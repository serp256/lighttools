
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
  iter_2d begin fun x y ->
    let elt =
      match img with 
      [ Images.Rgb24  i24 -> 
        let elt = (Rgb24.get i24 x y) in
        { Color.Rgba.color = elt; alpha = 1 }
      | Images.Rgba32 i32 -> Rgba32.get i32 x y
      | _   -> failwith "Unsupported format"
      ]
    in 
    (f x y elt);
  end 0 0 w h;

value save_alpha img fname = 
  let binout = gzip_output ~level:3 fname in
  let (width,height) = Images.size img in
  (
    IO.write_ui16 binout width;
    IO.write_ui16 binout height;
    image_iter (fun _ _ clr -> IO.write_byte binout clr.Color.alpha) img;
    IO.close_out binout;
  );

value gzip_input fname =
  let gzin = Gzip.open_in fname in
  IO.create_in
    ~read:(fun () -> Gzip.input_char gzin)
    ~input:(fun buf pos len -> Gzip.input gzin buf pos len)
    ~close:(fun () -> Gzip.close_in gzin);
