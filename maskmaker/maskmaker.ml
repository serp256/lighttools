(* Скрипт для выделения областей из картинки *)
open Images;
open DynArray;

value size = ref 16;
value fileName = ref "img";

(* Ширина исходной картики *)
value img_w = ref 0;
(* Высота исходной картинки *)
value img_h = ref 0;
value _width = ref 0;
value _height = ref 0;
value suffix = ref "";
value notSave = ref False;
value max_alpha = ref 232;
(* Функции для получения картинки *)
value _img:(ref (option Rgba32.t)) = ref None;
value img () =
		match !_img with
		[ None -> assert False
		| Some t -> t
		];

(* Чтобы не дёргать каждый раз картинку, будем работать с маской *)
value mask = DynArray.create ();
(* Создаём маску вида (bool, bool) - где первый элемент списка - был ли просмотрен элемент ранее, второй - определяет альфу *)
(*пометить как контур*)
value mark x y =
		DynArray.set mask (x + y * !img_w) (False, False);
(* Проверяет альфаканал *)
value mask_check_alpha x y =
		let el = DynArray.get mask (x + y * !img_w) in snd el;
value mask_init () =
				(
          for j = 0 to !img_h - 1 do
		      for i = 0 to !img_w - 1 do
						let point = Rgba32.get (img ()) i j in
						DynArray.add mask (False, 
            (
              point.Color.color.g = 0 && point.Color.color.g = 0 &&
              point.Color.color.b = 0 && point.Color.alpha < !max_alpha 
            )

          )
				done
		    done;
        (* поправка на округление пикселей*)
        let p = !img_w / 1024 * 4 in
        let px = p + p mod 2 in

(
          for i = (!img_w-px) to (!img_w-2) do
		      for j = 0 to !img_h - 1 do
            if 
              not (mask_check_alpha i j) && (mask_check_alpha (i+1) j)
            then ( mark (i+1) j)
            else ();
          done; 
          done;
         
		      for i = 0 to !img_w - 1 do
          for j = (!img_h-px) to (!img_h-2) do
            if 
              not (mask_check_alpha i j) && (mask_check_alpha i (j+1))
            then ( mark i (j+1))
            else ();
          done; 
          done;
         
		      for i = 0 to !img_w - 1 do
          for j = px downto 1 do
            if 
              not (mask_check_alpha i j) && (mask_check_alpha i (j-1))
            then ( mark i (j-1))
            else ();
          done; 
          done;

          for i = px downto 1 do
		      for j = 0 to !img_h - 1 do
            if 
              not (mask_check_alpha i j) && (mask_check_alpha (i-1) j)
            then ( mark (i-1) j)
            else ();
          done; 
          done;
)
        )
        ;

(* Проверяет, был ли элемент просмотрен ранее *)
value mask_check_marked x y =
		let el = DynArray.get mask (x + y * !img_w) in fst el;
(* Условие рассмотрения точки *)
value mask_check x y = (not (mask_check_marked x y)) && (mask_check_alpha x y);
(* Устанавливает значение элемента как "просмотренный" *)
value mask_set x y =
		let el = DynArray.get mask (x + y * !img_w) in DynArray.set mask (x + y * !img_w) (True, snd el);

(* Массив с вычленными областями *)
value regions = ref [];
(* Отдельная область *)
value part = ref [];
value regions_print () = 
		List.iter (fun x ->
				(
						Printf.printf "List length is %u\n%!" (List.length x);
				)
		) !regions;

   value _path = ref "";
