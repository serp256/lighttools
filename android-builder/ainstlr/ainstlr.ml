let myassert exp mes = if not exp then ( Printf.printf "\n%!"; failwith mes ) else ();;

let runCommand command errMes =
(
    Printf.printf "%s\n%!" command;
    myassert (Sys.command command = 0) errMes;
);;

let (//) = Filename.concat;;
let args = ref [];;

Arg.parse [] (fun arg -> args := arg :: !args) "android installer";;

let ver = List.hd !args in
let id = List.hd (List.tl !args) in
let archiveDir = "android" // "release" // id // ver in
	let (apk, main, patch) =
		Array.fold_left (fun (apk, main, patch) fname ->
			if ExtString.String.ends_with fname ".apk" then (fname, main, patch)
			else if ExtString.String.starts_with fname "main" then (apk, fname, patch)
			else if ExtString.String.starts_with fname "patch" then (apk, main, fname) else (apk, main, patch)
		) ("", "", "") (Sys.readdir archiveDir)
	in
	(
		runCommand ("adb install -r " ^ (archiveDir // apk)) "error when uploading apk";

		if main <> "" && patch <> "" then
			let regex = Str.regexp "main\\.[0-9]+\\.\\(.*\\).obb" in
			let () = Printf.printf "main %s" main in
				if Str.string_match regex main 0 then
					let package = Str.matched_group 0 main in
					let pushCommand = "storage_dir=`adb shell 'echo -n $EXTERNAL_STORAGE'` && exp_dir=$storage_dir/Android/obb/" ^ package ^ " && adb shell \"mkdir -p $exp_dir\" && adb push " in
					(
						runCommand (pushCommand ^ (archiveDir // main) ^ " $exp_dir/") "error when uploading main expansion";
						runCommand (pushCommand ^ (archiveDir // patch) ^ " $exp_dir/") "error when uploading patch expansion";
					)					
				else failwith "wrong expansions name"
		else ();
	);;