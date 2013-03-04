open Ojson;

exception BAD_FOLDERNAME of string;
exception BAD_FILENAME of string;
exception NOT_FOLDER of string;
exception Break_loop;

value isDigit c = c >= '0' && c <= '9';

value dirnameToIntAndName _ name =
    let len = String.length name in
    let rec loop i =
        if i = 0
            then i
            else if not (isDigit name.[i])
                then i+1
                else loop (i-1) in
    let p = loop (len-1) in
        if p = len
            then raise (BAD_FOLDERNAME name)
            else Scanf.sscanf (String.sub name p (len - p)) "%d" (fun a -> (a,name));

value filenameToIntAndName parName s =
    let rec loop2 i = if i = 0
        then i
        else if s.[i] < '0' || s.[i] > '9'
                then i+1
                else loop2 (i-1) in
    let rec loop1 i = if i = 0
        then raise (BAD_FILENAME s)
        else if s.[i] = '.'
                then (loop2 (i-1), i)
                else loop1 (i-1) in
    let (sI,fI) = loop1 (String.length s - 1) in
    if s.[sI] = '.'
        then raise (BAD_FILENAME s)
        else Scanf.sscanf (String.sub s sI (fI - sI)) "%d" (fun a -> (a,parName ^ s));


value getNSortFiles dname sfunc = (
    let rec onlyLast i = if i = 0
            then dname
            else if dname.[i] = '/'
                then String.sub dname (i+1) (String.length dname - i - 1)
                else onlyLast (i-1) in
    let dn = onlyLast (String.length dname - 2) in
    if Sys.is_directory dname
        then 
            let files = Array.map (sfunc dn) (Sys.readdir dname) in (
                Array.sort (fun (a,_) (b,_) -> if a > b then 1 else -1) files;
                Array.map (fun (_,a) -> a) files;
            )
        else raise (NOT_FOLDER dname);
);

(*
 * FROM_ORIGINAL**************************************************************
 *)

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

(*
 */FROM_ORIGINAL**************************************************************
 *)

value output = ref "";
value input = ref "";

value processFile path =
    let rec onlyLast i = if i = 0
            then path
            else if path.[i] = '/'
                then String.sub path (i+1) (String.length path - i - 1)
                else onlyLast (i-1) in
    let (file,x,y) = processImage (!input ^ "/" ^ path) (!output ^ "/" ^ path) (onlyLast (String.length path - 1)) in
    Build.array[
        Build.assoc [
            ("file",Build.string path);
            ("x",Build.int x);
            ("y",Build.int y);
            ("type",Build.string "image")
        ]];

value processChild path label =
    Build.assoc [
        ("children",processFile path);
        ("label",Build.string label);
        ("type",Build.string "sprite")];

value loadFiles inp out =
    let subdirs = getNSortFiles inp dirnameToIntAndName in
    let files = Array.map (fun path -> (path,
                                        Array.map (fun a -> (a,"")) (getNSortFiles (inp ^ path ^ "/") filenameToIntAndName))) subdirs in
    let frames = ref [] in
    (
        Array.iter (fun (p,f) -> (
            f.(0) := (fun (a,s) -> (a,p)) f.(0);
            f.(Array.length f - 1) := (fun (a,s) -> (a,p ^ "_end")) f.(Array.length f - 1);
            Sys.command ("mkdir -p " ^ out ^ "/" ^ p);
            Array.iter (fun (a,m) -> !frames := [processChild a m :: !frames]) f)) files;
        to_file (out ^ "/meta.json") (Build.assoc [("type",Build.string "clip");("frames", Build.array (List.rev !frames))]);
);

value main() = (
    Arg.parse
	[
			("-o", Arg.Set_string output, "output directory");
			("-i", Arg.Set_string input, "input directory");
	]
   (fun id -> ()) "usage msg";
   if !input.[String.length !input - 1] <> '/'
        then !input := !input ^ "/"
        else (); 
	Sys.command ("mkdir -p " ^ !output);
    loadFiles !input !output;
);
main();
