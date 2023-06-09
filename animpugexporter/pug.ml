open Node;
open Images;

module type P =
  sig
  value suffix : string;
	value prjName:  	string;
	value prjDir:   	string;
	value outDir:		string;
	value imgDir:   	string;
	value scale:		float;
	value gen_pvr:		bool;
	value gen_dxt:		bool;
	value degree4:		bool;
	value is_gamma_steam:		bool;
	value is_gamma_gin:		bool;
	value without_cntr:	bool;
	value is_android:	bool;
	value no_anim:		bool;
  value useScaleXY  : bool;
  value alpha_for_crop : int;
  value filter_conf : option FiltersConf.t;
  end;



type rects = 
  {
	rx : int;
	ry : int;
	rw : int;
	rh : int;
  };

(* type imgs = 
  {
	path : string;
	rect : rects;
  }; *)


value no_anim_prefix = [ "an_"; "bl_"; "dc_"; "mn_" ];

value (///) = Filename.concat;

(* value setPrj = (
	P.

); *)


module Make(P:P) =
  struct
	(* Общий прямоугольник файлов анимации *)
	value calcAnimRects a = (
	  let (x, y, w, h) = 
		  List.fold_left (fun bnds f ->
			let fx = Frame.x f in
			let fy = Frame.y f in
			  List.fold_left (fun bnds' l ->
				let (w, h) = (
				  try
					Utils.pngDims (P.imgDir /// (Layer.imgPath l))
				  with [
					Sys_error e -> (
					  Printf.printf "\nWARNING ERROR!\t%s\n%!" e;
					  (0, 0)
					)
				  ]
				) in(
				  Utils.rectsUnion bnds' (fx +. Layer.x l, fy +. Layer.y l, float w, float h);
				)
			  ) bnds (Common.childs f)
		  ) (0., 0., 0., 0.) (Common.childs a)
	  in (
		(x, y, w, h)
	  )
	);

  type crop_info = 
    {
      t : int;
      b : int;
      l : int;
      r : int;
    };

	type img = 
	  {
	  	tt_index:	int;
	  	img_index:	int;
		  rect :		rects;
      crop_info : crop_info;
	  };


	(* Запись animations.dat *)
	(* @return	int	numFrames	число фреймов в объекте *)
	value writeAnimationsDat o pack_scale animated = (
		let oname		= Object.name o in
		let animsOut	= IO.output_string () in
        let scale = P.scale *. (FiltersConf.get_scale P.filter_conf oname) in
		let numFrames	= (
			IO.write_ui16 animsOut 1;
			Utils.writeUTF animsOut oname;
			let numAnims  = Common.childsNum o in	IO.write_ui16 animsOut numAnims;
			let numFrames= 
				List.fold_left (fun frmIndx a -> (
					let aname		= Animation.name a in
					let _			= Utils.writeUTF animsOut aname in
					let frmRt		= Int32.bits_of_float (Animation.frameRate a) in IO.write_real_i32 animsOut frmRt;
					let rects		= Animation.rects a in 
					let numRects	= List.length rects in (
						(* Минимум всегда 1 прямоугольник *)
						if numRects > 0 then IO.write_byte animsOut numRects else IO.write_byte animsOut 1;

						if numRects > 0 then
							List.iter (fun r -> (
									(* Printf.printf "\n1oname %s; %f %f %f %f\n" oname r.Rect.x r.Rect.y r.Rect.width r.Rect.height; *)
									IO.write_i16 animsOut (truncate (scale *. r.Rect.x));
									IO.write_i16 animsOut (truncate (scale *. r.Rect.y));
									IO.write_i16 animsOut (truncate (scale *. r.Rect.width));
									IO.write_i16 animsOut (truncate (scale *. r.Rect.height));
								)
							) rects
						else (
							let (x, y, w, h) = calcAnimRects a in (
								(* Printf.printf "\n2oname %s; %f %f %f %f\n" oname x y w h; *)
								IO.write_i16 animsOut (truncate (scale *. x));
								IO.write_i16 animsOut (truncate (scale *. y));
								IO.write_i16 animsOut (truncate (scale *. w));
								IO.write_i16 animsOut (truncate (scale *. h));
							)
						)
					);

					let frmIndx = 
						match (* P.no_anim *) animated with
						[ True -> (
							
							let numFrames = Common.childsNum a 
							in 	IO.write_ui16 animsOut numFrames;
					    	
					    	List.fold_left (fun frmIndx' f -> (
						        IO.write_i32 animsOut frmIndx';
								frmIndx' + 1
							)) frmIndx (Common.childs a)
							
						  )
						(* Для случая отключение анимации *)
						| False -> (
							IO.write_ui16 animsOut 1;
							IO.write_i32 animsOut frmIndx; (* KMD *)
							1 + frmIndx
						  )
						]
					in frmIndx
					)
				) 0 (Common.childs o);
			numFrames
		) 
		in
		let animsOut	= IO.close_out animsOut in
        let out			= open_out (P.outDir /// oname /// "animations" ^ P.suffix ^ ".dat") in (
        	output out animsOut 0 (String.length animsOut);
            close_out out;
            numFrames
        )
	);

	(* Запись frames.dat *)
	value writeFramesDat o numFrames ttInfHash pack_scale animated = (
		let oname		= Object.name o in
        let scale = P.scale *. (FiltersConf.get_scale P.filter_conf oname) in
		let framesOut	= IO.output_string () in
		let _			= (
			IO.write_i32 framesOut numFrames;
			(* Фреймы *)
			List.iter (fun a -> (
				let animLst = Common.childs a in
				(* Берем первый кадр если отключена анимация *)
				let animLst = if (not animated) then [List.hd animLst] else animLst in
				List.iter (fun f -> (
					
					let fx			= Utils.roundi (scale *. (Frame.x f)) in
					let fy			= Utils.roundi (scale *. (Frame.y f)) in
					let iconX		= Utils.roundi (scale *. (Animation.iconX a)) in
					let iconY		= Utils.roundi (scale *. (Animation.iconY a)) in
					let points		= Frame.points f in
					let numPoints	= List.length points in
					let _			= (
						IO.write_i16	framesOut fx;
						IO.write_i16	framesOut fy;
						IO.write_i16	framesOut iconX;
						IO.write_i16	framesOut iconY;
						IO.write_byte	framesOut numPoints;

						(* Cписок свойств точек *)
						List.iter (fun p -> (
							let px    = Utils.roundi (scale *. (Point.x p)) in
							let py    = Utils.roundi (scale *. (Point.y p)) in
							let label = Point.label p in (
								IO.write_i16	framesOut px;
								IO.write_i16	framesOut py;
								Utils.writeUTF	framesOut label;
							)
						)) points;
					) in
					(* Слои *)
					let numLayers	= Common.childsNum f in
					let _			= IO.write_byte	framesOut numLayers in
					List.iter (fun l -> (
						let imgPath		= Layer.imgPath l in
						let imgRcd		= Hashtbl.find ttInfHash (oname, imgPath) in
						let flip		= Utils.int_of_bool (Layer.flip l ) in
            let crop_l = 
              match flip with
              [ 0 -> imgRcd.crop_info.l
              | _ -> imgRcd.crop_info.r
              ]
            in
            let () = Printf.printf "imgPath : %s; imgRcd : %d ; layer_scale : %f \n%!" imgPath imgRcd.img_index (Layer.scale l) in
            let () = Printf.printf "scale : %f; lx =%f; ly=%f; fx=%d; fy=%d; crop_info.l =%d; crop_info.t=%d \n%!" scale (Layer.x l) (Layer.y l) fx fy crop_l imgRcd.crop_info.t  in
						(* let imgRcd		= List.find (fun (i:img) -> i.path = imgPath)	imgsInfLst in *)
            let lx			= Utils.roundi (scale *. (Layer.x l)) + fx + (Utils.roundi ((float crop_l) *. (Layer.scale l))) in
						let ly			= Utils.roundi (scale *. (Layer.y l)) + fy + (Utils.roundi ((float imgRcd.crop_info.t) *. (Layer.scale l))) in
						(* let lx			= Utils.round (scale *. ((Layer.x l) +. (Frame.x fstFrm)) -.  (float fx)) in *)
						let alpha		= int_of_float (Layer.alpha l ) in
						let scale		= Int32.bits_of_float (Layer.scale l )  in
            let scaleXY =
              match P.useScaleXY with
              [ True -> 
                  let sx = Layer.scaleX l in
                  let sy = Layer.scaleY l in
                  (
                    Printf.printf "scaleX : %f; scaleY : %f\n%!" sx sy;
                    Some (Int32.bits_of_float sx, Int32.bits_of_float sy )
                  )
              | _ -> None
              ]
            in (
							(* TODO Возможно на клиенте индекс начинается с 1 *)
							(* IO.write_byte		framesOut imgRcd.tt_index; *) (*texID*)
							IO.write_i16		framesOut imgRcd.tt_index; (*texID*)
							IO.write_i32		framesOut imgRcd.img_index; (* rectId *)
							IO.write_i16 		framesOut lx;
							IO.write_i16 		framesOut ly;
		          IO.write_byte		framesOut alpha;
		          IO.write_byte		framesOut flip;
		          IO.write_real_i32	framesOut scale;
              match scaleXY with
              [ Some (scaleX, scaleY) -> 
                  (
                    IO.write_real_i32	framesOut scaleX;
                    IO.write_real_i32	framesOut scaleY;
                  )
              | _ -> ()
              ]
						)
					)) (Common.childs f)

				)) animLst;
			)) (Common.childs o);


		) in
		let framesOut	= IO.close_out framesOut in
        let out			= open_out (P.outDir /// oname /// "frames" ^ P.suffix ^ ".dat") in (
        	output out framesOut 0 (String.length framesOut);
            close_out out;
        )
	);


(* Собираем уникальные картинки с объекта *)
value makeLstImgs o animated = (
		List.fold_left (fun allimgs a -> (
		
		    let frames = 
		      if (animated) then
    		      (Common.childs a) 
    		  else
    		      [List.hd (Common.childs a)]
		    in

			List.fold_left (fun imgsf f -> (
				List.fold_left (fun imgsl l -> (
					let imgPath = Layer.imgPath l in
					if (List.mem imgPath imgsl) then
						imgsl
					else (
						 [imgPath :: imgsl]
					)
				
				)) imgsf (Common.childs f)
				
			)) allimgs frames
		)) [] (Common.childs o)
	);



  value crop_image img_src = 
    let (w,h) = Images.size img_src in
    let () = Printf.printf "CROP IMAGE %dx%d  \n%!" w h in
    match img_src with
    [ Images.Rgba32 img when (h > 1 && w > 1) ->
       let is_empty_col x =
         let rec loop y =
           match y < h with
           [ True -> 
              let rgba = Rgba32.get img x y  in
              match rgba.Color.alpha > P.alpha_for_crop with
              [ True -> False
              | _ -> loop (y + 1)
              ]
           | _ -> True
           ]
         in
         loop 0
       in
       let is_empty_row y =
         let rec loop x =
           match x < w with
           [ True -> 
              let rgba = Rgba32.get img x y  in
              match rgba.Color.alpha > P.alpha_for_crop with
              [ True -> False
              | _ -> loop (x + 1)
              ]
           | _ -> True
           ]
         in
         loop 0
       in
       let left = ref 0 in
       let right = ref 0 in
       let top = ref 0 in
       let bottom = ref 0 in
        (
           while is_empty_col !left do
            incr left
           done;

           while is_empty_col (w - !right - 1) do
             incr right;
           done;

           while is_empty_row !top do
            incr top
           done;

           while is_empty_row (h - !bottom - 1) do
             incr bottom;
           done;
           Printf.printf "CROP INFO : l = %d; r=%d; t=%d; b=%d \n%!" !left !right !top !bottom ;
           (
             Images.sub img_src !left !top (w - !left - !right) (h - !top - !bottom),
             {t= !top; b= !bottom; l = !left; r = !right}
           )
        )
    | _ -> 
        (img_src, {t=0;b=0;l=0; r=0})
    ];

	(* Запись файла атласа либы *)
	(* Добавляем в хэштаблицу imgRcd типа img *)

	value writeLibAtlasFile ttIndex imginfo packname ttInfHash = (
        let w				= imginfo.TextureLayout.width in
        let h				= imginfo.TextureLayout.height in
        let imgs			= imginfo.TextureLayout.placed_images in
        let rgb				= Rgba32.make w h {Color.color = {Color.r = 0; g = 0; b = 0}; alpha = 0} in
        let new_img			= Images.Rgba32 rgb in
        (
			      List.fold_left (fun imgIndex ((texId, recId, (objname, fname), dummy, crop_info ), (sx, sy, isRotate, img)) -> (
              let (iw,ih) = Images.size img in (
                Printf.printf "texId : %d; recId : %d; fname : %s\n%!" texId recId fname;
        (* Printf.printf "\n fname %s oname %s\n" fname oname; *)
        (* let ()		= Printf.printf "\n Sx Sy iw ih %d %d %d %d\n" sx sy iw ih in  *)
                try (
                    Images.blit img 0 0 new_img sx sy iw ih;
                )
                with 
                  [ Invalid_argument _ -> (
                        match img with
                        [ Images.Index8	 _ -> prerr_endline "index8"
                        | Images.Rgb24	 _ -> prerr_endline "rgb24"
                        | Images.Rgba32	 _ -> prerr_endline "rgba32"
                        | _ -> prerr_endline "other"
                        ];
                        raise Exit;
                    )
                  ];
                let imgRcd:img = { tt_index = ttIndex; img_index = recId; rect = {rx = sx; ry = sy; rw = iw; rh = ih}; crop_info } in
                Hashtbl.add ttInfHash (objname, fname) imgRcd;
                imgIndex + 1
            	)
            )) 0 imgs;
			let pathSaveImg = (P.outDir /// packname ^ P.suffix) in (
				(* Если гамма *)
	            match P.is_gamma_steam with
              [ True -> 
                  let tmp_name = pathSaveImg ^ "_tmp.png" in
                  (
                    Images.save tmp_name (Some Images.Png) [] new_img;
                    (*
                    let cmd = Printf.sprintf "convert -gamma 1.1 %s %s.png" tmp_name pathSaveImg in
  *)
                    let cmd = Printf.sprintf "convert -brightness-contrast \"5 x5\" -sharpen \"1x0.2\" %s %s.png" tmp_name pathSaveImg in
                      (
                        Printf.printf "%s\n%!" cmd;
                        match Sys.command cmd with
                        [ 0 -> Sys.remove tmp_name
                        | _ -> failwith "conver gamma return non-zero"
                        ];
                      )
                  )
              | _ -> 
                  match P.is_gamma_gin with
                  [ True when False ->
                      let tmp_name = pathSaveImg ^ "_tmp.png" in
                      (
                        Images.save tmp_name (Some Images.Png) [] new_img;
                        (*
                        let cmd = Printf.sprintf "convert -gamma 1.1 %s %s.png" tmp_name pathSaveImg in
      *)
                        let cmd = Printf.sprintf "convert -brightness-contrast \"7 x7\" -sharpen \"1x0.2\" -set option:modulate:colorspace hsb -modulate 100,110 %s %s.png" tmp_name pathSaveImg in
                          (
                            Printf.printf "%s\n%!" cmd;
                            match Sys.command cmd with
                            [ 0 -> Sys.remove tmp_name
                            | _ -> failwith "conver gamma return non-zero"
                            ];
                          )
                      )
                  | _ -> 
                    (* Обычное сохранение *)
                      (
                      Images.save (pathSaveImg ^ ".png") (Some Images.Png) [] new_img
                      )
                  ]
              ];
		              match P.gen_pvr with
	                [ True -> 
	                    (
	                    	try
								          Utils.pvr_png	pathSaveImg;
								          Utils.gzip_img	(pathSaveImg ^ ".pvr");	                    		
	                    	with
	                    	[ _ -> Printf.printf "\n === WARNING!!! NO PVR TOOL ===\n%!"]

	                    )
	                | _ -> ()
	                ];
		              match P.gen_dxt with
	                [ True -> 
	                    (
	                    	try
								          Utils.dxt_png	pathSaveImg;
                  				Utils.gzip_img	(pathSaveImg ^ ".dds");	                    		
	                    	with
	                    	[ _ -> Printf.printf "\n === WARNING!!! NO DDS TOOL ===\n%!"]

	                    )
	                | _ -> ()
	                ];
            )

            
        )
	);

  value get_conver_cmd src dst fltrs = 
    let cmd = 
      String.concat ";\n" @@ List.map (fun options ->
        if options = ""
        then ""
        else
          let path_filter = src ^ "_filter" in
          "convert " ^ options ^ " '" ^ src ^ "' 'png32:" ^ path_filter ^ "';
          mv -f '" ^ path_filter ^ "' '" ^ src ^ "'";
      ) fltrs
    in
    match cmd with
    [ "" -> "convert " ^ src ^ " png32:" ^  dst
    | _ -> 
        let mv = (Printf.sprintf "mv -f %s %s" src dst) in
        cmd ^";\n" ^ mv
    ];

	(* Получить картинку *)
	value getImg obj fname pack_scale = (
    let () = Printf.printf "getImg[%s] :%s \n%!" obj fname in
    let src_path = P.imgDir /// fname in
    let srcImg		= OImages.load src_path [] in
		(* let srcImg	= OImages.rgba32 srcImg in *)
		let image		= srcImg#image in
    let need_convert = True
      (*
      match image with
      [ Images.Index8 img -> True
      | _ -> False
      ]
      *)
    in
    (*
    let scale = pack_scale *. P.scale in
    *)
    let scale = P.scale *. (FiltersConf.get_scale P.filter_conf obj) in
		let image		=
			match scale with
			[ 1. when not need_convert -> image
			| scale ->
				let srcFname = Filename.temp_file "src" "" in
				let dstFname = Filename.temp_file "dst" ""  in
				(
          (*
					Images.save srcFname (Some Images.Png) [] image;
          *)
          let cmd_copy = Printf.sprintf "cp \"%s\" \"%s\"" src_path srcFname in
            (
              Printf.printf "%s\n%!" cmd_copy;
              if Sys.command cmd_copy <> 0
                then failwith "not copy"
              else ();
            );

          let filters = 
            match scale with
            [ 1.->  []
            | _ -> [ Printf.sprintf "-interpolative-resize %f%% " ((scale *. 100.))  ] 
            ]
            (*
            match scale with
            [ 1.->  []
            | sc when sc > 1. ->  [ Printf.sprintf "-resize %d%% -filter catrom" (int_of_float (scale *. 100.))  ]
            | _ -> [ Printf.sprintf "-interpolative-resize %d%% -sharpen 0x.1" (int_of_float (scale *. 100.))  ] 
            ]
      *)
          in
          let filters = (FiltersConf.get_filter P.filter_conf obj fname)  @ filters in 
          let filters = 
            match P.is_gamma_gin with
            [ True ->
              (*
              [ "-brightness-contrast \"7 x7\" -sharpen \"1x0.2\" -set option:modulate:colorspace hsb -modulate 100,110" :: params ]
            *)
              match FiltersConf.in_shadows P.filter_conf fname with
              [ True -> filters
              | _ -> 
                  [ "-brightness-contrast \"9 x7\" -sharpen \"1x0.2\" -set option:modulate:colorspace hsb -modulate 100,110" :: filters ]
              ]
            | _ -> filters
            ]
          in
          let cmd = get_conver_cmd srcFname dstFname filters in
          (*
          let cmd = 
            match scale with
            [ 1.-> Printf.sprintf "convert %s %s png32:%s" params srcFname dstFname
            | sc when sc > 1. -> Printf.sprintf "convert %s -resize %d%% -filter catrom %s png32:%s" params (int_of_float (scale *. 100.)) srcFname dstFname
            | _ ->Printf.sprintf "convert %s -interpolative-resize %d%% -sharpen 0x.1 %s png32:%s" params (int_of_float (scale *. 100.)) srcFname dstFname 
            ]
          in
      *)
            (
              Printf.printf "%s\n%!" cmd;
              if Sys.command cmd <> 0
                then failwith "convert returns non-zero exit code"
              else ();
            );

					let img = Images.load dstFname [] in
					(
					  match img with
					  [ Images.Index8	 _ -> Printf.printf("img type: Index8\n%!")
					  | Images.Rgb24	 _ -> Printf.printf("img type: Rgb24\n%!")
					  | Images.Index16	 _ -> Printf.printf("img type: Index16\n%!")
					  | Images.Rgba32	 _ -> Printf.printf("img type: Rgba32\n%!")
					  | Images.Cmyk32	 _ -> Printf.printf("img type: Cmyk32\n%!")
					  ];

            (*
					  Sys.remove srcFname;
					  Sys.remove dstFname;
            *)
					  img;
					);
				)
			] in
    let (image, crop_info) = crop_image image in
	  let image = 
      match P.degree4 with
      [ True -> 
          let (iw', ih') = Images.size image in
          let iw = TextureLayout.do_degree4 iw' 
          and ih = TextureLayout.do_degree4 ih' 
          in
          let rgb = Rgba32.make iw ih {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
          let res_img = Images.Rgba32 rgb in
            ( 
              Images.blit image 0 0 res_img 0 0 iw' ih';
              res_img
            )
      | _ -> image
      ] 
      in  (image,crop_info)
	);


	(* Запись атласа либы *)
	value writeLibAtlas packname (lstImgs: list (string * list string)) ttInfHash isWholly pack_scale = (
		(* Собираем список текстурной информации *)
    let () = Printf.printf "writeLibAtlas pack :%s; lstImgs : [ %s ]  \n%!" packname (String.concat "; " (List.map (fun (name, fnames) -> Printf.sprintf "%s : [ %s ]\n " name (String.concat "; " fnames)  ) lstImgs)) in
		let images = 
			(* List.fold_left (fun accLst (oname, fnameLst) -> ( *)
			List.fold_left (fun accLst (objname, fnames) -> (
        let (_,res) =
          List.fold_right (fun fname  (recId, result)-> 
            let (img,crop_info) = getImg objname fname pack_scale in
            (recId + 1, [((0, recId, (objname, fname), "", crop_info), img):: result])
          ) fnames (0,[])
        in
        [ (True, res) :: accLst ] 
			)) [] lstImgs in
    let images = 
      match isWholly with
      [ True -> 
          let imgs = 
            List.fold_left (fun res (_,images) -> 
              res @ images
            ) [] images 
          in
          [ (True, imgs) ]
      | _ -> images 
      ]
    in
		let _			= Printf.printf "\n PROCESSING TEXTURE START %s\n%!" (packname) in
		let (textures:list (TextureLayout.page (int * int * (string * string) * string * crop_info))) = TextureLayout.layout_min images in 
		let _			= Printf.printf "\n PROCESSING TEXTURE END %s\n%!" (packname) in
		let ttIndex		= List.fold_left (fun ttIndex imginfo -> (
			(* Имя либы + "_номер текстуры" *)
			let packname = packname ^ "_" ^ (string_of_int ttIndex) in
			(* Записываем файл атласа *)
			writeLibAtlasFile ttIndex imginfo packname  ttInfHash;
			ttIndex + 1;
				(* [ttInfLst::accPgsLst] *)
	    )) 0 textures in
	    	ttIndex
	);

	(* Запись texInfo.dat *)
	value writeTexDat prj packname lstObjs numAtlases ttInfHash animated = (

		List.iter (fun oname -> (
			Utils.makeDir (P.outDir /// oname); (* oname - типа dc_tree *)
			let texOut		= IO.output_string () in
			(* TODO Можно ускорить, записывать заранее в хеш таблицу *)
			let obj	= List.find (fun o -> ((Object.name o) = oname)) (Project.objects prj) in 
			let uniqObjImgsLst = makeLstImgs obj animated in
			let imgsInfLst	= List.fold_left (fun imgRcdLst path -> (
				let imgRcd = Hashtbl.find ttInfHash  (oname, path) in
				[imgRcd::imgRcdLst]
			)) [] uniqObjImgsLst in
			
			let ()			= Printf.printf "\n ONAME  %s\n" (oname) in			
    		let _			= (

(*  			IO.write_byte	texOut numAtlases;  *)

			IO.write_i16	texOut numAtlases;
			Printf.printf "\n numAtlases %d\n" (numAtlases);

				for i = 0 to numAtlases - 1 do
					let packname = Printf.sprintf "%s_%d%s.png" packname i P.suffix in 
					let _		 = Utils.writeUTF	texOut packname in

					(* Ищем в общем списке текстур, картинки принадлежащие текущей текстуре *)
					let ttImgs	= List.find_all (fun img -> ((img.tt_index = i))) imgsInfLst in (
						IO.write_ui16	texOut (List.length ttImgs);
						List.iter (fun img -> (
        	    			IO.write_ui16 texOut img.rect.rx;
                            IO.write_ui16 texOut img.rect.ry;
                            IO.write_ui16 texOut img.rect.rw;
                            IO.write_ui16 texOut img.rect.rh;
						)) ttImgs;
					)

				done;

			) in

			let texOut	= IO.close_out texOut in
	        let out		= open_out (P.outDir /// oname /// "texInfo" ^ P.suffix ^".dat") in (
	        	output out texOut 0 (String.length texOut);
	            close_out out;
	        )
		)) lstObjs;
	);


	(* Записать данных либы *)
	value writeLibData prj packname lstObjs isWholly pack_scale animated = (

		let ttInfHash= Hashtbl.create 30 in
		
		(* если не aminated, то добавляем только картинки первого кадра *)
		let lstImgs:list (string * list string) =
		
		let lstImgs = 
          List.fold_left (fun lstImgs oname -> 
            let obj	= List.find (fun o -> ((Object.name o) = oname)) (Project.objects prj) in 
            let uniqObjImgsLst = makeLstImgs obj animated
            in [ (oname, uniqObjImgsLst) :: lstImgs ]
    		) [] lstObjs         
          in ExtList.List.unique lstImgs
		in
		
		if (List.length lstImgs) > 0 then (
		
			(* Запись атласа *)
			let numAtlases	= writeLibAtlas	packname lstImgs ttInfHash isWholly pack_scale 
			in writeTexDat	prj	packname lstObjs numAtlases ttInfHash animated;
			
			
			List.iter (fun oname -> 
				(* Ищем объект в проекте *)
				let obj	= List.find (fun o -> (Object.name o) = oname) (Project.objects prj) in (
					(* Запись animations.dat *)
					let numFrames = writeAnimationsDat obj pack_scale animated in
					
					(* Запись frames.dat *)					
					let () = Printf.printf "GOT %d Frames in object \n" numFrames in
					writeFramesDat obj numFrames ttInfHash pack_scale animated;					
				)
			) lstObjs;

			Hashtbl.clear ttInfHash;
		) else ()
	);

  end;
