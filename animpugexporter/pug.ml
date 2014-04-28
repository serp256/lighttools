open Node;
open Images;

module type P =
  sig
	value prjName:  	string;
	value prjDir:   	string;
	value outDir:		string;
	value imgDir:   	string;
	value scale:		float;
	value gen_pvr:		bool;
	value gen_dxt:		bool;
	value degree4:		bool;
	value is_gamma:		bool;
	value without_cntr:	bool;
	value is_android:	bool;
	value no_anim:		bool;
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
					  Printf.printf "\nWARNING ERROR!\t%s" e;
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

	type img = 
	  {
	  	tt_index:	int;
	  	img_index:	int;
		rect :		rects;
	  };


	(* Запись animations.dat *)
	(* @return	int	numFrames	число фреймов в объекте *)
	value writeAnimationsDat o = (
		let oname		= Object.name o in
		let animsOut	= IO.output_string () in
		let numFrames	= (
			IO.write_ui16 animsOut 1;
			Utils.writeUTF animsOut oname;
			let numAnims		= Common.childsNum o in
				IO.write_ui16 animsOut numAnims;
			let numFrames		= 
				List.fold_left (fun frmIndx a -> (
					let aname		= Animation.name a in
					let _			= Utils.writeUTF animsOut aname in
					let frmRt		= Int32.bits_of_float (Animation.frameRate a) in
						IO.write_real_i32 animsOut frmRt;
					let rects		= Animation.rects a in 
					let numRects	= List.length rects in (
						(* Минимум всегда 1 прямоугольник *)
						if numRects > 0 then IO.write_byte animsOut numRects else IO.write_byte animsOut 1;

						if numRects > 0 then
							List.iter (fun r -> (
									(* Printf.printf "\n1oname %s; %f %f %f %f\n" oname r.Rect.x r.Rect.y r.Rect.width r.Rect.height; *)
									IO.write_i16 animsOut (truncate (P.scale *. r.Rect.x));
									IO.write_i16 animsOut (truncate (P.scale *. r.Rect.y));
									IO.write_i16 animsOut (truncate (P.scale *. r.Rect.width));
									IO.write_i16 animsOut (truncate (P.scale *. r.Rect.height));
								)
							) rects
						else (
							let (x, y, w, h) = calcAnimRects a in (
								(* Printf.printf "\n2oname %s; %f %f %f %f\n" oname x y w h; *)
								IO.write_i16 animsOut (truncate (P.scale *. x));
								IO.write_i16 animsOut (truncate (P.scale *. y));
								IO.write_i16 animsOut (truncate (P.scale *. w));
								IO.write_i16 animsOut (truncate (P.scale *. h));
							)
						)
					);
					let _			= Printf.printf "\n NO ANIM %b\n" (P.no_anim) in
					let frmIndx = 
						match P.no_anim with
						[ False -> (
							let numFrames	= Common.childsNum a in 
								IO.write_ui16 animsOut numFrames;
							List.fold_left (fun frmIndx' f -> (
									IO.write_i32 animsOut frmIndx';
									frmIndx' + 1
							)) frmIndx (Common.childs a)
						)
						(* Для случая отключение анимации *)
						| True -> (
							IO.write_ui16 animsOut 1;
							1
						)
						]
					in frmIndx
					)
				) 0 (Common.childs o);
			numFrames
		) in
		let animsOut	= IO.close_out animsOut in
        let out			= open_out (P.outDir /// oname /// "animations.dat") in (
        	output out animsOut 0 (String.length animsOut);
            close_out out;
            numFrames
        )
	);

	(* Запись frames.dat *)
	value writeFramesDat o numFrames ttInfHash = (
		let oname		= Object.name o in
		(* let imgsInfLst	= Hashtbl.find_all ttInfHash oname in *)
		let framesOut	= IO.output_string () in
		let _			= (
			IO.write_i32 framesOut numFrames;
			(* Фреймы *)
			List.iter (fun a -> (
				let animLst = Common.childs a in
				(* Берем первый кадр если отключена анимация *)
				let animLst = if (P.no_anim) then [List.hd animLst] else animLst in
				List.iter (fun f -> (
					
					let fx			= Utils.round (P.scale *. (Frame.x f)) in
					let fy			= Utils.round (P.scale *. (Frame.y f)) in
					let iconX		= Utils.round (P.scale *. (Animation.iconX a)) in
					let iconY		= Utils.round (P.scale *. (Animation.iconY a)) in
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
							let px    = Utils.round (P.scale *. (Point.x p)) in
							let py    = Utils.round (P.scale *. (Point.y p)) in
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
						let imgRcd		= Hashtbl.find ttInfHash imgPath in
						(* let imgRcd		= List.find (fun (i:img) -> i.path = imgPath)	imgsInfLst in *)
						let lx			= Utils.round (P.scale *. (Layer.x l)) + fx in
						let ly			= Utils.round (P.scale *. (Layer.y l)) + fy in
						(* let lx			= Utils.round (P.scale *. ((Layer.x l) +. (Frame.x fstFrm)) -.  (float fx)) in *)
						let alpha		= int_of_float (Layer.alpha l ) in
						let flip		= Utils.int_of_bool (Layer.flip l ) in
						let scale		= Int32.bits_of_float (Layer.scale l ) in (
							(* TODO Возможно на клиенте индекс начинается с 1 *)
							IO.write_byte		framesOut imgRcd.tt_index; (*texID*)
							IO.write_i32		framesOut imgRcd.img_index; (* rectId *)
							IO.write_i16 		framesOut lx;
							IO.write_i16 		framesOut ly;
		          IO.write_byte		framesOut alpha;
		          IO.write_byte		framesOut flip;
		          IO.write_real_i32	framesOut scale;
						)
					)) (Common.childs f)

				)) animLst;
			)) (Common.childs o);


		) in
		let framesOut	= IO.close_out framesOut in
        let out			= open_out (P.outDir /// oname /// "frames.dat") in (
        	output out framesOut 0 (String.length framesOut);
            close_out out;
        )
	);

	(* Собираем уникальные картинки с объекта *)
	value makeLstImgs o:list string = (
		List.fold_left (fun allimgs a -> (
			List.fold_left (fun imgsf f -> (
				List.fold_left (fun imgsl l -> (
					let imgPath = Layer.imgPath l in
					if (List.mem imgPath imgsl) then
						imgsl
					else (
						imgsl @ [imgPath]
					)
				)) imgsf (Common.childs f)
			)) allimgs (Common.childs a)
		)) [] (Common.childs o)
	);



	(* Запись файла атласа либы *)
	(* Добавляем в хэштаблицу imgRcd типа img *)
	value writeLibAtlasFile ttIndex imginfo packname ttInfHash = (
        let w				= imginfo.TextureLayout.width in
        let h				= imginfo.TextureLayout.height in
        let imgs			= imginfo.TextureLayout.placed_images in
        let rgb				= Rgba32.make w h {Color.color = {Color.r = 0; g = 0; b = 0}; alpha = 0} in
        let new_img			= Images.Rgba32 rgb in
        (
			List.fold_left (fun imgIndex ((texId, recId, fname, dummy ), (sx, sy, isRotate, img)) -> (
              	let (iw,ih) = Images.size img in (
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
                    let imgRcd:img = { tt_index = ttIndex; img_index = imgIndex; rect = {rx = sx; ry = sy; rw = iw; rh = ih} } in
                    	Hashtbl.add ttInfHash fname imgRcd;
                	imgIndex + 1
            	)
            )) 0 imgs;
			let pathSaveImg = (P.outDir /// packname) in (
				(* Если гамма *)
	            match P.is_gamma with
		            [ True -> 
		                let tmp_name = pathSaveImg ^ "_tmp.png" in
		                (
		                  Images.save tmp_name (Some Images.Png) [] new_img;
		                  let cmd = Printf.sprintf "convert -gamma 1.1 %s %s.png" tmp_name pathSaveImg in
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
		                Images.save (pathSaveImg ^ ".png") (Some Images.Png) [] new_img
		            ];
		        match P.gen_pvr with
	                [ True -> 
	                    (
	                    	try
								Utils.pvr_png	pathSaveImg;
								Utils.gzip_img	(pathSaveImg ^ ".pvr");	                    		
	                    	with
	                    	[ _ -> Printf.printf "\n === WARNING!!! NO PVR TOOL ===\n"]

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
	                    	[ _ -> Printf.printf "\n === WARNING!!! NO DDS TOOL ===\n"]

	                    )
	                | _ -> ()
	                ];
            )

            
        )
	);

	(* Получить картинку *)
	value getImg fname = (

		let srcImg		= OImages.load (P.imgDir /// fname) [] in
		(* let srcImg	= OImages.rgba32 srcImg in *)
		let image		= srcImg#image in
		let image		=
			match P.scale with
			[ 1. -> image
			| scale ->
				let srcFname = Filename.temp_file "src" "" in
				let dstFname = Filename.temp_file "dst" ""  in
				(
					Images.save srcFname (Some Images.Png) [] image;
					if Sys.command 
						(Printf.sprintf "convert -resize %d%% -filter catrom %s png32:%s" (int_of_float (scale *. 100.)) srcFname dstFname) <> 0
						then failwith "convert returns non-zero exit code"
					else ();

					let img = Images.load dstFname [] in
					(
					  match img with
					  [ Images.Index8	 _ -> Printf.printf("img type: Index8\n")
					  | Images.Rgb24	 _ -> Printf.printf("img type: Rgb24\n")
					  | Images.Index16	 _ -> Printf.printf("img type: Index16\n")
					  | Images.Rgba32	 _ -> Printf.printf("img type: Rgba32\n")
					  | Images.Cmyk32	 _ -> Printf.printf("img type: Cmyk32\n")
					  ];

					  Sys.remove srcFname;
					  Sys.remove dstFname;
					  img;
					);
				)
			] in
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
		] in
		image
	);


	(* Запись атласа либы *)
	value writeLibAtlas packname lstImgs ttInfHash isWholly = (
		(* Собираем список текстурной информации *)
		let images = 
			(* List.fold_left (fun accLst (oname, fnameLst) -> ( *)
			List.fold_left (fun accLst fname -> (
				let img = getImg fname in
				[((0, 0, fname, ""), img)::accLst]
			)) [] lstImgs in
		let images		= [(isWholly, images)] in
		let _			= Printf.printf "\n PROCESSING TEXTURE START %s\n" (packname) in
		let (textures:list (TextureLayout.page (int * int * string * string))) = TextureLayout.layout_min images in 
		let _			= Printf.printf "\n PROCESSING TEXTURE END %s\n" (packname) in
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
	value writeTexDat prj packname lstObjs numAtlases ttInfHash = (

		List.iter (fun oname -> (
			Utils.makeDir (P.outDir /// oname);
			let texOut		= IO.output_string () in
			(* TODO Можно ускорить, записывать заранее в хеш таблицу *)
			let obj	= List.find (fun o -> (
					(Object.name o) = oname
				)) (Project.objects prj) in 
			let uniqObjImgsLst = makeLstImgs obj in
			let imgsInfLst	= List.fold_left (fun imgRcdLst path -> (
				let imgRcd = Hashtbl.find ttInfHash path in
				[imgRcd::imgRcdLst]
			)) [] uniqObjImgsLst in
			(* let ()			= Printf.printf "\n ONAME  %s\n" (oname) in *)
			let _			= (
				IO.write_byte	texOut numAtlases;
				(* Printf.printf "\n numAtlases %d\n" (numAtlases); *)
				for i = 0 to numAtlases - 1 do
					(* let packname = Printf.sprintf "%s_%d.png" packname i in *)
					let _		 = Utils.writeUTF	texOut packname in
					(* Ищем в общем списке текстур, картинки принадлежащие текущей текстуре *)
					let ttImgs	= List.find_all (fun img -> (
						(img.tt_index = i)
					)) imgsInfLst in (
						(* Printf.printf "\n Texture %s \n" packname; *)
						(* Printf.printf "\n Num imgs %d\n" (List.length ttImgs); *)
						IO.write_ui16	texOut (List.length ttImgs);
						List.iter (fun img -> (
							(* Printf.printf "\n img %d %s\n" img.index img.path; *)
							(* Printf.printf "\n\t\t (%d,%d,%d,%d) \n" img.rect.rx img.rect.ry img.rect.rw img.rect.rh; *)
							IO.write_ui16 texOut img.rect.rx;
              IO.write_ui16 texOut img.rect.ry;
              IO.write_ui16 texOut img.rect.rw;
              IO.write_ui16 texOut img.rect.rh;
						)) ttImgs;
					)

				done;

			) in
			let texOut	= IO.close_out texOut in
	        let out		= open_out (P.outDir /// oname /// "texInfo.dat") in (
	        	output out texOut 0 (String.length texOut);
	            close_out out;
	        )
		)) lstObjs;
	);


	(* Записать данных либы *)
	value writeLibData prj packname lstObjs isWholly = (
		let ttInfHash							= Hashtbl.create 30 in
		let lstImgs:list string	= 
			let lstImgs = List.fold_left (fun lstImgs oname -> 
				let obj	= List.find (fun o -> (
					(Object.name o) = oname
				)) (Project.objects prj) in (
					let uniqObjImgsLst = makeLstImgs obj in (
						lstImgs @ uniqObjImgsLst
					)
				)
			) [] lstObjs in
			ExtList.List.unique lstImgs
		in
		if (List.length lstImgs) > 0 then (
			(* Запись атласа *)
			let numAtlases	= writeLibAtlas		packname lstImgs ttInfHash isWholly in (
				(* Printf.printf "\n NUM ATLASES %d\n" (numAtlases); *)

				(* Запись texInfo.dat *)
				writeTexDat	prj	packname lstObjs numAtlases ttInfHash;
			);
			List.iter (fun oname -> 
					(* Ищем объект в проекте *)
					let obj	= List.find (fun o -> (Object.name o) = oname) (Project.objects prj) in (
						(* Запись animations.dat *)
						let numFrames = writeAnimationsDat obj in
						(* Запись frames.dat *)
						writeFramesDat obj numFrames ttInfHash;
					)
			) lstObjs;
			Hashtbl.clear ttInfHash;
		) else ()
	);

  end;