value saveImgs () =
   (
    let name = Printf.sprintf "%s" !fileName in
    let path = Filename.concat "atlas_resources" name  in 
    let path = Printf.sprintf "%s/%s" !_path path in
    

      (
        if Sys.file_exists path then ()
        else Unix.mkdir path  0o755;
        );
        let fname =
          try
           fst (ExtLib.String.split !fileName "@")
          with [_ -> !fileName]
        in
  let s = ref "{" in
  let a = Array.make (List.length !regions) (0,0.) in
  let sum = ref 0 in
  (
  let num = ref 0 in
		List.iter (fun l ->
				(
						let rgba = Rgba32.make !img_w !img_h {Color.color = {Color.r=255;g=255;b=255}; alpha=0;} in
						(
								List.iter (fun (x, y) ->
										(
												Rgba32.set rgba x y ({Color.color =
                          {Color.r=255;g=255;b=255};alpha=255})
										)
								) l;
                if !notSave then ()
                else let canvas = Images.Rgba32 rgba in
                let save_path =Printf.sprintf "%satlas_resources/%s/%u.png" !_path !fileName !num in
                  (
                    Printf.printf "save_path %s\n%!" save_path;
                    Images.save save_path (Some Images.Png) [] canvas
                  )
						);
            let countPx = List.length l in (
            Array.set a !num (!num,float_of_int countPx);
            Printf.printf "%d\n" countPx;
         (*   sum.val := !sum + countPx;*)
            num.val := !num + 1;
        )
				)
    ) !regions;
    
    ignore(Array.map (fun (i,el) -> s.val:= Printf.sprintf "%s\n\"%s\": %f," !s
    (string_of_int i) el ) a);
    String.set (!s)(String.length !s - 1) '}';
    Printf.printf "%s %s %d" fname !s !sum;
    (*json with count of pixels*)
    (*Ojson.from_string (Printf.sprintf"%s" List.length l);
     * *)
   let out = open_out (Printf.sprintf "./Resources/textures/%s/%s%s.json" fname fname !suffix) in
   (
    output_string out !s;
    close_out out;
   )

  ) );


value stack = Stack.create ();
value rec min_x x y = 
    if (x - 1 >= 0) && (mask_check (x - 1) y)
       then min_x (x - 1) y
          else x;
             
          value rec max_x x y = 
              if (x + 1 < !img_w) && (mask_check (x + 1) y)
                 then max_x (x + 1) y
                    else x;

value _checkAreaFor x y = 
    if mask_check_alpha x y then
		(
      part.val := [(x, y) :: !part];
      let min = min_x x y
      and max = max_x x y in
      let x_left = (*if min - 1 >= 0 then min - 1 else*) min in
       let x_right = (*if max + 1 < !img_w then max + 1 else*) max in
     (* попытка улучшить алгоритм - флаги - находимся ли мы на непрерывном
      * участке строки*)
       (let flag_up = ref True
        and flag_down = ref True in
        for i = x_left to x_right do
         part.val := [(i, y) :: !part];
         mask_set i y;
          if (y + 1 < !img_h) && (mask_check i (y + 1)) then
            if !flag_up  then
            ( 
              mask_set i (y + 1);
              Stack.push (i, y + 1) stack;
              flag_up.val := False
            )
            else ()
          else flag_up.val := True;
          if (y - 1 >= 0) && (mask_check i (y - 1)) then
            if !flag_down then
            ( 
              mask_set i (y - 1);
              Stack.push (i, y - 1) stack;
              flag_down.val := False
            )
            else ()
          else flag_down.val := True
        
       done;
     )
    )
    else ();
value checkAreaFor x y =
		if not (mask_check_marked x y) then
		(
				Stack.push (x, y) stack;
				mask_set x y;
				part.val := [];

				while Stack.length stack > 0 do
						let el = Stack.pop stack in
						_checkAreaFor (fst el) (snd el)
				done;

				if List.length !part > !size then
				(
						regions.val := [!part :: !regions];
						part.val := []
				) else ()
		) else ();

