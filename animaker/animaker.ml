open Ojson;

exception Break_loop;

value inputDir = ref "";
value outputDir = ref "";
value oneMeta = ref False;

(*
 * FIXMETA****************************
 *)

exception NotFound of string;
exception LabelNotFound of string;

value toBlocks lst =
    let rec getToThis m l acc = match l with
        [[] -> raise (LabelNotFound m)
        |[h :: t] ->
                let lab = Browse.assoc_field Browse.string "label" h in
                if lab = m
                    then ([h :: acc],t)
                    else getToThis m t [h :: acc]] in
    let rec loop l a = match l with
        [[] -> a
        |[h :: t] ->
                let lab = Browse.assoc_field Browse.string "label" h in
                let (l',t') = getToThis (lab ^ "_end") t [h] in
                loop t' [(lab,l') :: a]] in
    loop lst [];


value intOfName s =
    let rec loop2 i = if i = 0
        then i
        else if s.[i] < '0' || s.[i] > '9'
                then i+1
                else loop2 (i-1) in
    let rec loop1 i = if s.[i] = '.'
        then (loop2 (i-1), i)
        else loop1 (i-1) in
    let (sI,fI) = loop1 (String.length s - 1) in
    Scanf.sscanf (String.sub s sI (fI - sI)) "%d" (fun a -> a);

value rec divAt l m a = match l with
        [[h :: t] -> if fst h = m
            then (h,List.append a t)
            else divAt t m [h :: a]
        |[] -> raise (NotFound m)];

value sortBlock (m,b) =
    let getIntName e =
        let l = Browse.assoc_field (fun a -> List.hd (Browse.array a)) "children" e in
        Browse.assoc_field (fun a -> intOfName (Browse.string a)) "file" l in
    let toSort = List.map (fun a -> (getIntName a,a)) b in
    let sorted = List.sort (fun (a,_) (b,_) -> if a > b then 1 else 0) toSort in
    let fixLabel e l =
        let (_,lst) = divAt (Browse.assoc e) "label" [] in
            Build.assoc [("label", Build.string l) :: lst] in
    let rec fixLabels l = match l with
        [ [(_,a)] -> [fixLabel a (m ^ "_end")]
        | [(_,h) :: t]-> [fixLabel h "" :: fixLabels t]] in
    [fixLabel (snd (List.hd sorted)) m :: fixLabels (List.tl sorted)];

value toStringL l =
    let rec loop l ac = match l with
        [[a] -> Printf.sprintf "%s%s]" ac (to_string a)
        |[h :: t] -> loop t (Printf.sprintf "%s%s,\n" ac (to_string h))]in
    loop l "[";

value fixJson js = 
    let ((slab,lst),other) = divAt (Browse.assoc js) "frames" [] in
    let blocks =
        let l = List.(fold_left append [] (map sortBlock (toBlocks (Browse.array lst)))) in
        (slab,Build.array l) in
    to_string (Build.assoc [blocks :: other]);

(*
 */FIXMETA****************************
 *)

(* Данные для meta-файла *)
value metaWrite path meta =
		let oc = open_out path in
		let k = fixJson (from_string !meta) in
		(
(*				print_endline k;*)
				output_string oc k;
				flush oc
		);

(* Контрольная точка *)
value coordCenter = ref None;

(* Корректируем координаты относительно центра *)
value coordCorrect x y =
		match !coordCenter with
		[ None ->
				(
						coordCenter.val := Some (x, y);
						(0, 0)
				)
		| Some (_x, _y) -> (x - _x, y - _y)
		];

