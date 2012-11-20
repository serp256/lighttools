open Images;

value pfolder = ref "palletes";
value p_width = 256;
value pallete_size = p_width * p_width;
value (//) = Filename.concat;
value zclr = {Color.color={Color.r=0;g=0;b=0}; alpha=0;};
value make_preview = ref False;
value only_colors = ref False;
value first_pallete = ref 0;

value skip_pixels = ref [];

value string_of_color clr = let open Color in Printf.sprintf "%x%x%x,a=%x" clr.color.r clr.color.g clr.color.b clr.alpha;

module Pallete = struct
  type t = array (array (option Color.rgba));

  value create () = 
    let res = Array.init p_width (fun _ -> Array.make p_width None) in
    (
      res.(0).(0) := Some zclr;
      res;
    );

  value add p eclr = 
    let rec loop x y = 
      match p.(y).(x) with
      [ None -> 
        let (x,y) = 
          match !skip_pixels with
          [ [] -> (x,y)
          | _ -> 
              let nx = 
                if List.mem x !skip_pixels
                then x + 1
                else x
              and ny = 
                if List.mem y !skip_pixels
                then y + 1
                else y
              in
              (
                if nx <> x || ny <> y 
                then p.(y).(x) := Some zclr
                else ();
                (nx,ny)
              )
          ]
        in
        (
          p.(y).(x) := Some eclr;
          Some (x,y)
        )
      | Some clr ->
        let res = 
          if clr.alpha = eclr.alpha
          then
            let dist = Color.Rgb.square_distance clr.color eclr.color in
            if dist < 33 && dist >= 0 
            then True
            else False
          else False
        in
        match res with
        [ True -> Some (x,y)
        | False when (x + 1) < p_width -> loop (x+1) y
        | False when (y + 1) < p_width -> loop 0 (y + 1)
        | False -> None
        ]
      ]
    in
    loop 0 0;


  value load fname = 
    let img = Images.load fname [] in
    let p = create () in
    (
      Utils.image_iter begin fun x y clr -> 
        if clr <> zclr 
        then p.(y).(x) := Some clr
        else ()
      end img;
      p;
    );

  value save p outputf = 
    let out = Rgba32.make p_width p_width zclr in
    (
      let x = ref 0
      and y = ref 0
      and stop = ref False in
      while !y < p_width && not !stop do
        match p.(!y).(!x) with
        [ None -> stop.val := True
        | Some clr ->
          (
            Rgba32.set out !x !y clr;
            incr x;
            if !x = p_width 
            then (incr y; x.val := 0;)
            else ();
          )
        ]
      done;
      Images.save outputf (Some Png) [] (Rgba32 out);
      Printf.printf "pallete %s saved\n%!" outputf;
    );

end;


value image_iter = Utils.image_iter;


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
  let colorMap = Hashtbl.create 1024 in
  try
    Array.iter begin fun clr ->
    (
      if not (Hashtbl.mem colorMap clr)
      then
        match Pallete.add pallete clr with
        [ None -> raise Exit
        | Some eidx ->
            (*
              try
                let res = 
                  DynArray.index_of begin fun eclr -> 
                    let dist = Color.Rgb.square_distance clr.color eclr.color in
                    if dist < 33 & dist >= 0 & clr.alpha == eclr.alpha (* CHECK THIS *)
                    then True
                    else False
                  end pallete
                in
                let x = res mod p_width in
                and y = res / p_width in
                let x = match x with [ 128 -> 129 | _ -> x ] 
                and y = match y with [ 128 -> 129 | _ -> y ] in
                y * p_width + x
              with 
              [ Not_found -> begin
                  DynArray.add pallete clr;
                  let idx = (DynArray.length pallete) - 1 in
                  let x = res mod p_width in
                  and y = res / p_width in
                  match x with
                  [ 128 -> (DynArray.add pallete clr; idx + 1)
                  | _ -> idx
                  ]
                end
              ]
            in
            *)
            Hashtbl.add colorMap clr eidx
        ]
      else ()
    )
    end colors;
    Some colorMap;
  with [ Exit -> None ];

  (* подобрать размеры картинки нахуй *)



value rec palletes () = 
  let i = ref (!first_pallete - 1) in
  let finished = ref False in
  Enum.from begin fun () ->
    if !finished then raise Enum.No_more_elements
    else
      let () = incr i in
      let plt = !pfolder // (Printf.sprintf "%d.plt" !i) in
      match Sys.file_exists plt with
      [ True ->
        let pallete = Pallete.load plt in
        (!i,pallete)
      | False -> 
        (
          finished.val := True;
          (!i,Pallete.create ())
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
          match reduce_colors pallete colors with
          [ None -> try_pallete ()
          | Some remapTable ->
            (
              Pallete.save pallete (!pfolder // (Printf.sprintf "%d.plt" pn));
              (* сделаем превью *)
              let prefix = Filename.chop_extension file in
              let (w,h) = Images.size image in
              let preview = Rgba32.make w h zclr in
              let index = Utils.gzip_output ~level:3 (Printf.sprintf "%s.plx" prefix) in
              (
                IO.write_byte index pn;
                IO.write_ui16 index w;
                IO.write_ui16 index h;
                image_iter begin fun x y clr ->
                (
                  let (px,py) = Hashtbl.find remapTable clr in
                  (
                    if !make_preview 
                    then
                      match pallete.(py).(px) with
                      [ None -> assert False
                      | Some clr -> 
(*                         let () = Printf.printf "color: %s\n%!" (string_of_color clr) in *)
                        Rgba32.set preview x y clr
                      ]
                    else ();
(*                     let x = idx mod pw in *)
                    IO.write_byte index px;
(*                     let y = idx / pw in *)
                    IO.write_byte index py;
                  )
                )
                end image;
                IO.close_out index;
                if !make_preview
                then
                  Images.save (Printf.sprintf "%s_preview.png" prefix) (Some Png) [] (Rgba32 preview)
                else ();
              )
            )
          ]
        | None -> failwith (Printf.sprintf "Can't add %s to pallete of 256x256" file)
        ];


(* Мы даем картинки и папку с палитрами, нужно попытаца впихнуть в любую из этих палитр нахуй *)
value () = 
  let files = RefList.empty () in
  (
    Arg.parse 
      [
        ("-c",Arg.Set only_colors,"show only cnt colors in images");
        ("-plt",Arg.Set_string pfolder,"pallete folder");
        ("-p",Arg.Set make_preview,"make preview");
        ("-fp",Arg.Set_int first_pallete,"first_pallete");
        ("-skip-idx",Arg.Int (fun idx -> skip_pixels.val := [ idx :: !skip_pixels ]),"skip indexes (if bug in GPU)")
      ] 
      (fun s -> RefList.push files s) "";
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
