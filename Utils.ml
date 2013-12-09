
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
        IO.write_byte binout clr.Color.alpha;
        
        if with_lum
        then IO.write_byte binout Color.(clr.color.Rgb.r)
        else ();
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
