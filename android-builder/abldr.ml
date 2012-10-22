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
value suffixes = ref [];
value installVer = ref "";
value installSuffix = ref "";
value installApk = ref False;
value installExp = ref False;
value withoutLib = ref False;

value args = [
    ("-i", Set_string inDir, "input directory (for example, farm root directory, which contains android subdirectory)");
    ("-package", Set_string package, "application package (for expansions maker)");
    ("-manifest", Set manifest, "generate manifest for suffixes");
    ("-assets", Set assets, "generate assets for suffixes");
    ("-exp", Set expansions, "generate expansions for suffixes");
    ("-exp-patch", Set_string patchFor, "generate expansions patch for version, passed through this option");
    ("-exp-ver", Set_string expVer, "use expansions from version, passed through this option");
    ("-apk", Set apk, "compile apk for suffixes");
    ("-without-lib", Set withoutLib, "compile apk without farm-lib rebuilding, use it in addition -apk option");
    ("-release", Set release, "compile apks for release, use it in addition to -apk option");
    ("-install", Tuple [ Set installApk; Set installExp; Set_string installSuffix; Set_string installVer ], "install both apk and expansions. pass through this option single suffix-version pair. note, that version is taken from archive. example: abldr -install android_800x480 1.1.3");
    ("-install-apk", Tuple [ Set installApk; Set_string installSuffix; Set_string installVer ], "install only apk, usage same as -install");
    ("-install-exp", Tuple [ Set installExp; Set_string installSuffix; Set_string installVer ], "install only expansion, usage same as -install")
];

parse args (fun arg -> suffixes.val := [ arg :: !suffixes ]) "android multiple apks generator, usage [<options>] [<siffixes>...]";
suffixes.val := List.rev !suffixes;

(* if String.ends_with !inDir "/" then () else inDir.val := !inDir ^ "/"; *)

value androidDir = Filename.concat !inDir "android";
value manifestsDir = Filename.concat androidDir "manifests";
value expansionsDir = Filename.concat androidDir "expansions";
value rsyncDir = Filename.concat androidDir "rsync";
value resDir = Filename.concat !inDir "Resources";
value assetsDir = Filename.concat androidDir "assets";
value makefilePath = Filename.concat !inDir "Makefile";
value archiveDir = Filename.concat androidDir "archive";

value genManifest suffix =
    let manifestConfig = Filename.concat manifestsDir (suffix ^ ".xml") in
    (
        printf "\n\n[ generating manifest for suffix %s... ]\n%!" suffix;
        myassert (Sys.file_exists manifestConfig) (sprintf "cannot find manifest config for suffix %s" suffix);
        runCommand ("xsltproc -o " ^ (Filename.concat androidDir "AndroidManifest.xml") ^ " --xinclude --xincludestyle " ^ (Filename.concat manifestsDir "manifest.xslt") ^ " " ^ manifestConfig) "xsltproc failed";
    );

value genAssets suffix =
    let suffixFilter = Filename.concat rsyncDir ("android-" ^ suffix ^ "-assets.filter") in
        let suffixFilter = if Sys.file_exists suffixFilter then " --filter='. " ^ suffixFilter ^ "'" else "" in
        (
            printf "\n\n[ generating assets for suffix %s... ]\n%!" suffix;
            runCommand ("rsync -avL --include-from=" ^ (Filename.concat rsyncDir "android-assets.include") ^ suffixFilter ^ " --exclude-from=" ^ (Filename.concat rsyncDir "android-assets.exclude") ^ " --delete --delete-excluded " ^ resDir ^ "/ " ^ assetsDir) "rsync failed when copying assets";
        );

