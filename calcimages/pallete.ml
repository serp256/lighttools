open Images;

value iter_2d f sx sy mx my = 
  let y = ref sy in
  while !y < my do
  (
    let x = ref sx in
    while !x < mx do
    (
      f !x !y;
      incr x;
    )
    done; 
    incr y;
  ) done;
  

(* iterate over image *)
value image_iter f img = 
  let (w,h) = Images.size img in
  iter_2d begin fun x y ->
    let elt =
      match img with 
      [ Rgb24  i24 -> 
        let elt = (Rgb24.get i24 x y) in
        { Color.Rgba.color = elt; alpha = 1 }
      | Rgba32 i32 -> Rgba32.get i32 x y
      | _   -> failwith "Unsupported format"
      ]
    in 
    (f x y elt);
  end 0 0 w h;



(* return array of all colors *)
value get_colors img = 
  let clrTable = HSet.create 65001 in
  let () = image_iter (fun _ _ clr -> HSet.add clrTable clr) img in 
  let result = Array.make (HSet.length clrTable) {color={r=0;g=0;b=0};alpha=0} in
  let i = ref 0 in
  (
    HSet.iter (fun k -> (result.(!i) := k; incr i)) clrTable;
    result;
  );

(* build color table *)
value reduce_colors colors = 
  let colorMap = Hashtbl.create 3 in
  let reduced_colors = DynArray.make ((Array.length colors) / 2) in
  (
    Array.iter begin fun clr ->
      if not (Hashtbl.mem colorMap clr)
      then
        try
          let eidx = 
            DynArray.index_of begin fun eclr -> 
              let dist = Color.Rgb.square_distance clr.color eclr.color in
              if dist < 33 & dist > 0 & clr.alpha == eclr.alpha (* CHECK THIS *)
              then True
              else False
            end reduced_colors
          in
          Hashtbl.add colorMap clr eidx
        with [ Not_found -> DynArray.add reduced_colors clr ]
      else ()
    end colors;
    (DynArray.to_array reduced_colors, colorMap);
  );

value save_pallete pallete outputf = 
  let cnt_colors = Array.length pallete in
  let (w,h) = find_size 8 8 where 
    rec find_size w h =
      if (w * h) >= cnt_colors
      then (w,h)
      else 
        if w > h then find_size w (h*2) else find_size (w*2) h
  in
  let () = Printf.printf "pallete size: %d:%d\n" w h in
  let out = Rgba32.make w h {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
  (
    let i = ref 0
    and x = ref 0 
    and y = ref 0
    in
    while (!i < cnt_colors) do
      Rgba32.set out !x !y pallete.(!i);
      incr x;
      if !x = w 
      then (incr y; x.val := 0;)
      else ();
      incr i;
    done;
    Images.save "pallete.png" (Some Png) [] (Rgba32 out);
    (w,h)
  );
  (* подобрать размеры картинки нахуй *)

(* *)
value process_file fn = 
  let () = Printf.eprintf "Processing %s...  %!\n" fn in
  let image = Images.load fn [] in
  let colors   = get_colors image in
  let () = Printf.eprintf "Total %d colors\n%!" (Array.length colors) in
  let (pallete,remapTable) = reduce_colors colors in
  let () = Printf.eprintf "Reduced to %d colors (keys in table %d)\n%!" (Array.length pallete) (Hashtbl.length remapTable) in
  if Array.length pallete > 0b1111111111111111
  then failwith ("Big pallete!!!")
  else
    (* найти максимально квадратную текстуру со степенями 2 чтобы впихнуть ебанную палитру нахуй *)
    let (pw,ph) = save_pallete pallete "output.plt" in
    (* сделаем превью *)
    let (w,h) = Images.size image in
    let preview = Rgba32.make w h {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
    let index = IO.output_channel (open_out_bin "output.idx") in
    (
      IO.write_ui16 index w;
      IO.write_ui16 index h;
      let i = ref 0 in
      image_iter begin fun x y clr ->
        (
          let idx = 
            try
              Hashtbl.find remapTable clr
            with [ Not_found -> let r = !i in (incr i; r) ]
          in
          (
            Printf.printf "[%d:%d] index in pallete: %d\n" x y idx;
            let clr = pallete.(idx) in
            Rgba32.set preview x y clr;
            let x = idx mod pw in
            IO.write_byte index x;
            let y = idx / pw in
            IO.write_byte index y;
          )
        )
      end image;
      IO.close_out index;
      Images.save "preview.png" (Some Png) [] (Rgba32 preview);
    );


value () = process_file Sys.argv.(1);