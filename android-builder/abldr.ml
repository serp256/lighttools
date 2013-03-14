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

value cleanDir path = (
  myassert (Sys.os_type = "Unix") "android builder doesn't support non-unix systems now";
  myassert (Sys.file_exists path) (path ^ " passed to cleanDir func doesn't exists");
  myassert (Sys.is_directory path) (path ^ " passed to cleanDir is not directory");

  runCommand ("rm -rf " ^ path ^ "/*") ("error when cleaning " ^ path);
);

value findExpNames dir =
  Array.fold_left (fun (main, patch) fname ->
    if String.ends_with fname ".index" then (main, patch)
    else
      if String.starts_with fname "main" then (fname, main)
      else if String.starts_with fname "patch" then (main, fname) else (main, patch)
  ) ("", "") (Sys.readdir dir);

value getAbsolutePath path =
  let cwd = Unix.getcwd () in
  let dir = Filename.dirname path in (
    myassert (Sys.file_exists dir) ("cannot get absolute path of non-existent file '" ^ path ^ "'");
    Unix.chdir dir;

    let retval = Filename.concat (Unix.getcwd ()) (Filename.basename path) in (
      Unix.chdir cwd;
      retval;  
    );
  );

value getRelativePath pathA pathB =
  let pathA = List.tl (ExtString.String.nsplit (getAbsolutePath pathA) (Filename.dir_sep)) in
  let pathB = List.tl (ExtString.String.nsplit (getAbsolutePath pathB) (Filename.dir_sep)) in
  let rec skipCommonPath pathA pathB =
    if pathA <> [] && pathB <> [] && List.hd pathA = List.hd pathB
    then skipCommonPath (List.tl pathA) (List.tl pathB)
    else (pathA, pathB)
  in
  let (pathA, pathB) = skipCommonPath pathA pathB in
    (String.concat "" (List.map (fun _ -> Filename.(parent_dir_name ^ dir_sep)) pathB)) ^ (String.concat Filename.dir_sep pathA);

value makeRelativeSymlink src dst =
  let cwd = Unix.getcwd () in
  let src = Filename.concat (getRelativePath (Filename.dirname src) (Filename.dirname dst)) (Filename.basename src) in (
    Unix.chdir (Filename.dirname dst);
    Unix.symlink src (Filename.basename dst);
    Unix.chdir cwd;
  );

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
  ("-manifest", Set manifest, "generate manifest for builds");
  ("-assets", Set assets, "generate assets for builds");
  ("-asssounds", Set asssounds, "include sounds into assets, use with -assets option. by default sounds included into expansions");
  ("-nosounds", Set nosounds, "do not apply specific for sounds rsync calls");
  ("-exp", Set expansions, "generate expansions for builds");
  ("-base-exp", Set baseExp, "create symlink, named 'base', to this version on expansions in release archive");
  ("-exp-patch", Set_string patchFor, "generate expansions patch for version, passed through this option");
  ("-exp-ver", Set_string expVer, "use expansions from version, passed through this option");
  ("-lib", Set lib, "build only so");
  ("-all-builds", Set allBuilds, "make all builds");
  ("-apk", Set apk, "compile apk for builds");
  ("-no-exp", Set noExp, "application has no expansions");
  ("-without-lib", Set withoutLib, "compile apk without farm-lib rebuilding, use it in addition -apk option");
  ("-release", Set release, "compile apks for release, install from release archive, copy apk and expansions to release archive");
  ("-install", Tuple [ Set installApk; Set installExp; Set_string installSuffix; Rest (fun ver -> installVer.val := ver) ], "install both apk and expansions. when using with -release flag, takes build-version pair, when without -release -- only build. example: abldr -install normal_hdpi_pvr or abldr -release -install normal_hdpi_pvr 1.1.3");
  ("-install-apk", Tuple [ Set installApk; Set_string installSuffix; Rest (fun ver -> installVer.val := ver) ], "install only apk, usage same as -install");
  ("-install-exp", Tuple [ Set installExp; Set_string installSuffix; Rest (fun ver -> installVer.val := ver) ], "install only expansion, usage same as -install")
];

parse args (fun arg -> builds.val := [ arg :: !builds ]) "android multiple apks generator";
builds.val := List.rev !builds;