value archiveApk ?(apk = True) ?(expansions = True) suffix =
    let ver =
        let inchan = open_in (Filename.concat androidDir "version") in
            let ver = input_line inchan in
            (
                close_in inchan;
                ver;
            )
    in
        let apkArchiveDir = Filename.concat (Filename.concat archiveDir suffix) ver in
        (
            mkdir apkArchiveDir;

            if apk then
            (
                printf "\n\n[ archiving apk version %s for suffix %s... ]\n%!" ver suffix;
                runCommand ("rm -f " ^ (Filename.concat apkArchiveDir "*.apk")) "rm failed when trying to remove previous apk";
                runCommand ("cp -Rv `find " ^ androidDir ^ "/bin -name '*-release.apk'` " ^ apkArchiveDir) "cp failed when trying to copy apk to archive";
            ) else ();
            
            if expansions then
            (
                printf "\n\n[ archiving expansions version %s for suffix %s... ]\n%!" ver suffix;
                runCommand ("rm -f " ^ (Filename.concat apkArchiveDir "*.obb")) "rm failed when trying to remove previous obbs";
                runCommand ("cp -Rv `find " ^ (Filename.concat expansionsDir suffix) ^ " -name '*obb'` " ^ apkArchiveDir) "cp failed when trying to copy main expansion to archive";
            ) else ();
        );

