open ExtList;
open ExtString;

value texInfo        = "texInfo.dat";
value frames         = "frames.dat";

value (///)          = Filename.concat;

value no_anim_prefix = [ "an_"; "bl_"; "dc_"; "mn_" ];

value inp_dir        = ref "input"; 
value outdir         = ref "output";
value gen_pvr        = ref False;
value gen_dxt        = ref False;
value degree4        = ref False;
value is_gamma_gin   = ref False;
value is_gamma_steam = ref False;
value scale          = ref 1.;
(* value scale          = ref 1.; *)
value without_cntr   = ref False;
value is_android     = ref False;
value no_anim        = ref False;
value suffix         = ref "";

value json_name      = ref "";
value useScaleXY     = ref False;
value alpha_for_crop = ref 0;
value filter_conf   = ref None;
value get_postfix () = !suffix;


type pack_info        = {
		name :		string;
		objs :		list string;
		wholly :	bool;
		animated : bool;
  	scale : float;
};



value get_packs objs = 
  let libs = ref objs in
  let read_json json =
	match json with
	[ `Assoc packs ->
		(
		  List.map begin fun (name,json) -> 
			(

			  match json with
			  [ `Assoc params ->
				  let wholly = 
						try
						  match List.assoc "whooly" params with
						  [ `Bool wholly -> wholly
						  | _ -> assert False 
						  ]
						with
							[ Not_found -> False ]
				  
				  and animated = 
						try 
							match List.assoc "animated" params with
							[ `Bool anim -> anim
							| _ -> assert False 
							]						
						with [ Not_found -> not !no_anim ]
				  in

				  let include_libs = 
					let ls = List.assoc "include" params in
					match ls with
					[ `List ls ->
						List.fold_left begin fun res reg ->
						  match reg with
						  [ `String reg_str | `Intlit reg_str -> 
							  let reg = Str.regexp reg_str in
							  let (libs_filter,old_libs) = List.partition (fun lib -> Str.string_match reg lib 0) !libs in
								(
								  libs.val := old_libs;
								  libs_filter @ res 
								)
						  | _ -> assert False
						  ]
						end [] ls
					| _ -> assert False
					]
				  in
				  let pack_libs = 
					try
					  let ls = List.assoc "exclude" params in
					  match ls with
					  [ `List ls ->
						(
						  (* Printf.printf "include_libs  : [%s]  \n%!" (String.concat "; " include_libs); *)
						  let libs' =
							List.fold_left begin fun res reg ->
							  match reg with
							  [ `String reg_str | `Intlit reg_str -> 
								  let reg = Str.regexp reg_str in
								  let (exclude_libs,libs_filter) = List.partition (fun lib -> Str.string_match reg lib 0) res in
									(
									  Printf.printf "reg_str : %S; exclude_libs  : [%s]  \n%!" reg_str (String.concat "; " exclude_libs);
									  libs.val := !libs @ exclude_libs ;
									  libs_filter 
									)
							  | _ -> assert False
							  ]
							end include_libs ls
						  in
							(
							  (* Printf.printf "result libs  : [%s]  \n%!" (String.concat "; " libs'); *)
							  libs'
							)
						) 
					  | _ -> assert False
					  ]
					with
					  [ Not_found -> include_libs ]
				  in
            let scale = 
              try
                let scale = List.assoc "scale" params in
                match scale with
                [ `Float sc -> sc
                | `Int sc -> float sc
                | _ -> assert False
                ]
              with
                [  Not_found -> 1. ]
            in
		    (
              { name; objs = pack_libs; wholly; scale; animated }
		    )
		
		  | _ -> assert False 
		  ]
		  ) 
		  end packs,
		  !libs
		)
	| _ -> assert False 
	]
  in
  read_json (Ojson.from_file !json_name);



Gc.set {(Gc.get()) with Gc.max_overhead = 2000000};

  Arg.parse 
	[
		("-inp",			Arg.Set_string inp_dir,	"input directory");
		("-o",				Arg.Set_string outdir,	"output directory");
		("-pvr",			Arg.Set gen_pvr,		"generate pvr file");
		("-dxt",			Arg.Set gen_dxt,		"generate dxt file");        
		("-p",				Arg.Set_int TextureLayout.countEmptyPixels,	"count Empty pixels between images");
		("-min",			Arg.Set_int TextureLayout.min_size,			"Min size texture");
		("-max",			Arg.Set_int TextureLayout.max_size,			"Max size texture");
		("-scale",			Arg.Set_float scale,	"Scale factor");
		("-degree4",		Arg.Set degree4,		"Use degree 4 rects");
		("-without-cntr",	Arg.Set without_cntr,	"Not generate counters");
		("-android",		Arg.Set is_android,		"Textures for android");
		("-no-anim",		Arg.Set no_anim,		"Skip expansion animations");
		("-suffix",			Arg.Set_string suffix,	"add suffix to library name");
		("-gamma-steam",	  Arg.Set is_gamma_steam,		"add conver -gamma 1.1 call for result image");
		("-gamma-gin",			Arg.Set is_gamma_gin,		"add conver -gamma 1.1 call for result image");
		("-useScaleXY",			Arg.Set useScaleXY,		"use in params scaleX scaleY only match3 ");
		("-alpha_for_crop",	Arg.Set_int alpha_for_crop,		"value alpha for crop image, by default 0");
        ("-filter",        Arg.String (fun str -> filter_conf.val := Some str), "path to config");
	]

	(fun name -> json_name.val := name)

	"";

	TextureLayout.countEmptyPixels.val := 0;

	TextureLayout.rotate.val := False;