value (//) = Filename.concat;

(* value androidDir = Filename.concat !inDir "android"; *)
value androidDir = !inDir;
value manifestsDir = Filename.concat androidDir "manifests";
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

value aresmkrDir = Filename.concat !inDir "_aresmkr";
value assetsAresmkrDir = Filename.concat aresmkrDir "assets-raw";
value assetsAresmkrFname = Filename.concat aresmkrDir "assets";

value expAresmkrDir = Filename.concat aresmkrDir "expansions";
value rawExpAresmkrDir = Filename.concat expAresmkrDir "raw";
value buildRawExpAresmkrDir build = Filename.concat rawExpAresmkrDir build;
value buildExpAresmkrDir build = Filename.concat expAresmkrDir build;

value lsyncDir = "lsync";
value lsyncCommon = "common";
value _lsyncAssets = lsyncDir // "assets";
value _lsyncExp = lsyncDir // "expansions";
value lsyncAssets build = _lsyncAssets // build;
value lsyncExp build = _lsyncExp // build;
value lsyncCommonAssets = _lsyncAssets // lsyncCommon;
value lsyncCommonExp = _lsyncExp // lsyncCommon;

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

value expFname package ver main = (if main then "main" else "patch") ^ "." ^ ver ^ "." ^ package ^ ".obb";

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
(*   let buildFilter = Filename.concat rsyncDir ("android-" ^ build ^ "-assets.filter") in
  let buildFilter = if Sys.file_exists buildFilter then " --filter='. " ^ buildFilter ^ "'" else "" in *)
  (
    printf "\n\n[ generating assets for build %s... ]\n%!" build;

    mkdir assetsAresmkrDir;

(*     Printf.printf "%s: %s\n%!" lsyncCommonAssets (String.concat "," (Array.to_list (Sys.readdir lsyncCommonAssets)));
    Printf.printf "%s: %s\n%!" (lsyncAssets build) (String.concat "," (Array.to_list (Sys.readdir (lsyncAssets build)))); *)

    let commonAss = try Array.map (fun fname -> lsyncCommonAssets // fname) (Sys.readdir lsyncCommonAssets) with [ _ -> [||] ] in
    let buildAssDir = lsyncAssets build in
    let buildAss = try Array.map (fun fname -> buildAssDir // fname) (Sys.readdir buildAssDir) with [ _ -> [||] ] in
    let lsyncRules = Array.to_list (ExtArray.Array.filter (fun fname -> Sys.file_exists fname && not (Sys.is_directory fname)) (Array.concat [ commonAss; buildAss ])) in
    let lsyncRules = List.filter (fun rulesFname -> not (ExtString.String.ends_with rulesFname ".m4.include")) lsyncRules in
      runCommand ("lsync -i " ^ resDir ^ " -o " ^ assetsAresmkrDir ^ " " ^ (String.concat " " lsyncRules)) "lsync failed when copying assets";

(*     let sndOpts = if !asssounds then " --filter='protect locale/*/sounds' --filter='protect sounds'" else "" in
      runCommand ("rsync -avL" ^ sndOpts ^ " --include-from=" ^ (Filename.concat rsyncDir "android-assets.include") ^ buildFilter ^ " --exclude-from=" ^ (Filename.concat rsyncDir "android-assets.exclude") ^ " --delete --delete-excluded " ^ resDir ^ "/ " ^ assetsAresmkrDir) "rsync failed when copying assets"; *)

(*     if !asssounds then syncSounds assetsAresmkrDir
    else (); *)

    runCommand("aresmkr -concat -i " ^ assetsAresmkrDir ^ " -o " ^ assetsAresmkrFname) "android resources maker failed when making assets";
  );

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
        runCommand ("rm -f " ^ (Filename.concat apkArchiveDir "*.obb*")) "rm failed when trying to remove previous obbs";

        let expDir = buildExpAresmkrDir build in
        let archiveExp fname =
          if fname = ""
          then ()
          else
            let fname = Filename.concat expDir fname in
              if Unix.((lstat fname).st_kind = S_LNK)
              then makeRelativeSymlink (Filename.concat expDir (Unix.readlink fname)) (Filename.concat apkArchiveDir (Filename.basename fname))
              else runCommand ("cp -Rv " ^ fname ^ " " ^ apkArchiveDir) ("cp failed when trying to copy " ^ fname ^ " to archive")
        in
        let (main, patch) = findExpNames expDir in (
          archiveExp main;
          archiveExp patch;
        );

        if !release && !baseExp && !patchFor = "" then
          let base = Filename.concat (Filename.dirname apkArchiveDir) "base" in (
            try Sys.remove base with [ _ -> () ];
            makeRelativeSymlink apkArchiveDir base;
          )
        else ();

        printf "[ done ]\n%!";
      ) else ();
    );

value genExpansion build =
(
  if !expVer <> "" then
    let src = Filename.concat releaseDir (Filename.concat build !expVer) in
    let (main, patch) = findExpNames src in
    let dst = buildExpAresmkrDir build in
    let makeLink fname =
      if fname <> ""
      then
        let src = Filename.concat src fname in
        let dst = Filename.concat dst fname in (
          runCommand ("rm -f " ^ (Filename.concat (Filename.dirname dst) "*.obb*")) "rm failed when trying to remove previous obbs";

          printf "\n\n[ creating links to expansions version %s... ]\n%!" !expVer;
          makeRelativeSymlink src dst;
          makeRelativeSymlink (src ^ ".index") (dst ^ ".index");
          printf "[ done ]\n%!";
        )
      else ()
    in (
      makeLink main;
      makeLink patch;
    )
  else
    let expDir = (* Filename.concat expansionsDir build *)buildRawExpAresmkrDir build
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

        let inp = open_in (Filename.concat androidDir "AndroidManifest.xml") in
          let xmlinp = Xmlm.make_input ~strip:True (`Channel inp) in
          (
            ignore(Xmlm.input xmlinp);

            match Xmlm.input xmlinp with
            [ `El_start ((_, "manifest"), attributes) ->
              try
                let verCode = List.find_map (fun ((uri, name), v) -> if name = "versionCode" then Some v else None) attributes in
                let expAresmkrDir = buildExpAresmkrDir build in (
                  mkdir expAresmkrDir;
                  cleanDir expAresmkrDir;

                  if !patchFor <> ""
                  then
                    let archiveDir = Filename.concat (Filename.concat releaseDir build) !patchFor in
                    let (patchForFname, _) = findExpNames archiveDir in
                    let patchForPath = Filename.concat archiveDir patchForFname in (
                      myassert (Sys.file_exists patchForPath) ("main expansion file for which patch will be made doesn't exists (" ^ patchForPath ^ ")");

                      let mainExpPath = Filename.concat expAresmkrDir patchForFname in (
                        makeRelativeSymlink patchForPath mainExpPath;
                        makeRelativeSymlink (patchForPath ^ ".index") (mainExpPath ^ ".index");
                      );

                      let outFname = Filename.concat expAresmkrDir (expFname (getPackage ()) verCode False) in
                      let command = "aresmkr -o " ^ outFname ^ " -diff " ^ patchForPath ^ " " ^ expDir in
                        runCommand command ("aresmkr failed when making expansion patch for build '" ^ build ^ "' version " ^ !patchFor);
                    )
                  else
                    let outFname = Filename.concat expAresmkrDir (expFname (getPackage ()) verCode True) in
                    let command = "aresmkr -concat -i " ^ expDir ^ " -o " ^ outFname in                      
                      runCommand command ("aresmkr failed when making main expansion for build '" ^ build ^ "'")
                )
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
  cleanDir assetsDir;
  runCommand ("cp " ^ assetsAresmkrFname ^ " " ^ assetsDir ^ Filename.dir_sep) "failed when copying concated assets into android assets directory";

  if not !noExp then
    let expansionsDir = buildExpAresmkrDir build in
    let (main, patch) = findExpNames expansionsDir in
    let expXml fname main =
      if fname <> ""
      then
        let size = (Unix.stat (Filename.concat expansionsDir fname)).Unix.st_size in
        let ver = try List.hd (List.tl (String.nsplit fname ".")) with [ Failure _ -> failwith ("wrong expansion name '" ^ fname ^ "'") ] in
          "<item>" ^ (if main then "true" else "false") ^ "," ^ ver ^ "," ^ (string_of_int size) ^ "</item>"
      else ""
    in
    let out = open_out (Filename.concat androidDir "res/values/expansions.xml") in (
      output_string out ("<?xml version=\"1.0\" encoding=\"utf-8\"?><resources><array name=\"expansions\">" ^ (expXml main True) ^ (expXml patch False) ^ "</array></resources>");
      close_out out;

      myassert (main <> "") "main expansion not found, if app doesn't use expansions, use -no-exp option";

      let command = "aresmkr -o " ^ (Filename.concat assetsDir "index") ^ " -merge " ^ assetsAresmkrFname in
      let command = if patch <> "" then command ^ " " ^ (Filename.concat expansionsDir patch) else command in
        runCommand (command ^ " " ^ (Filename.concat expansionsDir main)) "failed when making assets and expansions binary index";
    )
  else
    runCommand ("aresmkr -o " ^ (Filename.concat assetsDir "index") ^ " -merge " ^ assetsAresmkrFname) "failed when making assets binary index";
  
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
      else runCommand ("adb install -r " ^ (Filename.concat archiveDir apk)) "adb failed when installing apk"
    else ();

    if !installExp then
      let installObb fname =
        if fname <> ""
        then
          let pushCommand = "storage_dir=`adb shell 'echo -n $EXTERNAL_STORAGE'` && exp_dir=$storage_dir/Android/obb/" ^ (getPackage ()) ^ " && adb shell \"mkdir -p $exp_dir\" && adb push " in
            runCommand (pushCommand ^ (Filename.concat archiveDir fname) ^ " $exp_dir/") ("error while pushing " ^ fname ^ " expansion")
        else ()
      in (
        installObb main;
        installObb patch;
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