value genMainExpansion suffix =
(
    if !expVer <> "" then
        let src = Filename.concat archiveDir (Filename.concat suffix !expVer)
        and dst = Filename.concat expansionsDir suffix in
            let (main, patch) = findExpNames src in
                let src = if Filename.is_relative src then Filename.concat (Unix.getcwd ()) src else src
                and dst = if Filename.is_relative dst then Filename.concat (Unix.getcwd ()) dst else dst in
                (
                    runCommand ("rm -f " ^ (Filename.concat dst "*.obb")) "rm failed when trying to remove previous obbs";
                    Unix.symlink (Filename.concat src main) (Filename.concat dst main);
                    Unix.symlink (Filename.concat src patch) (Filename.concat dst patch);
                )
    else
        let expDir = Filename.concat expansionsDir (Filename.concat suffix "main")
        and suffixFilter = Filename.concat rsyncDir ("android-" ^ suffix ^ "-expansions.filter") in
            let suffixFilter = if Sys.file_exists suffixFilter then " --filter='. " ^ suffixFilter ^ "'" else "" in
            (
                printf "\n\n[ generating expansions for suffix %s... ]\n%!" suffix;
                mkdir expDir;
                runCommand ("rsync -avL --filter='protect locale/*/sounds' --filter='protect sounds' --include-from=" ^ (Filename.concat rsyncDir "android-expansions.include") ^ suffixFilter ^ " --exclude-from=" ^ (Filename.concat rsyncDir "android-expansions.exclude") ^ " --delete --delete-excluded " ^ resDir ^ "/ " ^ expDir) "rsync failed when copying expansions";
                runCommand ("rsync -avL --exclude=.DS_Store --delete --delete-excluded " ^ (Filename.concat resDir "sounds_android/default/") ^ " " ^ (Filename.concat expDir "sounds/")) "rsync failed when copying default sounds";
                runCommand ("rsync -avL --exclude=.DS_Store --delete --delete-excluded " ^ (Filename.concat resDir "sounds_android/en/") ^ " " ^ (Filename.concat expDir "locale/en/sounds/")) "rsync failed when copying en sounds";
                runCommand ("rsync -avL --exclude=.DS_Store --delete --delete-excluded " ^ (Filename.concat resDir "sounds_android/ru/") ^ " " ^ (Filename.concat expDir "locale/ru/sounds/")) "rsync failed when copying ru sounds";

                let expsDir = Filename.concat expansionsDir suffix in
                    Array.iter (fun fname -> if String.ends_with fname ".obb" then Sys.remove (Filename.concat expsDir fname) else ()) (Sys.readdir expsDir);

                let inp = open_in (Filename.concat androidDir "AndroidManifest.xml") in
                    let xmlinp = Xmlm.make_input ~strip:True (`Channel inp) in
                    (
                        ignore(Xmlm.input xmlinp);

                        match Xmlm.input xmlinp with
                        [ `El_start ((_, "manifest"), attributes) ->
                            try
                                let verCode = List.find_map (fun ((uri, name), v) -> if name = "versionCode" then Some v else None) attributes
                                and expansionsDir = Filename.concat expansionsDir suffix in
                                    let command = "aem -o " ^ expansionsDir ^ "/ -i " ^ (Filename.concat expansionsDir "main") ^ " -package " ^ !package ^  " -version " ^ verCode in
                                        let command =
                                            if !patchFor <> "" then
                                                let archiveDir = Filename.concat (Filename.concat archiveDir suffix) !patchFor in
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

    archiveApk ~apk:False suffix;
);

value compileApk suffix =
    let target = if !release then "android-release" else "android" in
    (
        let expansionsDir = Filename.concat expansionsDir suffix in
            let (main, patch) = findExpNames expansionsDir in
                let msize = (Unix.stat (Filename.concat expansionsDir main)).Unix.st_size
                and psize = (Unix.stat (Filename.concat expansionsDir patch)).Unix.st_size
                and mver = try List.hd (List.tl (String.nsplit main ".")) with [ Failure _ -> failwith "wrong main expansion name" ]
                and pver = try List.hd (List.tl (String.nsplit patch ".")) with [ Failure _ -> failwith "wrong expansion patch name" ] in
                    let out = open_out (Filename.concat androidDir "res/values/expansions.xml") in
                    (
                        output_string out ("<?xml version=\"1.0\" encoding=\"utf-8\"?><resources><array name=\"expansions\"><item>true," ^ mver ^ "," ^ (string_of_int msize) ^ "</item><item>false," ^ pver ^ "," ^ (string_of_int psize) ^ "</item></array></resources>");
                        close_out out;
                    );
        
        printf "\n\n[ compiling apk for suffix %s... ]\n%!" suffix;

        if !withoutLib then runCommand ("ant -f " ^ (Filename.concat androidDir "build.xml") ^ " release") "ant failed when compiling apk"
        else runCommand ("make -f " ^ makefilePath ^ " " ^ target) "make failed when compiling apk";

        archiveApk ~expansions:False suffix;
    );

value install () =
    let archiveDir = Filename.concat (Filename.concat archiveDir !installSuffix) !installVer in
        let (apk, main, patch) =
            Array.fold_left (fun (apk, main, patch) fname ->
                if String.ends_with fname ".apk" then (fname, main, patch)
                else if String.starts_with fname "main" then (apk, fname, patch)
                else if String.starts_with fname "patch" then (apk, main, fname) else (apk, main, patch)
            ) ("", "", "") (Sys.readdir archiveDir)
        in
            if apk = "" || main = "" || patch = "" then failwith "apk, main or patch not found"
            else
            (
                if !installApk then runCommand ("adb install -r " ^ (Filename.concat archiveDir apk)) "adb failed when installing apk" else ();

                if !installExp then
                    let pushCommand = "storage_dir=`adb shell 'echo -n $EXTERNAL_STORAGE'` && exp_dir=$storage_dir/Android/obb/" ^ !package ^ " && adb shell \"mkdir -p $exp_dir\" && adb push " in
                    (
                        runCommand (pushCommand ^ (Filename.concat archiveDir main) ^ " $exp_dir/") "error while pushing main expansion";
                        runCommand (pushCommand ^ (Filename.concat archiveDir patch) ^ " $exp_dir/") "error while pushing expansion patch";                    
                    )
                else ();
            );

if !installSuffix <> "" && !installVer <> "" then
    install ()
else
    List.iter (fun suffix ->
        (
            printf "processing suffix %s...\n%!" suffix;

            if !manifest || !patchFor <> "" || !expVer <> "" || !apk then genManifest suffix else ();
            if !assets || !apk then genAssets suffix else ();
            if !expansions || !patchFor <> "" || !expVer <> "" then genMainExpansion suffix else ();
            if !apk then compileApk suffix else ();
        )
    ) !suffixes;