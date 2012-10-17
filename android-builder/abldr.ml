open ExtString;
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

value inDir = ref ".";
value manifests: ref (list string) = ref [];

value manifest = ref False;
value assets = ref False;
value expansions = ref False;
value apk = ref False;
value release = ref False;
value archive = ref False;
value all = ref False;
value suffixes = ref [];

value args = [
	("-i", Set_string inDir, "input directory (for example, farm root directory, which contains android subdirectory)");
	("-manifest", Set manifest, "generate manifest for suffixes");
	("-assets", Set assets, "generate assets for suffixes");
	("-exp", Set expansions, "generate expansions for suffixes");
	("-apk", Set apk, "compile apk for suffixes");
	("-release", Set release, "compile apks for release");	
	("-archive", Set archive, "archive apk and expansions");	
	("-all", Set all, "perform all steps for suffiex")
];

parse args (fun arg -> suffixes.val := [ arg :: !suffixes ]) "android multiple apks generator, usage [<options>] [<siffixes>...]";
suffixes.val := List.rev !suffixes;

if String.ends_with !inDir "/" then () else inDir.val := !inDir ^ "/";

value androidDir = !inDir ^ "android/";
value manifestsDir = androidDir ^ "manifests/";
value expansionsDir = androidDir ^ "expansions/";
value rsyncDir = androidDir ^ "rsync/";
value resDir = !inDir ^ "Resources/";
value assetsDir = androidDir ^ "assets/";
value makefilePath = !inDir ^ "Makefile";
value archiveDir = androidDir ^ "archive/";

value genManifest suffix =
	let manifestConfig = manifestsDir ^ suffix ^ ".xml" in
	(
		printf "\n\n[ generating manifest for suffix %s... ]\n%!" suffix;
		myassert (Sys.file_exists manifestConfig) (sprintf "cannot find manifest config for suffix %s" suffix);
		myassert (Sys.command ("xsltproc -o " ^ androidDir ^ "AndroidManifest.xml --xinclude --xincludestyle " ^ manifestsDir ^ "manifest.xslt " ^ manifestConfig) = 0) "xsltproc failed";
	);

value genAssets suffix =
	let suffixFilter = rsyncDir ^ "android-" ^ suffix ^ "-assets.filter" in
		let suffixFilter = if Sys.file_exists suffixFilter then " --filter='. " ^ suffixFilter ^ "'" else "" in
		(
			printf "\n\n[ generating assets for suffix %s... ]\n%!" suffix;
			myassert (Sys.command ("rsync -avL --include-from=" ^ rsyncDir ^ "android-assets.include" ^ suffixFilter ^ " --exclude-from=" ^ rsyncDir ^ "android-assets.exclude --delete --delete-excluded " ^ resDir ^ " " ^ assetsDir) = 0) "rsync failed when copying assets";
		);

value genMainExpansion suffix =
	let expDir = expansionsDir ^ suffix ^ "/main"	
	and suffixFilter = rsyncDir ^ "android-" ^ suffix ^ "-expansions.filter" in
		let suffixFilter = if Sys.file_exists suffixFilter then " --filter='. " ^ suffixFilter ^ "'" else "" in
		(
			printf "\n\n[ generating expansions for suffix %s... ]\n%!" suffix;
			mkdir expDir;
			myassert (Sys.command ("rsync -avL --filter='protect locale/*/sounds' --filter='protect sounds' --include-from=" ^ rsyncDir ^ "android-expansions.include" ^ suffixFilter ^ " --exclude-from=" ^ rsyncDir ^ "android-expansions.exclude --delete --delete-excluded " ^ resDir ^ " " ^ expDir) = 0) "rsync failed when copying expansions";
			myassert (Sys.command ("rsync -avL --exclude=.DS_Store --delete --delete-excluded " ^ resDir ^ "sounds_android/default/ " ^ expDir ^ "/sounds/") = 0) "rsync failed when copying default sounds";
			myassert (Sys.command ("rsync -avL --exclude=.DS_Store --delete --delete-excluded " ^ resDir ^ "sounds_android/en/ " ^ expDir ^ "/locale/en/sounds/") = 0) "rsync failed when copying en sounds";
			myassert (Sys.command ("rsync -avL --exclude=.DS_Store --delete --delete-excluded " ^ resDir ^ "sounds_android/ru/ " ^ expDir ^ "/locale/ru/sounds/") = 0) "rsync failed when copying ru sounds";
			myassert (Sys.command ("make -f " ^ makefilePath ^ " EXP_SUFFIX=" ^ suffix ^ " android-expansions-fresh") = 0) "make failed when packing expansions";
		);

value compileApk suffix =
	let target = if !release then "android-release" else "android" in
	(
		printf "\n\n[ compiling apk for suffix %s... ]\n%!" suffix;
		myassert (Sys.command ("make -f " ^ makefilePath ^ " " ^ target) = 0) "make failed when compiling apk";
	);

value archiveApk suffix =
	let ver =
		let inchan = open_in (androidDir ^ "version") in
			let ver = input_line inchan in
			(
				close_in inchan;
				ver;
			)
	in
		let apkArchiveDir = archiveDir ^ suffix ^ "/" ^ ver in
		(
			printf "\n\n[ archiving version %s for suffix %s... ]\n%!" ver suffix;

			mkdir apkArchiveDir;

			myassert (Sys.command ("cp `find " ^ androidDir ^ "/bin -name '*-release.apk'` " ^ apkArchiveDir) = 0) "cp failed when trying to copy apk to archive";
			myassert (Sys.command ("cp `find " ^ expansionsDir ^ suffix ^ " -name '*obb'` " ^ apkArchiveDir) = 0) "cp failed when trying to copy main expansion to archive";
		);

List.iter (fun suffix ->
	(
		printf "processing suffix %s...\n%!" suffix;

		if !manifest || !apk || !all then genManifest suffix else ();
		if !assets || !apk || !all then genAssets suffix else ();
		if !expansions || !all then genMainExpansion suffix else ();
		if !apk || !all then compileApk suffix else ();
		if !archive || !all then archiveApk suffix else ();
	)
) !suffixes;