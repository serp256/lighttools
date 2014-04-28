
value chop_ext f = 
  try
    let idx = (String.rindex f '.') + 1 in
    String.sub f 0 (idx - 1)
  with [ Not_found -> f ];

value rec nextPowerOfTwo number =
  let rec loop result = 
    if result < number 
    then loop (result * 2)
    else result
  in 
  loop 1;


value iter_image f sx sy mx my = 
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
  

value iter_2d = iter_image;


value gzip_output ?level fname = 
  let gzout = Gzip.open_out ?level fname in
  IO.create_out
    ~write:(fun chr -> Gzip.output_char gzout chr)
    ~output:(fun buf pos len -> (Gzip.output gzout buf pos len; len))
    ~flush:(fun () -> Gzip.flush gzout)
    ~close:(fun () -> Gzip.close_out gzout);

(* iterate over image *)
value image_iter f img = 
  let (w,h) = Images.size img in
  iter_image begin fun x y ->
    let elt =
      match img with 
      [ Images.Rgb24  i24 -> 
        let elt = (Rgb24.get i24 x y) in
        { Color.Rgba.color = elt; alpha = 255 }
      | Images.Rgba32 i32 -> Rgba32.get i32 x y
      | _   -> failwith "Unsupported format"
      ]
    in 
    (f x y elt);
  end 0 0 w h;

value save_alpha ?(with_lum = False) img fname = 
  let binout = gzip_output ~level:3 fname in
  let (width,height) = Images.size img in
  (
    IO.write_ui16 binout width;
    IO.write_ui16 binout height;
    image_iter (fun _ _ clr ->
      (
        if with_lum
        then IO.write_byte binout Color.(clr.color.Rgb.r)
        else ();
        
        IO.write_byte binout clr.Color.alpha;
      )
    ) img;
    IO.close_out binout;
  );

value gzip_input fname =
  let gzin = Gzip.open_in fname in
  IO.create_in
    ~read:(fun () -> Gzip.input_char gzin)
    ~input:(fun buf pos len -> Gzip.input gzin buf pos len)
    ~close:(fun () -> Gzip.close_in gzin);


value pvr_png img = 
  let cmd = Printf.sprintf "PVRTexTool -yflip0 -fOGLPVRTC4 -premultalpha -pvrtcbest -i%s.png -o %s.pvr" img img in
  (
    Printf.printf "%s\n%!" cmd;
    match Sys.command cmd with
    [ 0 -> ()
    | _ -> failwith (Printf.sprintf "Failed pvr %s.png" img)
    ];
  );

value dxt_png img = 
  let cmd = Printf.sprintf "nvcompress -nomips -fast -bc3 %s.png %s.dds" img img in
  (
    Printf.printf "%s\n%!" cmd;
    match Sys.command cmd with
    [ 0 -> ()
    | _ -> failwith (Printf.sprintf "Failed dxt %s.png" img)
    ];
  );  

value plx_png plt img = 
  let cmd = Printf.sprintf "pallete -plt %s %s.png" plt img in
  (
    Printf.printf "%s\n%!" cmd;
    match Sys.command cmd with
    [ 0 -> ()
    | _ -> failwith (Printf.sprintf "Failed plx %s.png" img)
    ];
  );

value gzip_img img =
  let cmd = Printf.sprintf "gzip %s" img in
  (
    Printf.printf "%s\n%!" cmd;
    match Sys.command cmd with
    [ 0 -> ignore(Sys.command (Printf.sprintf "mv %s.gz %s" img img))
    | _ -> failwith (Printf.sprintf "Failed gzip %s" img)
    ];
  );

value round (v:float) : float = 
  let mult  = if v < 0. then ~-.1. else 1. in
  let v_abs = abs_float v in
  let v' = ceil v_abs in
  match v' -. v_abs > 0.5 with
  [ True -> mult *. (v' -. 1.)
  | _ -> mult *. v'
  ];
  


  (* Создание директории *)
value makeDir path = (
  if not (Sys.file_exists path)
  then Unix.mkdir path 0o775
  else ()
);


value readUTF ?(endian = `little) inp = 
  let read_i16 = match endian with [ `little -> IO.read_i16 | `big -> IO.BigEndian.read_i16 ] in
  let len = read_i16 inp in
    IO.nread inp len;

value writeUTF ?(endian = `little) out str =
  let write_i16 = match endian with [ `little -> IO.write_i16 | `big -> IO.BigEndian.write_i16 ] in
    (
      write_i16 out (String.length str);
      IO.nwrite out str;
    );

value pngDims fname =
  (* let fname   = escapePath fname in *)
  (* let ()  = Printf.printf "\n fname escaping %s" (fname) in *)
  let inpChan = open_in fname in
  let inp = IO.input_channel inpChan in
  let module IO = IO.BigEndian in
    (
      ignore(IO.read_real_i32 inp);
      ignore(IO.read_real_i32 inp);
      ignore(IO.read_real_i32 inp);
      ignore(IO.read_real_i32 inp);

      let w = IO.read_i32 inp in
      let h = IO.read_i32 inp in
        (
          close_in inpChan;
          (w, h);
        );
    );

value rectsUnion (x1, y1, w1, h1) (x2, y2, w2, h2) = (
  if (w1 = 0.0 && h1 = 0.0) then ((x2, y2, w2, h2)) 
  else(
    let x_list = ExtList.List.sort [x1; x1 +. w1; x2; x2 +. w2] in
    let new_x  = ExtList.List.first x_list in
    let new_w  = (ExtList.List.last x_list) -. new_x in
    let y_list = ExtList.List.sort [y1; y1 +. h1; y2; y2 +. h2] in
    let new_y  = ExtList.List.first y_list in
    let new_h  = (ExtList.List.last y_list) -. new_y in
      (new_x, new_y, new_w, new_h)
  )
);

value int_of_bool = (
  fun [True -> 1 | False -> 0]
);

(* value round x = truncate (f x) where f = fun [ x when x > 0. -> x +. 0.5 | x -> x -. 0.4999 ]; *)
