open Arg;

value all_const = "all";
value param_name = "param_name";
value empty_param_name = "empty_param_name";
value include_param = "include";
value header_param = "header";

value main_path = "download_pack/";
value raw_path = main_path ^ "raw/";
value tmp_data = main_path ^ "tmp_data/";
value data_path = main_path ^ "data/";

value rule_file = ref "lsync2_rules.ml";

value version = ref 0;
value conf_file = ref "resconfig";
value only_raw = ref False;

value htbl = Hashtbl.create 100;
value ios_vers = ref "";
value android_vers = ref "";

value createHtbl () = 
(
	ignore(Sys.command (Printf.sprintf "mkdir -p %s" data_path));

	Array.iter (fun fname -> (
		if ExtString.String.ends_with fname ".json" then () 
		else
			let index = (ExtString.String.find fname "_") in
			let vers = int_of_string (String.sub fname 0 index )
			and name = String.sub fname (index + 1) ((String.length fname) - index - 1) 
			and md5 = (Digest.to_hex (Digest.file (Printf.sprintf "%s%s" data_path fname)))
			in
			(
				Printf.printf "[%d][%s][%s]\n" vers name md5;
				Hashtbl.replace htbl (vers,name) md5;
			);
	) ) (Sys.readdir data_path);
);

value getFile fname md5 = 
(
	let ver = ref None in
	(
		Hashtbl.iter (fun (vers,name) m -> (
			if md5 = m && name = fname then ver.val := Some vers else ();
		) ) htbl;
		!ver;
	);
);