(* Основная функция - выделяем аргументы, подгружаем исходную картинку *)
value main () =
		let files = ref [] in
		(
      Printf.printf "hello\n";
				Arg.parse 
        [
          ("-size", Arg.Set_int size , "Minimal size of region" );
          ("-o", Arg.Set_string fileName, "output file name" );
          ("-w", Arg.Set_int _width, "output width" );
          ("-h", Arg.Set_int _height, "output height" );
          ("-s", Arg.Set_string suffix, "resources_suffix");
          ("-ma", Arg.Set_int max_alpha, "max alpha value for region");
          ("-ns", Arg.Set notSave, "don t save images");
        ]
        (fun s -> files.val := [s :: !files]) "makemaker src dst";
				let (src, dst) =
						match List.rev !files with
						[ [src; dst] -> (src, dst)
						| _ -> invalid_arg "E: too few params\n%!"
						] in
				try
				(
          _path.val := dst;
          let lib = LLib.load src !suffix in
          let ((x,y),cont) = LLib.symbol lib "Skins.Contour" in
						let contour =
								match cont with
								[ Images.Rgba32 i -> i 
								| Images.Rgb24 i -> Rgb24.to_rgba32 i
								(* FIXME - допили меня для других вариантов *)
								| _ -> assert False
								]
            in
          let () = Printf.printf "contour matched\n" in
          let w = !_width (*if contour.Rgba32.width > 1030 then 2048 else 1024 *)in
          let h = !_height(*if contour.Rgba32.height > 780 then 1536 else 768 i*)in
          let () = Printf.printf "x y  w h cw ch %u %u %u %u %u %u\n" x y w h contour.Rgba32.width
             contour.Rgba32.height in
          let img = Rgba32.make w h {Color.color = {Color.r=0;g=0;b=0};
          alpha=0;} in
          (
            let width = if w< (contour.Rgba32.width+x) then w-x else
              contour.Rgba32.width
            and height = if h< (contour.Rgba32.height+y) then h-y else
              contour.Rgba32.height
            in 
            Rgba32.blit contour 0 0 img x y width height;
								img_w.val := 
                  img.Rgba32.width;
								img_h.val := 
                  img.Rgba32.height;
                  Printf.printf " w h %u %u" !img_w !img_h;
								_img.val := Some img;
								mask_init ();

								for x = 0 to !img_w - 1 do
										for y = 0 to !img_h - 1 do
										(
												checkAreaFor x y
										) done
								done;
								
								saveImgs ();

                let map = Array.make_matrix !img_w !img_h 0 in
								(
                  let reg_num = ref 1 in
								  (
										List.iter (fun el ->
												(
														List.iter (fun el2 ->
																(
																	map.(fst el2).(snd el2) := !reg_num
																)
														) el;

														incr reg_num
												)
										) !regions;
                  ); 

                  if !notSave then ()
                  else

                    let out = open_out (Printf.sprintf "%smaps/%s.map" dst !fileName) in
                    (
                      let binout = IO.output_channel out in
                      (
                        IO.write_ui16 binout !img_w;
                        IO.write_ui16 binout !img_h;

                        let sum = ref 0 in
                        let cur = ref map.(0).(0) in
                        let count = ref 0 in
                        (
                          Printf.printf "img: %d %d\n" !img_w !img_h;
                        for j = 0 to !img_h - 1 do
                          for i = 0 to !img_w - 1 do
                            (

                              if !cur <> map.(i).(j) 
                              
                              then 
                                (

                                  IO.write_byte binout !cur;
                                  IO.write_i32 binout !count;
                                  sum.val := !sum + !count;
                                  cur.val  := map.(i).(j);
                                  count.val := 1
                                )
                              else
                                incr count;
                            )

                          done;
                          done;
                                  IO.write_byte binout !cur;
                                  IO.write_i32 binout !count;

                                  sum.val := !sum + !count;
                            Printf.printf "sum %d\n%!" !sum;
                      )
                            );

                            close_out out;
                      )
            )
            )
				)
        with [Images.Wrong_file_type -> Printf.eprintf "E: Wrong file type: %s\n%!" src ]
 );

main ();