(* Получаем краплёный прямоугольник *)
value croppedImageRect img =
		let vLineEmpty img num f t =
				let y = ref f  in
				try 
				(
						while !y <= t do
								let elt = Rgba32.get img num !y in
								match elt.Color.Rgba.alpha with
								[ 0 -> incr y
								| _ -> raise Break_loop
								]
						done;
						True
				) with [ Break_loop -> False ]
		and hLineEmpty img num f t =
				let x = ref f in
				try
				(
						while !x <= t do
								let elt = Rgba32.get img !x num in
								match elt.Color.Rgba.alpha with
								[ 0 -> incr x
								| _ -> raise Break_loop
								]
						done;
						True
				) with [ Break_loop -> False ]
		in
		let x = ref 0
		and y = ref 0
		and w = ref img.Rgba32.width
		and h = ref img.Rgba32.height in
		(
				(* top *)
				try
						while !y < img.Rgba32.height do
								match hLineEmpty img !y !x (!w - 1) with
								[ True  -> incr y
								| False -> raise Break_loop
								]
						done
				with [ Break_loop -> () ];

				(* bottom *)
				try
						while !h > 0 do
								match hLineEmpty img (!h - 1) !x (!w - 1) with
								[ True  -> decr h
								| False -> raise Break_loop
								]
						done
				with [ Break_loop -> () ];

				(* left *)
				try
						while !x < img.Rgba32.width do
								match vLineEmpty img !x !y (!h - 1) with
								[ True  -> incr x
								| False -> raise Break_loop
								]
						done
				with [ Break_loop -> () ];

				(* right *)
				try
						while !w > 0 do
								match vLineEmpty img (!w - 1) !y (!h - 1) with
								[ True  -> decr w
								| False -> raise Break_loop
								]
						done
				with [ Break_loop -> () ];

				(!x, !y, (!w - !x), (!h - !y))
		);

(* Передаём методу путь, кусок текстуры и её параметры *)
value saveImage path file img (x, y, w, h) =
		let rgba = Rgba32.make w h {Color.color = {Color.r = 255; g = 255; b = 255}; alpha = 0;} in
		(
				(* Вырезаем из сиходника выделенную область и подсохраняем в новое место *)
				for i = 0 to w - 1 do
						for j = 0 to h - 1 do
						(
								Rgba32.set rgba i j (Rgba32.get img (x + i) (y + j))
						) done
				done;

				let canvas = Images.Rgba32 rgba in
				Images.save path (Some Images.Png) [] canvas;

				(* Корректируем координаты и записываем в meta *)
				let (_x, _y) = coordCorrect x y in
				(file, _x, _y)
		);

(* Загружаем и обрабатываем картинку *)
value processImage inPath outPath f =
		let () = Printf.eprintf "Loading %s --> %s\n%!" inPath outPath in
		try
				let image = Images.load inPath [] in
				let image =
						match image with
						[ Images.Rgba32 i -> i
						| Images.Rgb24 i -> Rgb24.to_rgba32 i
						| _ -> assert False
						] in
				let (x, y, w, h) = croppedImageRect image in
				saveImage outPath f image (x, y, w, h)
		with [ Images.Wrong_file_type -> (Printf.eprintf "Wrong file type: %s\n%!" inPath; assert False) ];