value final json = 
(
	if json = [] then True else False;
(* 	not (List.exists (fun (name, json) -> ( *)
(* 		match json with  *)
(* 		[ `String _ -> False *)
(* 		| _ -> True  *)
(* 		] *)
(* 	) ) json); *)
);

value getParamName lst = 
(
	let htbl = Hashtbl.create 10 in
	let param = ref "" in 
	let path = ref "" in
	(
		List.iter (fun (key, vl) -> (
			if Hashtbl.mem htbl key then () else 
			(
				Hashtbl.replace htbl key vl;
				param.val := Printf.sprintf "%s -def %s=\"%s\"" !param key vl;
			);
			path.val := Printf.sprintf "%s%s%s" !path (if !path = "" then "" else "_") vl;
		) ) (List.rev lst);

		(!path, !param);
	);
);

value cmnd text = 
(
  Printf.printf "%s\n%!" text;
	assert(Sys.command text = 0);
);

value start_convert lst = 
	let (path, param) = getParamName lst in
	(
		let in_file = Printf.sprintf "%s%s" raw_path path in 
		let command = (Printf.sprintf "lsync2 -def rule_file=\"%s\" %s -def path=\"%s\" downloader" !rule_file param in_file) in 
		(
(* 			Printf.printf "[%s]\n\n" command; *)
(* 			if True then () else *)
			(
			ignore(cmnd (Printf.sprintf "rm -rf %s" in_file ));
			ignore(cmnd (Printf.sprintf "mkdir -p %s" in_file ));
			ignore(cmnd command);
			);

			if !only_raw then [] else

			let ar = Sys.readdir in_file in 
			(
				List.map (fun fname -> (
					let out_file = Printf.sprintf "%s%s/%s" tmp_data path fname 
					in 
					let command = Printf.sprintf "resmkr -concat -combine -i %s/%s -o %s" in_file fname out_file
					in 
					(
(* 						if True then () else *)
						(
						ignore(cmnd (Printf.sprintf "mkdir -p %s%s" tmp_data path));
						ignore(cmnd command);
						);

						let md5 = (Digest.to_hex (Digest.file out_file))
						in
						(
							Printf.printf "%s_%s md5 %s\n" path fname md5;
							match getFile (Printf.sprintf "%s_%s" path fname) md5 with
							[ Some vers -> (Printf.sprintf "%d_%s_%s" vers path fname, md5)
							| _ -> 
								(
									let path_data = Printf.sprintf "%d_%s_%s" !version path fname in
									let command = Printf.sprintf "mv %s %s%s" out_file data_path path_data in 
									(
										Hashtbl.replace htbl (!version, Printf.sprintf "%s_%s" path fname) md5;
										Printf.printf "%s" command;
										ignore(cmnd command);
										(path_data, md5)
									)
								)
							];
						);
					)
				) ) (Array.to_list ar);
			);
		);
	);

value used_resources = ref [];

value rec read_json ~key ~json ~params ~list_files ~header_files () = 
(
(*
	Printf.printf "<< %s " key;
	List.iter (fun (a,b) -> (
		Printf.printf "[%s/%s]" a b;
	) ) params;
	Printf.printf ">>\n";
	*)
	match json with
	[ `Assoc packs ->
		(
			if final packs then
			(
				let lst = (List.map (fun (name, json) -> ( name , match json with [ `String name -> name | _ -> assert False ] ) ) packs ) @ params in 
				(
					start_convert lst
				);
			)
			else
			(
				let param_name_value = 
					try 
						match snd (
							List.find (fun (name,json) -> (
								name = param_name
							) ) packs) with
						[ `String name -> name
						| _ -> assert False
						]
					with [ Not_found -> empty_param_name ] 
				in
				let new_files_list = ref list_files in 
				let headers = ref header_files in 
				(
(* 					Printf.printf "PARAM_NAME %s" param_name_value ; *)
					List.iter ( fun (name,json) -> 
						if name = param_name then () else
						if name = header_param then
						(
							match json with
							[ `Assoc json ->
								List.iter (fun (n,j) -> (
									let call_params = [(name, n) :: params] in 
									(
										let files = read_json ~key:n ~json:j ~params:call_params ~list_files ~header_files () in
										(
											headers.val := [ (n,files) :: !headers ];
										);
									);
								) ) json
							| _ -> assert False
							];
						)
						else 
						if name = include_param then 
						(
							match json with
							[ `List include_list -> 
								(
									List.iter (fun text -> (
										match text with 
										[ `String text -> 
											let params = 
												List.find (fun (name, params) -> (
													name = text 
												) ) header_files
											in
											(
												new_files_list.val := (snd params) @ !new_files_list;
											)
										| _ -> assert False
										];
									) ) include_list;
								)
							| _ -> ()
							];
						)
						else
						(
							let call_params = [(param_name_value, name) :: params] in 
							(
								let files = read_json ~key:name ~json ~params:call_params ~list_files:!new_files_list ~header_files:!headers () in
								(
									if name = all_const then
										new_files_list.val := files @ !new_files_list
									else ();
								);
							);
						);
					) packs;
				);
				[];
			);
		)
	| `String name -> 
		(
			let call_params = [ (key, name) :: params ] in 
			(
				let data_list = start_convert call_params
				in
				(
					List.iter (fun (fname,md5) -> (
						Printf.printf "JSON [%s][%s]\n" fname md5;
						used_resources.val := [ fname :: !used_resources ];
					) ) (data_list @ list_files);

					let text  =
						List.fold_left (fun str (elem,md5) -> (
							if str = "" then Printf.sprintf "\"%s\":\"%s\"" elem md5 
							else Printf.sprintf "%s,\"%s\":\"%s\"" str elem md5
						) ) "" (data_list @ list_files)
					in
					(
						let name = 
							if ExtString.String.starts_with name "ios" then  
								(Printf.sprintf "%s%s_%s" data_path !ios_vers name)
							else
							if ExtString.String.starts_with name "android" then  
								(Printf.sprintf "%s%s_%s" data_path !android_vers name)
							else
								failwith "В строках где должно быть имена json-ок должны указываться тип устройства в начале строки"
						in
							Ojson.to_file name (Ojson.from_string (Printf.sprintf "{%s}" text))
					);
				);
			);
			[]
		)
	| _ -> assert False 
	];
);

value run conf_name = 
(
	ignore (read_json ~key:"" ~json:(Ojson.from_file conf_name) ~params:[] ~list_files:[] ~header_files:[] ());
);

value show_unused () =
(
	Printf.printf "============ UNUSED FILES ==============\n";
	Array.iter (fun fname -> (
		if ExtString.String.ends_with fname ".json" then () 
		else
		if List.exists (fun name -> fname = name) !used_resources then () 
		else
			Printf.printf "%s\n" fname ;
	) ) (Sys.readdir data_path);
	Printf.printf "============ UNUSED FILES END ==========\n";
);

value () = 
(
	Arg.parse [
		("-v", Set_int version, "version resources");
		("-i", Set_string conf_file, "configuration file - default resconfig");
		("-only_raw",Set only_raw, "only raw");
		("-ios-vers",Set_string ios_vers, "ios apps version (for json name)");
		("-android-vers",Set_string android_vers, "android apps version (for json name)");
		("-lsync2-file",Set_string rule_file, "lsync file")
	] ( fun _ -> () ) "";

	if !ios_vers = "" then failwith "Need -ios-vers param" else ();
	if !android_vers = "" then failwith "Need -android-vers param" else ();
	if !version = 0 then failwith "Need -v param" else ();



	createHtbl ();
	run !conf_file; 	
	show_unused ();
);

