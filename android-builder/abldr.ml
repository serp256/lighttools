open ExtString;
open ExtList;
open ExtArray;
open Printf;
open Arg;

value doNotCleanAssets = ref False;
value (//) = Filename.concat;
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
value assetsMd5 = ref True;
value expansions = ref False;
value apk = ref False;
value release = ref False;
value patchFor = ref "";
value expVer = ref "";
value builds = ref [];
value installVer = ref "";
value installSuffix = ref "";
value installApk = ref False;
value installExp = ref False;
value withoutLib = ref False;
value baseExp = ref False;
(* value noExp = ref False; *)
value lib = ref False;
value allBuilds = ref False;

value proj = ref False;
value projPackage = ref "";
value projAppName = ref "";
value projPath = ref "android";
value projKeystorePass = ref "xyupizda";
value projWithExp = ref False;
value projWithDownload = ref False;
value projSo = ref "";
value projLightning = ref "";
value lsync = ref False;
value abldr_xml = ref "";

value makeProject () = (
  myassert (!projPackage <> "") "-proj-package is required";
  myassert (!projAppName <> "") "-proj-app-name is required";
  myassert (!projSo <> "") "-proj-so is required";
  myassert (!projLightning <> "") "-proj-lightning is required";

  runCommand (Printf.sprintf "android create project --target android-10 --name abldr_android_project --path \"%s\" --package %s --activity Activity" !projPath !projPackage)
              "android tool failed when creating base android project";

  ignore(Sys.command ("rm -r " ^ (!projPath // "src/*")));
  try Sys.remove (!projPath // "AndroidManifest.xml") with [ Sys_error _ -> () ];
  try Sys.remove (!projPath // "ant.properties") with [ Sys_error _ -> () ];
  try Sys.remove (!projPath // "proguard-project.txt") with [ Sys_error _ -> () ];
  try Sys.remove (!projPath // "res/layout/main.xml") with [ Sys_error _ -> () ];
  try Sys.remove (!projPath // "res/values/strings.xml") with [ Sys_error _ -> () ];
  try Unix.rmdir (!projPath // "res/layout") with [ Unix.Unix_error _ -> () ];

  mkdir (!projPath // "libs" // "armeabi-v7a");
  mkdir (!projPath // "assets");

  let kstore = "keystore" in
  let kstoreFname = !projPath // kstore in
  let cmd = Printf.sprintf
              "keytool -genkey -keystore %s.keystore -alias %s -dname \"CN=%s, OU=Unknown, O=Redspell, L=Orel, ST=Unknown, C=RU\" -keypass %s -storepass %s -keyalg RSA -keysize 2048 -validity 10000"
              kstoreFname kstore (Unix.getlogin ()) !projKeystorePass !projKeystorePass
  in (
    runCommand cmd "keytool failed when create keystore";

    let out = open_out (!projPath // "ant.properties") in (
      output_string out (Printf.sprintf "key.store=%s.keystore\nkey.alias=%s\nkey.store.password=%s\nkey.alias.password=%s"
                                        kstore kstore !projKeystorePass !projKeystorePass);
      close_out out;
    );
  );


  (*let lsyncDir = !projPath // "lsync" in (
    mkdir (lsyncDir // "assets" // "common");
    if !projWithExp then mkdir (lsyncDir // "expansions") else ();
  );*)

  let manifestsDir = !projPath // "manifests" in

  let defaultManifest =
    "<?xml version=\"1.0\"?>
      <apk>
        <id>0</id>
        <screens>
          <small/><normal/><large/><xlarge/>
          <compatible>
            <!--<screen size=\"normal\" density=\"hdpi\"/>-->
          </compatible>
        </screens>
      </apk>"
  in

  let manifest =
    "<?xml version=\"1.0\"?>
    <xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\" xmlns:xi=\"http://www.w3.org/2001/XInclude\" xmlns:android=\"http://schemas.android.com/apk/res/android\">
        <xsl:output method=\"xml\" indent=\"yes\"/>

        <xsl:template match=\"apk\">
            <manifest xmlns:android=\"http://schemas.android.com/apk/res/android\"
                    package=\"{document('../abldr.xml')/apk/package}\"
                    android:versionName=\"{document('../abldr.xml')/apk/version}\"
                    android:versionCode=\"{concat(translate(document('../abldr.xml')/apk/version,'.',''),id)}\"
                    android:installLocation=\"auto\">

                <application android:label=\"{document('../abldr.xml')/apk/name}\" android:icon=\"@drawable/icon\">
                    <meta-data android:name=\"com.google.android.gms.version\" android:value=\"@integer/google_play_services_version\" />

                    <activity android:name=\"ru.redspell.lightning.NativeActivity\"
                      android:label=\"@string/app_name\"
                      android:screenOrientation=\"landscape\"
                      android:launchMode=\"singleTop\"
                      android:configChanges=\"orientation|screenSize\">
                      <meta-data android:name=\"android.app.lib_name\" android:value=\"{document('../abldr.xml')/apk/lib}\"/>
                      <intent-filter>
                          <action android:name=\"android.intent.action.MAIN\" />
                          <category android:name=\"android.intent.category.LAUNCHER\" />
                      </intent-filter>
                    </activity>

                    <service android:name=\"ru.redspell.lightning.expansions.DownloadService\" />
                    <receiver android:name=\"ru.redspell.lightning.expansions.AlarmReceiver\" />

                    <receiver android:name=\"ru.redspell.lightning.notifications.Receiver\">
                      <intent-filter>
                        <action android:name=\"android.intent.action.BOOT_COMPLETED\" />
                      </intent-filter>
                    </receiver>
                </application>

                <uses-permission android:name=\"android.permission.INTERNET\" />
                <uses-permission android:name=\"com.android.vending.BILLING\" />
                <uses-permission android:name=\"com.android.vending.CHECK_LICENSE\" />
                <uses-permission android:name=\"android.permission.WAKE_LOCK\" />
                <uses-permission android:name=\"android.permission.ACCESS_NETWORK_STATE\" />
                <uses-permission android:name=\"android.permission.ACCESS_WIFI_STATE\"/>
                <uses-permission android:name=\"android.permission.WRITE_EXTERNAL_STORAGE\"/>
                <uses-permission android:name=\"android.permission.READ_PHONE_STATE\"/>
                <uses-permission android:name=\"android.permission.RECEIVE_BOOT_COMPLETED\" />
                <uses-sdk android:targetSdkVersion=\"10\" android:minSdkVersion=\"9\"></uses-sdk>

                <xsl:choose>
                    <xsl:when test=\"opengl3\">
                        <uses-feature android:glEsVersion=\"0x00030000\"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <uses-feature android:glEsVersion=\"0x00020000\"/>
                        <xsl:apply-templates select=\"//texture\"/>
                    </xsl:otherwise>
                </xsl:choose>

                <xsl:apply-templates select=\"screens\"/>
            </manifest>
        </xsl:template>

        <xsl:template match=\"texture\">
            <supports-gl-texture android:name=\"{.}\" />
        </xsl:template>

        <xsl:template match=\"screens\">
            <supports-screens>
                <xsl:attribute name=\"android:smallScreens\"><xsl:choose><xsl:when test=\"small\">true</xsl:when><xsl:otherwise>false</xsl:otherwise></xsl:choose></xsl:attribute>
                <xsl:attribute name=\"android:normalScreens\"><xsl:choose><xsl:when test=\"normal\">true</xsl:when><xsl:otherwise>false</xsl:otherwise></xsl:choose></xsl:attribute>
                <xsl:attribute name=\"android:largeScreens\"><xsl:choose><xsl:when test=\"large\">true</xsl:when><xsl:otherwise>false</xsl:otherwise></xsl:choose></xsl:attribute>
                <xsl:attribute name=\"android:xlargeScreens\"><xsl:choose><xsl:when test=\"xlarge\">true</xsl:when><xsl:otherwise>false</xsl:otherwise></xsl:choose></xsl:attribute>
            </supports-screens>

            <xsl:apply-templates select=\"compatible\"/>
        </xsl:template>

        <xsl:template match=\"compatible\">
            <compatible-screens>
                <xsl:apply-templates />
            </compatible-screens>
        </xsl:template>

        <xsl:template match=\"screen\">
            <screen android:screenSize=\"{@size}\" android:screenDensity=\"{@density}\"/>
        </xsl:template>
    </xsl:stylesheet>"
  in (
    mkdir manifestsDir;

    let out = open_out (manifestsDir // "manifest.xslt") in (
      output_string out manifest;
      close_out out;
    );

    let out = open_out (manifestsDir // "default.xml") in (
      output_string out defaultManifest;
      close_out out;
    );
  );

  let out = open_out (!projPath // "abldr.xml") in (
    output_string out (Printf.sprintf "<?xml version=\"1.0\"?>\n<apk>\n\t<package>%s</package>\n\t<name>%s</name>\n\t<version>1.0.0</version>\n\t<withexp>%B</withexp>\n\t<withdownload>%B</withdownload>\n\t<lib>%s</lib>\n</apk>"
                                        !projPackage !projAppName !projWithExp !projWithDownload !projSo);
    close_out out;
  );

  let out = open_out (!projPath // "Makefile") in (
    output_string out "debug:\n\t$(MAKE) -C ../ android-debug\nrelease:\n\t$(MAKE) -C ../ android-release";
    close_out out;
  );

  (*let activity =
    Printf.sprintf "package %s;\n\nimport ru.redspell.lightning.LightActivity;\n\npublic class %s extends LightActivity {\n\tstatic {\n\t\tru.redspell.lightning.utils.Log.enabled = false;\n\t\tSystem.loadLibrary(\"%s\");\n\t}\n}"
                    !projPackage !projActivity !projSo
  in
  let packagePath = String.map (fun c -> if c = '.' then '/' else c) !projPackage in
  let out = open_out (!projPath // "src" // packagePath // (!projActivity ^ ".java")) in (
    output_string out activity;
    close_out out;
  );*)

  let out = open_out_gen [ Open_append ] 0o755 (!projPath // "local.properties") in (
    seek_out out (out_channel_length out);
    output_string out (Printf.sprintf "\nandroid.library.reference.1=%s/src/android/java\n" !projLightning);
    close_out out;
  );

  let out = open_out (!projPath // "res/values/ints.xml") in
    (
      output_string out "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n\t<integer name=\"google_play_services_version\">5089000</integer>\n</resources>";
      close_out out;
    );
);

value args = [
  ("-i", Set_string inDir, "\t\t\tinput directory (for example, farm root directory, which contains android subdirectory)");
  ("-manifest", Set manifest, "\t\tgenerate manifest for builds");
  ("-assets", Set assets, "\t\tgenerate assets for builds");
  ("-disable-ass-md5", Clear assetsMd5, "\tdisable md5 checking before generating assets");
  ("-exp", Set expansions, "\t\t\tgenerate expansions for builds");
  ("-base-exp", Set baseExp, "\t\tcreate symlink, named 'base', to this version on expansions in release archive");
  ("-exp-patch", Set_string patchFor, "\t\tgenerate expansions patch for version, passed through this option");
  ("-exp-ver", Set_string expVer, "\t\tuse expansions from version, passed through this option");
  ("-lib", Set lib, "\t\t\tbuild only so");
  ("-all-builds", Set allBuilds, "\t\tmake all builds");
  ("-apk", Set apk, "\t\t\tcompile apk for builds");
  (* ("-no-exp", Set noExp, "\t\tapplication has no expansions"); *)
  ("-without-lib", Set withoutLib, "\t\tcompile apk without farm-lib rebuilding, use it in addition -apk option");
  ("-release", Set release, "\t\tcompile apks for release, install from release archive, copy apk and expansions to release archive");
  ("-install", Tuple [ Set installApk; Set installExp; Set_string installSuffix; Rest (fun ver -> installVer.val := ver) ], "\t\tinstall both apk and expansions. when using with -release flag, takes build-version pair, when without -release -- only build.\n\t\t\texample: abldr -install normal_hdpi_pvr or abldr -release -install normal_hdpi_pvr 1.1.3");
  ("-install-apk", Tuple [ Set installApk; Set_string installSuffix; Rest (fun ver -> installVer.val := ver) ], "\t\tinstall only apk, usage same as -install");
  ("-install-exp", Tuple [ Set installExp; Set_string installSuffix; Rest (fun ver -> installVer.val := ver) ], "\t\tinstall only expansion, usage same as -install");

  ("-proj", Set proj, "\t\tcreate android project with all needed for light android builder");
  ("-proj-package", Set_string projPackage, "\tjava package of new project");
  ("-proj-app-name", Set_string projAppName, "\tapplication name");
  ("-proj-path", Set_string projPath, "\t\tdirectory, where project structure will be created, by default './android'");
  ("-proj-keystore-pass", Set_string projKeystorePass, "\tkeystore password, by default 'xyupizda'");
  ("-proj-with-exp", Set projWithExp, "\tpass with option if application with expansions");
  ("-proj-with-download", Set projWithDownload, "\tpass with option if application with expansions");
  ("-proj-so", Set_string projSo, "\t\tnative library name");
  ("-proj-lightning", Set_string projLightning, "\tpath to lightning");
  ("-do-not-clean-assets", Set doNotCleanAssets, "\tdon't clen assets folder");

  ("-lsync", Set lsync, "\tuse lsync instead of lsync2");
  ("-xml-file", Set_string abldr_xml, "\tname of abldr xml file by default abldr.xml"); 
];

parse args (fun arg -> builds.val := [ arg :: !builds ]) "android multiple apks generator";
builds.val := List.rev !builds;

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

type projConfig = {
  package:mutable string;
  version:mutable string;
  withExp:mutable bool;
  lsync2Defs: mutable list string;
  withDownload:mutable bool;
};

value readProjConfig () =
  let rec readProjConfig xmlinp projConfig =
    if Xmlm.eoi xmlinp then projConfig
    else (
      match Xmlm.input xmlinp with
      [ `El_start ((_, "package"), _) -> match Xmlm.input xmlinp with [ `Data data -> projConfig.package := data | _ -> () ]
      | `El_start ((_, "version"), _) -> match Xmlm.input xmlinp with [ `Data data -> projConfig.version := data | _ -> () ]
      | `El_start ((_, "withexp"), _) -> match Xmlm.input xmlinp with [ `Data data -> projConfig.withExp := bool_of_string data | _ -> () ]
      | `El_start ((_, "withdownload"), _) -> match Xmlm.input xmlinp with [ `Data data -> projConfig.withDownload := bool_of_string data | _ -> () ]
      | `El_start ((_, "lsync2-def"), attrs) ->
        let k = try List.find_map (fun ((_, n), v) -> if n = "key" then Some v else None) attrs with [ Not_found -> failwith "error parsing abldr.xml: <lsync2-def/> should contain 'key' attribute" ] in
        let v = try List.find_map (fun ((_, n), v) -> if n = "val" then Some v else None) attrs with [ Not_found -> failwith "error parsing abldr.xml: <lsync2-def/> should contain 'val' attribute" ] in
        let () = Printf.printf "new lsync2 def %s %s\n%!" k v in
          projConfig.lsync2Defs := [ (Printf.sprintf "-def %s=%s" k v) :: projConfig.lsync2Defs ]
      | _ -> ()
      ];

      readProjConfig xmlinp projConfig;
    )
  in
  let readAbldrXml file retval = 
    let inp = open_in (Filename.concat !inDir file) in
    let xmlinp = Xmlm.make_input ~strip:True (`Channel inp) in
      (
        ignore(Xmlm.input xmlinp);

        let retval = readProjConfig xmlinp retval in (
          close_in inp;
          myassert (retval.package <> "") "package not found in abldr project config";
          myassert (retval.version <> "") "version not found in abldr project config";
          retval;
        )
      )
  in
  let retval = { package = ""; version = ""; withExp = False; lsync2Defs = []; withDownload= False  } in 
  let retval = readAbldrXml "abldr.xml" retval in
  match !abldr_xml with
  [ "" -> retval 
  | file -> readAbldrXml file retval 
  ];


value projConfig () = Lazy.force (Lazy.from_fun readProjConfig);

value lsync2Cmd = 
  lazy ("lsync2 " ^ (String.concat " " (projConfig ()).lsync2Defs));

value lsync2Cmd () = Lazy.force lsync2Cmd;

value getPackage () = (projConfig ()).package;
value getVersion () = (projConfig ()).version;
value getWithExp () = (projConfig ()).withExp;
value getWithDownload () = (projConfig ()).withDownload;

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

value md5CheckPossible () = !assetsMd5 && Sys.command "which md5deep > /dev/null" = 0;

value genAssets build = (
  printf "\n\n[ generating assets for build %s... ]\n%!" build;

  mkdir assetsAresmkrDir;

  if !lsync
  then
    let commonAss = try Array.map (fun fname -> lsyncCommonAssets // fname) (Sys.readdir lsyncCommonAssets) with [ _ -> [||] ] in
    let buildAssDir = lsyncAssets build in
    let buildAss = try Array.map (fun fname -> buildAssDir // fname) (Sys.readdir buildAssDir) with [ _ -> [||] ] in
    let lsyncRules = Array.to_list (ExtArray.Array.filter (fun fname -> Sys.file_exists fname && not (Sys.is_directory fname)) (Array.concat [ commonAss; buildAss ])) in
    let lsyncRules = List.filter (fun rulesFname -> not ExtString.String.(starts_with (Filename.basename rulesFname) "." || ends_with rulesFname ".m4.include")) lsyncRules in
      runCommand ("lsync -i " ^ resDir ^ " -o " ^ assetsAresmkrDir ^ " " ^ (String.concat " " lsyncRules)) "lsync failed when copying assets"
  else
    let cmd = lsync2Cmd () in
    let cwd = Sys.getcwd () in
    let assetsDir = cwd // "_aresmkr/assets-raw" in
      (
        Sys.chdir "..";
        runCommand (Printf.sprintf "%s -def assetsDir=%s %s_assets" cmd assetsDir build) "lsync2 failed when copying assets";
        Sys.chdir cwd;
      );


  let md5Fname = aresmkrDir // "assets.md5" in
  let files = assetsAresmkrDir // "*" in
  let md5CheckPossible = md5CheckPossible () in
  let remakeAssets =
    if md5CheckPossible && Sys.file_exists md5Fname
    then Sys.command ("md5deep -r -x " ^ md5Fname ^ " " ^ files) = 1
    else True
  in
    if remakeAssets
    then (
      if md5CheckPossible then runCommand ("md5deep -rq " ^ files ^  " > " ^ md5Fname) "failed to make md5 hashes list" else ();
      runCommand("aresmkr -concat -i " ^ assetsAresmkrDir ^ " -o " ^ assetsAresmkrFname) "android resources maker failed when making assets";
    )
    else ();
);

value archiveApk ?(apk = True) ?(expansions = True) build =
  let ver = getVersion () in
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
            let copy fname =
              let fname = Filename.concat expDir fname in
                if Unix.((lstat fname).st_kind = S_LNK)
                then makeRelativeSymlink (Filename.concat expDir (Unix.readlink fname)) (Filename.concat apkArchiveDir (Filename.basename fname))
                else runCommand ("cp -Rv " ^ fname ^ " " ^ apkArchiveDir) ("cp failed when trying to copy " ^ fname ^ " to archive")
            in (
              copy fname;
              copy (fname ^ ".index");
            )
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
  printf "genExpansion\n%!";
  if !expVer <> "" then
    let () = printf "\n\n[ making symlinks to expansions for build %s... ]\n%!" build in
    let src = Filename.concat releaseDir (Filename.concat build !expVer) in
    let (main, patch) = findExpNames src in
    let dst = buildExpAresmkrDir build in
    let makeLink fname =
      if fname <> ""
      then
        let src = Filename.concat src fname in
        let dst = Filename.concat dst fname in (
          printf "\n\n[ creating links to expansions version %s (from %s to %s) ... ]\n%!" !expVer src dst;
          makeRelativeSymlink src dst;
          makeRelativeSymlink (src ^ ".index") (dst ^ ".index");
          printf "[ done ]\n%!";
        )
      else ()
    in (
      runCommand ("rm -f " ^ (Filename.concat dst "*.obb*")) "rm failed when trying to remove previous obbs";
      makeLink main;
      makeLink patch;
    )
  else
    let expDir = buildRawExpAresmkrDir build in
      (
        printf "\n\n[ generating expansions for build %s... ]\n%!" build;
        mkdir expDir;

        if !lsync
        then
          let commonExp = try Array.map (fun fname -> lsyncCommonExp // fname) (Sys.readdir lsyncCommonExp) with [ _ -> [||] ] in
          let buildExpDir = lsyncExp build in
          let buildExp = try Array.map (fun fname -> buildExpDir // fname) (Sys.readdir buildExpDir) with [ _ -> [||] ] in
          let lsyncRules = Array.to_list (ExtArray.Array.filter (fun fname -> Sys.file_exists fname && not (Sys.is_directory fname)) (Array.concat [ commonExp; buildExp ])) in
          let lsyncRules = List.filter (fun rulesFname -> not ExtString.String.(starts_with (Filename.basename rulesFname) "." || ends_with rulesFname ".m4.include")) lsyncRules in
            runCommand ("lsync -i " ^ resDir ^ " -o " ^ expDir ^ " " ^ (String.concat " " lsyncRules)) "lsync failed when copying expansions"
        else
          let cmd = lsync2Cmd () in
          let cwd = Sys.getcwd () in
          let expDir = cwd // expDir in
            (
              Sys.chdir "..";
              runCommand (Printf.sprintf "%s -def expDir=%s %s_exp" cmd expDir build) "lsync2 failed when copying expansions";
              Sys.chdir cwd;
            );

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
  let target = if (getWithDownload ()) then target ^ "-download" else target in
    runCommand ("make -f " ^ makefilePath ^ " " ^ target) "make failed when compiling lib";

value compileApk build =
(
  if !withoutLib then () else compileLib ();

  (* CLEANING ASSETS *)
  if !doNotCleanAssets
	then ()
	else cleanDir assetsDir;
  genAssets build;
  runCommand ("cp " ^ assetsAresmkrFname ^ " " ^ assetsDir ^ Filename.dir_sep) "failed when copying concated assets into android assets directory";

  if getWithExp () then
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

      myassert (main <> "") "main expansion not found, if app doesn't use expansions, put into abldr.xml <withexp>false</withexp>";

      let command = "aresmkr -o " ^ (Filename.concat assetsDir "index") ^ " -merge " ^ assetsAresmkrFname in
      let command = if patch <> "" then command ^ " " ^ (Filename.concat expansionsDir patch) else command in
        runCommand (command ^ " " ^ (Filename.concat expansionsDir main)) "failed when making assets and expansions binary index";
    )
  else
    runCommand ("aresmkr -o " ^ (Filename.concat assetsDir "index") ^ " -merge " ^ assetsAresmkrFname) "failed when making assets binary index";

  printf "\n\n[ compiling apk for build %s... ]\n%!" build;
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
      else if String.starts_with fname "main" && not (String.ends_with fname ".index") then (apk, fname, patch)
      else if String.starts_with fname "patch" && not (String.ends_with fname ".index") then (apk, main, fname) else (apk, main, patch)
    ) ("", "", "") (Sys.readdir archiveDir)
  in
  (
    if !installApk then
      if apk = "" then  failwith "apk is missing"
      else runCommand ("adb install -r " ^ (Filename.concat archiveDir apk)) "adb failed when installing apk"
    else ();

    if (getWithExp ()) && !installExp then
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

if !proj
then makeProject ()
else if !installApk || !installExp then install ()
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
      if !assets then genAssets build else ();
      if !expansions || !patchFor <> "" || !expVer <> "" then genExpansion build else ();
      if !apk then compileApk build else ();
    )
  ) !builds;
);
