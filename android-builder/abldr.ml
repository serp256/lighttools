open ExtString;
open ExtList;
open ExtArray;
open Printf;
open Arg;

value myassert exp mes = if not exp then ( printf "\n%!"; failwith mes ) else ();
value mkdir path =
(
  myassert (Sys.os_type = "Unix") "android builder doesn't support non-unix systems now";

  if Sys.file_exists path then
    if Sys.is_directory path then ()
    else
    (
      ignore(Sys.command ("rm " ^ path));
      ignore(Sys.command ("mkdir -p " ^ path));
    )
  else
    ignore(Sys.command ("mkdir -p " ^ path));
);

value runCommand command errMes =
(
  printf "%s\n%!" command;
  myassert (Sys.command command = 0) errMes;
);

value findExpNames dir =
  Array.fold_left (fun (main, patch) fname ->
    if String.starts_with fname "main" then (fname, main)
    else if String.starts_with fname "patch" then (main, fname) else (main, patch)
  ) ("", "") (Sys.readdir dir);

value inDir = ref ".";
value manifests: ref (list string) = ref [];

value manifest = ref False;
value assets = ref False;
value expansions = ref False;
value apk = ref False;
value release = ref False;
value package = ref "";
value patchFor = ref "";
value expVer = ref "";
value builds = ref [];
value installVer = ref "";
value installSuffix = ref "";
value installApk = ref False;
value installExp = ref False;
value withoutLib = ref False;
value baseExp = ref False;
(* value cheat = ref False; *)
value noExp = ref False;
value asssounds = ref False;
value lib = ref False;
value allBuilds = ref False;
value nosounds = ref False;

value args = [
  ("-i", Set_string inDir, "input directory (for example, farm root directory, which contains android subdirectory)");
  (* ("-package", Set_string package, "application package (for expansions maker)"); *)
  ("-manifest", Set manifest, "generate manifest for builds");
  ("-assets", Set assets, "generate assets for builds");
  ("-asssounds", Set asssounds, "include sounds into assets, use with -assets option. by default sounds included into expansions");
  ("-nosounds", Set nosounds, "do not apply specific for sounds rsync calls");
  ("-exp", Set expansions, "generate expansions for builds");
  ("-base-exp", Set baseExp, "create symlink, named 'base', to this version on expansions in release archive");
  ("-exp-patch", Set_string patchFor, "generate expansions patch for version, passed through this option");
  ("-exp-ver", Set_string expVer, "use expansions from version, passed through this option");
  ("-lib", Set lib, "build only Farm.so");
  ("-all-builds", Set allBuilds, "make all builds");
  ("-apk", Set apk, "compile apk for builds");
  ("-no-exp", Set noExp, "application has no expansions");
  ("-without-lib", Set withoutLib, "compile apk without farm-lib rebuilding, use it in addition -apk option");
  ("-release", Set release, "compile apks for release, install from release archive, copy apk and expansions to release archive");
  (* ("-cheat", Set cheat, "compile apk with cheats, only for debug version"); *)
  ("-install", Tuple [ Set installApk; Set installExp; Set_string installSuffix; Rest (fun ver -> installVer.val := ver) ], "install both apk and expansions. when using with -release flag, takes build-version pair, when without -release -- only build. example: abldr -install normal_hdpi_pvr or abldr -release -install normal_hdpi_pvr 1.1.3");
  ("-install-apk", Tuple [ Set installApk; Set_string installSuffix; Rest (fun ver -> installVer.val := ver) ], "install only apk, usage same as -install");
  ("-install-exp", Tuple [ Set installExp; Set_string installSuffix; Rest (fun ver -> installVer.val := ver) ], "install only expansion, usage same as -install")
];

parse args (fun arg -> builds.val := [ arg :: !builds ]) "android multiple apks generator";
builds.val := List.rev !builds;