(* Алиас для удобства *)
value (//) = Filename.concat;
value getLast src =
		try
				let str = Str.string_after src (String.rindex src '/' + 1) in
				(
						str
				)
		with [ Not_found -> src ];

(* Обрабатываем все файлы *)
value loadFiles gdir =
		let rec _readdir dir =
		let meta = ref "{\"frames\":[\n" in
		let once = ref True in
		let blockFlag = ref False in
		(
				Array.iter (fun f ->
								try
										let inPath = gdir // dir // f in
										let outPath = !outputDir // dir // f in
										match Sys.is_directory inPath with
										[ True -> _readdir (dir // f)
										| False ->
												(
														ignore(Sys.command ("mkdir -p " ^ !outputDir // dir));
														let (file, x, y) = processImage inPath outPath f in
														(
																if not !once then meta.val := !meta ^ ",\n" else once.val := False;
																meta.val :=
                                                                    !meta ^
                                                                    (Printf.sprintf "{\"children\":[{\"file\":\"%s\",\"x\":%i,\"y\":%i,\"type\":\"image\"}],\"label\":\"%s\",\"type\":\"sprite\"}" file x y (getLast (!outputDir // dir)))
														);
														blockFlag.val := True
												)
										]
								with [ _ -> () ]
				) (Sys.readdir (gdir // dir));

				if !blockFlag then
				(
						meta.val := !meta ^ "],\"type\":\"clip\"}\n";
						let path = !outputDir // dir ^ "/meta.json" in metaWrite path meta
				) else ();

				coordCenter.val := None
		) in _readdir "";

(* Обрабатываем все файлы и сохраняем все данные в одну мету - фиг с ним, что дублируется код *)
value loadFiles2 gdir =
		(* Содержимое файла meta.json *)
		let meta = ref "{\"frames\":[\n" in
		(* Флажок, что не надо ставить запятую в начале первого предложения *)
		let once = ref True in
		(
				(*	Мой мозг умер здесь - рекурсивно обходим папку, если находим png - добавляем запись о них в мету, сами пнг обрезаем и сохраняем в аналогичную иерархию
						в мете, первый фрейм имеет имя "имя_папки", последний "имя_папки_end" - итерируем один раз и х/з сколько файлов в папке - код ужасен, но работает на "отлично"
				*)

				(* Рекурсивный адЪ *)
				let rec _readdir dir =
				(
						let isFirst = ref True in
						(* параметры - (первый_юзабельный_файл_в_списке?, "путь к нему", x, y, "имя фрейма", "имя первого фрейма") *)
						let vvv = ref (False, "", 0, 0, "", "") in
						(
								(* Итерация по всем элементам папки *)
								Array.iter (fun f ->
										try
												(* Тут всё очевидно *)
												let inPath = gdir // dir // f in
												let outPath = !outputDir // dir // f in
												match Sys.is_directory inPath with
												[ True -> _readdir (dir // f)
												| False ->
														(
																ignore(Sys.command ("mkdir -p " ^ !outputDir // dir));
																let (file, x, y) = processImage inPath outPath f in
																(
																		let (flag, vvv_file, vvv_x, vvv_y, vvv_name, ll) = !vvv in
																		(
																				if not flag then ()
																				else (
																						if not !once then meta.val := !meta ^ ",\n" else once.val := False;
																						meta.val
                                                                                        :=
                                                                                            !meta
                                                                                            ^
                                                                                            (Printf.sprintf
                                                                                            "{\"children\":[{\"file\":\"%s\",\"x\":%i,\"y\":%i,\"type\":\"image\"}],\"label\":\"%s\",\"type\":\"sprite\"}" vvv_file vvv_x vvv_y vvv_name);
																						isFirst.val := False 
																				);

																				vvv.val := (True, (dir // file), x, y, (if !isFirst then (getLast (!outputDir // dir)) else ""), (if !isFirst then (getLast (!outputDir // dir)) else ll))
																		)
																);
														)
												]
										with [ _ -> () ]
								) (Sys.readdir (gdir // dir));

								let (vvv_f, vvv_file, vvv_x, vvv_y, vvv_name, ll) = !vvv in
								(
										if vvv_f then
										(
												if not !once then meta.val := !meta ^ ",\n" else once.val := False;
												meta.val := !meta ^
                                                (Printf.sprintf
                                                "{\"children\":[{\"file\":\"%s\",\"x\":%i,\"y\":%i,\"type\":\"image\"}],\"label\":\"%s\",\"type\":\"sprite\"}" vvv_file vvv_x vvv_y (if compare "" vvv_name <> 0 then ll else ll ^ "_end"))
										) else ()
								)
						)
				) in _readdir "";

				(* Дописываем мете хвост и сохраняем нах  *)
				meta.val := !meta ^ "],\"type\":\"clip\"}\n";
				let path = !outputDir ^ "/meta.json" in metaWrite path meta
		);


value main () = 
(
		Arg.parse
		[
				("-o", Arg.Set_string outputDir, "output directory");
				("-i", Arg.Set_string inputDir, "input directory");
				("-oneMeta", Arg.Set oneMeta, "make only one meta.json");
		]
		(fun id -> ()) "usage msg";
		ignore(Sys.command ("mkdir -p " ^ !outputDir));

		if !oneMeta then loadFiles2 !inputDir else loadFiles !inputDir
);

main ();