(* value prjDir = "/home/xalt/Projects/ScalePrj"; *)


(* Если нет out директории, создаём *)
Utils.makeDir !outdir;

module Pug = Pug.Make(
  	struct
      value suffix       = !suffix;
      value prjName      = "farm";
      value prjDir       = !inp_dir;
      value outDir       = !outdir;
      value imgDir       = Filename.concat prjDir "img";
      value scale        = !scale;
      value useScaleXY   = !useScaleXY;

      value gen_pvr      = !gen_pvr;
      value gen_dxt      = !gen_dxt;
      value degree4      = !degree4;
      value is_gamma_steam     = !is_gamma_steam;
      value is_gamma_gin     = !is_gamma_gin;
      value without_cntr = !without_cntr;
      value is_android   = !is_android;
      value no_anim      = !no_anim;
      value alpha_for_crop  = !alpha_for_crop;
      value filter_conf = FiltersConf.get !filter_conf;
  	end
);


(* Pug.readPrjName; *)
(* exit 0; *)
(* Printf.printf "\n Pug.prjName %s\n" (Pug1.prjName);  *)
(* exit 0; *)

value postfixs = [ "_sh"; "_ex" ];

value split_pack pack = 
  let (packs, remain_pack)        = 
	List.fold_left (fun (res, pack) pstfx  ->
	  	let new_name				= pack.name ^ pstfx in
	  	let (new_libs, remain_libs)	= List.partition (fun lib -> String.ends_with lib "_ex" || String.ends_with lib "_sh") pack.objs in
      ( [ {name					= new_name; objs = new_libs; wholly = pack.wholly; scale= pack.scale; animated = pack.animated} :: res ], {(pack) with objs=remain_libs})
	)  ([], pack) [ "_ex" ]
  in
  packs @ [ remain_pack ];



(* Record актуальных либ *)
value getActualLibsFromJson allObjs = (
	let (libs, other_libs)	= get_packs allObjs in (
	let libs_split = 
    List.fold_left (fun packs' pack -> (
  		let split_packs		= split_pack pack in
	  	packs' @ split_packs
	  )) [] libs 
  in 
	(libs_split,other_libs)
  )
);



(* Запись info_objects.bin *)
value writeInfoObjects infObjs = (
    let () = Printf.printf "WRITE INFO OBJECTS" in
	let infobjOut	= IO.output_string () in
	let _			= (
	  	IO.write_i16 infobjOut (List.length infObjs);
	  	List.iter (fun (w,h,name) -> (
            Printf.printf "write to info_objects %s \n%!" name;
		    IO.write_byte   infobjOut (int_of_float w);
	  	    IO.write_byte   infobjOut (int_of_float h);
  		    Utils.writeUTF  infobjOut name;
	  	)) infObjs
	) in
	
	let infobjOut	= IO.close_out infobjOut in
	let out		= open_out (!outdir /// "info_object.bin") in (
	  output out infobjOut 0 (String.length infobjOut);
	  close_out out;
	)
);


(* TextureLayout.max_size.val := 1024; *)

let dsrlzr  = Deserializer.run !inp_dir in 
let ()      = Printf.printf "RUN\n" in 
let prj     = (Deserializer.project dsrlzr) in

(* Список всех объектов проекта *)
let (allObjs, infObjs) = 
  	List.fold_left (fun (objsLst, infObjs) o -> (
		(objsLst @ [Node.Object.name o], [(Node.Object.width o, Node.Object.height o, Node.Object.name o)::infObjs])
  	)) ([],[]) (Node.Project.objects prj)
in


let (packs, other_libs)	= getActualLibsFromJson allObjs in
let () = Printf.printf "Count other_libs : %d\n%!" (List.length other_libs) in 


let infObjs = List.filter (fun (_,_,name) -> not (List.mem name other_libs)) infObjs in
(
  writeInfoObjects infObjs;
	List.iter (fun pack -> (Pug.writeLibData prj pack.name pack.objs pack.wholly pack.scale pack.animated)) packs
);




match !without_cntr with
	[ False -> 
    let sfx = 
      match !suffix with
      [ "" -> ""
      | sfx -> "-s " ^ sfx 
      ]
    in
		let cmd = Printf.sprintf "cntrgen %s  -i %s" sfx !outdir in (
			Printf.printf "\n%s\n%!" cmd;
			match Sys.command cmd with
			[ 0 -> ()
			| _ -> Printf.printf "\n === WARNING!!! ERROR GEN COUNTER === \n"
			]
		)
	| _ -> ()
	];


(* Printf.printf "\n TextureLayout.max_size.val %d\n" (!TextureLayout.max_size); *)