(* value androidDir = Filename.concat !inDir "android"; *)
value androidDir = !inDir;
value manifestsDir = Filename.concat androidDir "manifests";
value expansionsDir = Filename.concat androidDir "expansions";
value rsyncDir = Filename.concat androidDir "rsync";
value resDir = Filename.concat androidDir "../Resources";
value assetsDir = Filename.concat androidDir "assets";
value makefilePath = Filename.concat androidDir "Makefile";
value archiveDir = Filename.concat androidDir "apk-archive";
value releaseDir = Filename.concat archiveDir "release";
value debugDir = Filename.concat archiveDir "debug";
value archiveDir build ver =
  let archiveDir = Filename.concat (if !release then releaseDir else debugDir) build in
    if !release then Filename.concat archiveDir ver else archiveDir;

value genManifest build =
  let manifestConfig = Filename.concat manifestsDir (build ^ ".xml") in
  (
    printf "\n\n[ generating manifest for build %s... ]\n%!" build;
    myassert (Sys.file_exists manifestConfig) (sprintf "cannot find manifest config for build %s" build);
    runCommand ("xsltproc -o " ^ (Filename.concat androidDir "AndroidManifest.xml") ^ " --xinclude --xincludestyle " ^ (Filename.concat manifestsDir "manifest.xslt") ^ " " ^ manifestConfig) "xsltproc failed";
  );

