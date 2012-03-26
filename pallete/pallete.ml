open Images;

value pfolder = ref "palletes";
value pallete_size = 256 * 256;
value (//) = Filename.concat;
value zclr = {Color.color={Color.r=0;g=0;b=0}; alpha=0;};
value make_preview = ref False;
value only_colors = ref False;

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
  (
    image_iter (fun _ _ clr -> HSet.add clrTable clr) img;
    let result = Array.make (HSet.length clrTable) zclr in
    let i = ref 0 in
    (
      HSet.iter (fun k -> (result.(!i) := k; incr i)) clrTable;
      result;
    );
  );

(* build color table *)
value reduce_colors pallete colors = 
  let colorMap = Hashtbl.create 3 in
  (
    Array.iter begin fun clr ->
      if not (Hashtbl.mem colorMap clr)
      then
        let eidx = 
          try
            DynArray.index_of begin fun eclr -> 
              let dist = Color.Rgb.square_distance clr.color eclr.color in
              if dist < 33 & dist >= 0 & clr.alpha == eclr.alpha (* CHECK THIS *)
              then True
              else False
            end pallete
          with [ Not_found -> (DynArray.add pallete clr;(DynArray.length pallete) - 1) ]
        in
        Hashtbl.add colorMap clr eidx
      else ()
    end colors;
    colorMap;
  );

value save_pallete pallete outputf = 
  let cnt_colors = DynArray.length pallete in
  let (w,h) = (256,256)
    (*
    find_size 8 8 where 
    rec find_size w h =
      if (w * h) >= cnt_colors
      then (w,h)
      else 
        if w > h then find_size w (h*2) else find_size (w*2) h
    *)
  in
  let out = Rgba32.make w h zclr in
  (
    let i = ref 0
    and x = ref 0 
    and y = ref 0
    in
    while (!i < cnt_colors) do
      Rgba32.set out !x !y (DynArray.get pallete !i);
      incr x;
      if !x = w 
      then (incr y; x.val := 0;)
      else ();
      incr i;
    done;
    Images.save outputf (Some Png) [] (Rgba32 out);
    Printf.printf "pallete %s saved\n%!" outputf;
    (w,h)
  );
  (* подобрать размеры картинки нахуй *)



value rec palletes () = 
  let i = ref ~-1 in
  let finished = ref False in
  Enum.from begin fun () ->
    if !finished then raise Enum.No_more_elements
    else
      let () = incr i in
      let plt = !pfolder // (Printf.sprintf "%d.plt" !i) in
      match Sys.file_exists plt with
      [ True ->
          let img = Images.load plt [] in
          let pallete = DynArray.make pallete_size in
          (
            image_iter begin fun x y clr -> 
              if clr <> zclr || (y = 0 && x = 0)
              then DynArray.add pallete clr
              else ()
            end img;
            (!i,pallete)
          )
      | False -> 
        (
          finished.val := True;
          let p = DynArray.make pallete_size in
          (
            DynArray.add p zclr;
            (!i,p)
          )
        )
      ]
  end;

(* *)
value process_file file = 
  let () = Printf.printf "--> PROCESS '%s'\n%!" file in
  let image = Images.load file [] in
  let colors   = get_colors image in
  let () = Printf.eprintf "Total %d colors\n%!" (Array.length colors) in
  if !only_colors then ()
  else
  let palletes = palletes () in
    try_pallete () where
      rec try_pallete () = 
        match Enum.get palletes with
        [ Some (pn,pallete) ->
          let () = Printf.printf "Try %d pallete\n%!" pn in
          let remapTable = reduce_colors pallete colors in
          if DynArray.length pallete > pallete_size
          then try_pallete ()
          else
            let () = Printf.eprintf "Reduced to %d colors (keys in table %d)\n%!" (DynArray.length pallete) (Hashtbl.length remapTable) in
        (*     let prefix = Filename.chop_extension (Filename.basename fn) in *)
            let (pw,ph) = save_pallete pallete (!pfolder // (Printf.sprintf "%d.plt" pn)) in
            (* сделаем превью *)
            let prefix = Filename.chop_extension file in
            let (w,h) = Images.size image in
            let preview = Rgba32.make w h zclr in
            let index = IO.output_channel (open_out_bin (Printf.sprintf "%s.plx" prefix)) in
            (
              IO.write_byte index pn;
              IO.write_ui16 index w;
              IO.write_ui16 index h;
              image_iter begin fun x y clr ->
                (
                  let idx = Hashtbl.find remapTable clr
                  in
                  (
                    if !make_preview 
                    then
                      let clr = DynArray.get pallete idx in
                      Rgba32.set preview x y clr
                    else ();
                    let x = idx mod pw in
                    IO.write_byte index x;
                    let y = idx / pw in
                    IO.write_byte index y;
                  )
                )
              end image;
              IO.close_out index;
              if !make_preview
              then
                Images.save (Printf.sprintf "%s_preview.png" prefix) (Some Png) [] (Rgba32 preview)
              else ();
            )
          | None -> failwith (Printf.sprintf "Can't add %s to pallete of 256x256" file)
        ];


(* Мы даем картинки и папку с палитрами, нужно попытаца впихнуть в любую из этих палитр нахуй *)
value () = 
  let files = RefList.empty () in
  (
    Arg.parse [("-c",Arg.Set only_colors,"show only cnt colors in images");("-plt",Arg.Set_string pfolder,"pallete folder");("-p",Arg.Set make_preview,"make preview")] (fun s -> RefList.push files s) "";
    if RefList.is_empty files
    then failwith ("select images")
    else
    (
      if Sys.file_exists !pfolder
      then 
        if not (Sys.is_directory !pfolder)
        then 
          failwith (Printf.sprintf "pallete folder %s is not directory" !pfolder)
        else ()
      else Unix.mkdir !pfolder 0o774;
      RefList.iter begin fun pf ->
        if Sys.file_exists pf
        then
          if Sys.is_directory pf
          then
            let files = Sys.readdir pf in
            Array.iter begin fun fn ->
              match Filename.check_suffix fn ".png" with
              [ True -> process_file (pf // fn)
              | False -> ()
              ]
            end files
          else process_file pf
        else Printf.printf "!!! SKIP %s not exists\n%!" pf
      end files;
    )
  );