value getPackage () =
(
  if !package = "" then
    let inp = open_in (Filename.concat !inDir "package.xml") in
      let xmlinp = Xmlm.make_input ~strip:True (`Channel inp) in
      (
        ignore(Xmlm.input xmlinp);

        let rec findPackage () =
          if Xmlm.eoi xmlinp then failwith "package not found package.xml"
          else
            match Xmlm.input xmlinp with
            [ `El_start ((_, "package"), _) ->
              match Xmlm.input xmlinp with
              [ `Data package -> package
              | _ -> failwith "package not found in package.xml"
              ]
            | _ -> findPackage ()
            ]
        in
          package.val := findPackage ();

        close_in inp;
      )
  else ();
  
  !package;  
);

(* value rsyncArgs =
  let argFunc argName argVal = if argVal = "" then "" else Printf.sprintf "--%s=%s" argName (Filename.concat rsyncDir argVal)
  and srcFunc _ src = if src = "" then resDir ^ "/" else Printf.sprintf "`cat %s`" (Filename.concat rsyncDir src)
  and dstFunc _ dst = if dst = "" then assetsDir ^ "/" else Printf.sprintf "`cat %s`" (Filename.concat rsyncDir dst) in
    [ ("files-from", argFunc); ("include-from", argFunc); ("filter", argFunc); ("exclude-from", argFunc); ("src", srcFunc); ("dst", dstFunc) ];

value kindRegexp = String.concat "\\|" (List.map (fun (argName, _) -> argName) rsyncArgs);

value createRsyncPass () = List.map (fun (argName, _) -> (argName, ref "")) rsyncArgs; *)

value syncSounds dst =
  let sndDir = Filename.concat resDir "sounds_android" in
    Array.iter (fun fname ->
      let sndDir = Filename.concat sndDir fname in
        if Sys.is_directory sndDir then
          if fname = "default" then
            runCommand ("rsync -avL --exclude=.DS_Store --delete --delete-excluded " ^ sndDir ^ "/ " ^ (Filename.concat dst "sounds/")) "rsync failed when copying default sounds"
          else
            runCommand ("rsync -avL --exclude=.DS_Store --delete --delete-excluded " ^ sndDir ^ "/ " ^ (Filename.concat dst ("locale/" ^ fname ^ "/sounds/"))) "rsync failed when copying en sounds"
        else ()
    ) (Sys.readdir sndDir);

value genAssets build =
  let buildFilter = Filename.concat rsyncDir ("android-" ^ build ^ "-assets.filter") in
  let buildFilter = if Sys.file_exists buildFilter then " --filter='. " ^ buildFilter ^ "'" else "" in
  (
    printf "\n\n[ generating assets for build %s... ]\n%!" build;

    let sndOpts = if !asssounds then " --filter='protect locale/*/sounds' --filter='protect sounds'" else "" in
      runCommand ("rsync -avL" ^ sndOpts ^ " --include-from=" ^ (Filename.concat rsyncDir "android-assets.include") ^ buildFilter ^ " --exclude-from=" ^ (Filename.concat rsyncDir "android-assets.exclude") ^ " --delete --delete-excluded " ^ resDir ^ "/ " ^ assetsDir) "rsync failed when copying assets";

    if !asssounds then
      syncSounds assetsDir
    else ();
  );
(*     let rsyncPasses = ref []
  and regexp = Str.regexp ("^\\(" ^ build ^ "\\|common\\)\\.assets\\.\\([0-9]+\\)\\.\\(" ^ kindRegexp ^ "\\)$") in
  (
    Array.iter (fun fname ->
      if Str.string_match regexp fname 0 then
        let passId = int_of_string (Str.matched_group 2 fname)
        and arg = Str.matched_group 3 fname in
          let rsyncPass = try List.assoc passId !rsyncPasses with [ Not_found -> let rsyncPass = createRsyncPass () in ( rsyncPasses.val := [ (passId, rsyncPass) :: !rsyncPasses ]; rsyncPass ) ] in
            (List.assoc arg rsyncPass).val := fname
      else ()
    ) (Sys.readdir rsyncDir);

    List.iter (fun (_, pass) ->
      let rsyncArgs =
        let argsList = (List.map (fun (argName, argVal) -> (List.assoc argName rsyncArgs) argName argVal.val) pass) in
          String.concat " " argsList
      in
        runCommand ("rsync -avL --exclude=.DS_Store --delete --delete-excluded " ^ rsyncArgs) "rsync failed when copying assets";
    ) (List.sort !rsyncPasses);
  ); *)



value archiveApk ?(apk = True) ?(expansions = True) build =
  let ver =
    let inchan = open_in (Filename.concat androidDir "version") in
      let ver = input_line inchan in
      (
        close_in inchan;
        ver;
      )
  in
    let apkArchiveDir = archiveDir build ver in
    (
      mkdir apkArchiveDir;

      if apk then
      (
        printf "\n\n[ archiving apk version %s for build %s... ]\n%!" ver build;
        runCommand ("rm -f " ^ (Filename.concat apkArchiveDir "*.apk")) "rm failed when trying to remove previous apk";
        runCommand ("cp -Rv `find " ^ androidDir ^ "/bin -name '*-release.apk'` " ^ apkArchiveDir) "cp failed when trying to copy apk to archive";
      ) else ();
      
      if expansions then
      (
        printf "\n\n[ archiving expansions version %s for build %s... ]\n%!" ver build;
        runCommand ("rm -f " ^ (Filename.concat apkArchiveDir "*.obb")) "rm failed when trying to remove previous obbs";
        runCommand ("cp -Rv `find " ^ (Filename.concat expansionsDir build) ^ " -name '*obb'` " ^ apkArchiveDir) "cp failed when trying to copy main expansion to archive";

        if !release && !baseExp && !patchFor = "" then
          let baseLinkName = "base" in
          let base = Filename.concat (Filename.dirname apkArchiveDir) baseLinkName in
            (* let apkArchiveDir = if Filename.is_relative apkArchiveDir then Filename.concat (Unix.getcwd()) apkArchiveDir else apkArchiveDir in *)
            (
              try Sys.remove base with [ _ -> () ];
              (* if Sys.file_exists base then Sys.remove base else (); *)
              (* Unix.symlink apkArchiveDir base; *)

              let cwd = Unix.getcwd () in
              (
                Unix.chdir (Filename.dirname apkArchiveDir);
                Unix.symlink ver baseLinkName;
                Unix.chdir cwd;
              );
            )
        else ();
      ) else ();
    );

value genExpansion build =
(
  if !expVer <> "" then
    let src = Filename.concat releaseDir (Filename.concat build !expVer)
    and dst = Filename.concat expansionsDir build in
      let (main, patch) = findExpNames src in
        let src = if Filename.is_relative src then Filename.concat (Unix.getcwd ()) src else src
        and dst = if Filename.is_relative dst then Filename.concat (Unix.getcwd ()) dst else dst in
        (
          runCommand ("rm -f " ^ (Filename.concat dst "*.obb")) "rm failed when trying to remove previous obbs";

          printf "\n\n[ creating links to expansions version %s... ]\n%!" !expVer;
          Unix.symlink (Filename.concat src main) (Filename.concat dst main);
          Unix.symlink (Filename.concat src patch) (Filename.concat dst patch);
        )
  else
    let expDir = Filename.concat expansionsDir (Filename.concat build "main")
    and buildFilter = Filename.concat rsyncDir ("android-" ^ build ^ "-expansions.filter") in
      let buildFilter = if Sys.file_exists buildFilter then " --filter='. " ^ buildFilter ^ "'" else "" in
      (
        printf "\n\n[ generating expansions for build %s... ]\n%!" build;
        mkdir expDir;

        (* it is so bad, not universal at all *)
        runCommand ("rsync -avL --filter='protect locale/*/sounds' --filter='protect sounds' --include-from=" ^ (Filename.concat rsyncDir "android-expansions.include") ^ buildFilter ^ " --exclude-from=" ^ (Filename.concat rsyncDir "android-expansions.exclude") ^ " --delete --delete-excluded " ^ resDir ^ "/ " ^ expDir) "rsync failed when copying expansions";

        if not !nosounds
        then syncSounds expDir
        else ();

(*                 runCommand ("rsync -avL --exclude=.DS_Store --delete --delete-excluded " ^ (Filename.concat resDir "sounds_android/default/") ^ " " ^ (Filename.concat expDir "sounds/")) "rsync failed when copying default sounds";
        runCommand ("rsync -avL --exclude=.DS_Store --delete --delete-excluded " ^ (Filename.concat resDir "sounds_android/en/") ^ " " ^ (Filename.concat expDir "locale/en/sounds/")) "rsync failed when copying en sounds";
        runCommand ("rsync -avL --exclude=.DS_Store --delete --delete-excluded " ^ (Filename.concat resDir "sounds_android/ru/") ^ " " ^ (Filename.concat expDir "locale/ru/sounds/")) "rsync failed when copying ru sounds";
 *)
        let expsDir = Filename.concat expansionsDir build in
          Array.iter (fun fname -> if String.ends_with fname ".obb" then Sys.remove (Filename.concat expsDir fname) else ()) (Sys.readdir expsDir);

        let inp = open_in (Filename.concat androidDir "AndroidManifest.xml") in
          let xmlinp = Xmlm.make_input ~strip:True (`Channel inp) in
          (
            ignore(Xmlm.input xmlinp);

            match Xmlm.input xmlinp with
            [ `El_start ((_, "manifest"), attributes) ->
              try
                let verCode = List.find_map (fun ((uri, name), v) -> if name = "versionCode" then Some v else None) attributes
                and expansionsDir = Filename.concat expansionsDir build in
                  let command = "aem -o " ^ expansionsDir ^ "/ -i " ^ (Filename.concat expansionsDir "main") ^ " -package " ^ (getPackage ()) ^  " -version " ^ verCode in
                    let command =
                      if !patchFor <> "" then
                        let archiveDir = Filename.concat (Filename.concat releaseDir build) !patchFor in
                          try
                            let patchFname = Array.find (fun fname -> String.starts_with fname "patch") (Sys.readdir archiveDir) in
                              command ^ " -p " ^ (Filename.concat archiveDir patchFname)
                          with [ Not_found -> failwith "no base patch found in archive "]
                      else command
                    in
                      runCommand command "aem failed when packing expansion"
              with [ Not_found -> failwith "no versionCode in your manifest" ]
            | _ -> failwith "no manifest tag in your manifest"
            ];                  
          );
      );

  archiveApk ~apk:False build;
);

value compileLib () =
  let target = if !release then "release" else "debug" in
    runCommand ("make -f " ^ makefilePath ^ " " ^ target) "make failed when compiling lib";

value compileApk build =
(
  if not !noExp then
    let expansionsDir = Filename.concat expansionsDir build in
      let (main, patch) = findExpNames expansionsDir in
        let msize = (Unix.stat (Filename.concat expansionsDir main)).Unix.st_size
        and psize = (Unix.stat (Filename.concat expansionsDir patch)).Unix.st_size
        and mver = try List.hd (List.tl (String.nsplit main ".")) with [ Failure _ -> failwith "wrong main expansion name" ]
        and pver = try List.hd (List.tl (String.nsplit patch ".")) with [ Failure _ -> failwith "wrong expansion patch name" ] in
          let out = open_out (Filename.concat androidDir "res/values/expansions.xml") in
          (
            printf "\n\n[ writing expansions.xml for build %s (%d, %d)... ]\n%!" build msize psize;
                      
            output_string out ("<?xml version=\"1.0\" encoding=\"utf-8\"?><resources><array name=\"expansions\"><item>true," ^ mver ^ "," ^ (string_of_int msize) ^ "</item><item>false," ^ pver ^ "," ^ (string_of_int psize) ^ "</item></array></resources>");
            close_out out;
          )
  else ();
  
  printf "\n\n[ compiling apk for build %s... ]\n%!" build;

  if !withoutLib then () else compileLib ();
  runCommand ("ant -f " ^ (Filename.concat androidDir "build.xml") ^ " release") "ant failed when compiling apk";

  archiveApk ~expansions:False build;
);

value install () =
(
  myassert (not !release || !installVer <> "") "when installing release, should pass install version";

  let archiveDir = archiveDir !installSuffix !installVer in
  let () = printf "archiveDir %s\n" archiveDir in
  let (apk, main, patch) =
    Array.fold_left (fun (apk, main, patch) fname ->
      if String.ends_with fname ".apk" then (fname, main, patch)
      else if String.starts_with fname "main" then (apk, fname, patch)
      else if String.starts_with fname "patch" then (apk, main, fname) else (apk, main, patch)
    ) ("", "", "") (Sys.readdir archiveDir)
  in
  (
    if !installApk then
      if apk = "" then  failwith "apk is missing"
      else
      (
        runCommand ("storage_dir=`adb shell 'echo -n $EXTERNAL_STORAGE'` && adb shell \"rm $storage_dir/Android/data/" ^ (getPackage ()) ^ "/files/assets/a*\"") "";
        runCommand ("adb install -r " ^ (Filename.concat archiveDir apk)) "adb failed when installing apk";
      )
    else ();

    if !installExp then
      if main = "" || patch = "" then failwith "main expansion or patch is missing"
      else 
        let pushCommand = "storage_dir=`adb shell 'echo -n $EXTERNAL_STORAGE'` && exp_dir=$storage_dir/Android/obb/" ^ (getPackage ()) ^ " && adb shell \"mkdir -p $exp_dir\" && adb push " in
        (
          runCommand (pushCommand ^ (Filename.concat archiveDir main) ^ " $exp_dir/") "error while pushing main expansion";
          runCommand (pushCommand ^ (Filename.concat archiveDir patch) ^ " $exp_dir/") "error while pushing expansion patch";
        )
    else ();        
  );
);

if !installApk || !installExp then install ()
else
(
  if !allBuilds then
    builds.val := Array.to_list (Array.map (fun fname -> Filename.chop_extension fname) (Array.filter (fun fname -> not (Sys.is_directory (Filename.concat manifestsDir fname)) && (ExtString.String.ends_with fname ".xml")) (Sys.readdir manifestsDir)))
  else ();

  if !lib then compileLib () else ();

  List.iter (fun build ->
    (
      printf "processing build %s...\n%!" build;

      if !manifest || !expansions || !patchFor <> "" || !expVer <> "" || !apk then genManifest build else ();
      if !assets || !apk then genAssets build else ();
      if !expansions || !patchFor <> "" || !expVer <> "" then genExpansion build else ();
      if !apk then compileApk build else ();
    )
  ) !builds;    
);