open ExtList;

value texInfo = "texInfo.dat";
value frames = "frames.dat";

value (///) = Filename.concat;

type layer =
  {
    imgId   : int;
    lx       : int;
    ly       : int;
    alpha   : int;
    flip    : bool;
  };

type frame = 
  {
    x       : int;
    y       : int;
    iconX   : int;
    iconY   : int;
    layers  : list layer; 
  };

value read_utf inp = 
  let len = IO.read_i16 inp in
  IO.really_nread inp len;

value write_utf out str=
  (
    IO.write_i16 out (String.length str);
    IO.nwrite out str;
  );

value inp_dir = ref "input"; 
value outdir = ref "output";
value gen_pvr = ref False;
value start_num = ref 0;
value scale = ref 1.;


value get_postfix () =
  match !scale with
  [ 1. -> ""
  | _ -> "x" ^ (snd ( ExtString.String.replace ~str:(string_of_float !scale) ~sub:"." ~by:""))
  ];

  value round v = 
  let mult = 
    match v < 0. with
    [ True -> ~-.1.
    | _ -> 1.
    ]
  in
  let absv = abs_float v in
  let f = floor absv in
  match absv -. f >= 0.5 with
  [ True -> truncate ( mult *. (absv +. 1.))
  | _ ->  truncate (mult *. absv)
  ];

  (*
value get_images dir images  =
  let texInfo = !inp_dir /// dir /// texInfo in
  let texInfo = IO.input_channel (open_in texInfo) in 
  let countTex = IO.read_ui16 texInfo in
  let () = Printf.printf "count textures : %d\n%!" countTex in
  let rec imagesByTexture img countImage id s images =
    match countImage with
    [ 0 -> (id, s, images) 
    | _ ->
        let sx = IO.read_ui16 texInfo in
        let sy = IO.read_ui16 texInfo in
        let iw = IO.read_ui16 texInfo in
        let ih = IO.read_ui16 texInfo in
        let image = Images.sub img sx sy iw ih in
        let image = 
          match !scale with
          [ 1. -> image
          | _ -> 
              let w = round ((float iw) *. !scale) 
              and h = round ((float ih) *. !scale) 
              in
              let () = Printf.printf "old image [ %d; %d ] ro new [ %d; %d]  \n%!" iw ih w h in
              match image with
              [ Images.Rgb24 image -> Images.Rgb24 (Rgb24.resize None image w h)
              | Images.Rgba32 image -> Images.Rgba32 (Rgba32.resize None image w h)
              | Images.Cmyk32 image -> Images.Cmyk32 (Cmyk32.resize None image w h)
              | _ -> failwith "incorrect type image"
              ]
          ]
        in
        imagesByTexture img (countImage - 1) (id +1) (s + iw * ih) [ ((id,dir), image) :: images ]
    ]
  in
  let rec readTexture countTex (id,s,images) =
    match countTex with
    [ 0 -> (s,dir, images)
    | _ ->
        let name = !inp_dir /// dir /// read_utf texInfo in
        let () = Printf.printf "Try open %s\n%!" name in
        let texture = Images.load name [] in 
        let count = IO.read_ui16 texInfo in
        readTexture (countTex - 1) (imagesByTexture texture count id s images) 
    ]
  in
  let res = [ readTexture countTex (0,0,[]) :: images ] in
    (
      IO.close_in texInfo;
      res
    );
*)

value get_images dirs images  =
  let get_images_by_dir dir s images = 
    let texInfo = !inp_dir /// dir /// texInfo in
    let texInfo = IO.input_channel (open_in texInfo) in 
    let countTex = IO.read_ui16 texInfo in
    let () = Printf.printf "count textures : %d\n%!" countTex in
    let rec imagesByTexture img countImage id s images =
      match countImage with
      [ 0 -> (id, s, images) 
      | _ ->
          let sx = IO.read_ui16 texInfo in
          let sy = IO.read_ui16 texInfo in
          let iw = IO.read_ui16 texInfo in
          let ih = IO.read_ui16 texInfo in
          let image = Images.sub img sx sy iw ih in
          let image = 
            match !scale with
            [ 1. -> image
            | _ -> 
                let w = round ((float iw) *. !scale) 
                and h = round ((float ih) *. !scale) 
                in
                match image with
                [ Images.Rgb24 image -> Images.Rgb24 (Rgb24.resize None image w h)
                | Images.Rgba32 image -> Images.Rgba32 (Rgba32.resize None image w h)
                | Images.Cmyk32 image -> Images.Cmyk32 (Cmyk32.resize None image w h)
                | _ -> failwith "incorrect type image"
                ]
            ]
          in
          imagesByTexture img (countImage - 1) (id +1) (s + iw * ih) [ ((id,dir), image) :: images ]
      ]
    in
    let rec readTexture countTex (id,s,images) =
      match countTex with
      [ 0 -> (s,images)
      | _ ->
          let name = !inp_dir /// dir /// read_utf texInfo in
          let () = Printf.printf "Try open %s\n%!" name in
          let texture = Images.load name [] in 
          let count = IO.read_ui16 texInfo in
          readTexture (countTex - 1) (imagesByTexture texture count id s images) 
      ]
    in
    let res = readTexture countTex (0,s,images) in
      (
        IO.close_in texInfo;
        res
      )
  in
  let res = 
    List.fold_left begin fun (s,imgs) dir ->
      get_images_by_dir dir s imgs 
    end (0, []) dirs  
  in
  [ res :: images ];


 

value copyFrames dir =
  let inp =IO.input_channel (open_in (!inp_dir /// dir /// "frames.dat")) in 
  let out = IO.output_channel (open_out (!outdir /// dir /// "frames" ^ (get_postfix ()) ^  ".dat")) in
  let () = Printf.printf "Copy frames  %s \n%!" dir in
  let cnt_frames = IO.read_i32 inp in
  (
    IO.write_i32 out cnt_frames;
    for i = 1 to cnt_frames do
      (
        let x = IO.read_i16 inp in
        let y = IO.read_i16 inp in
        let ix = IO.read_i16 inp in
        let iy = IO.read_i16 inp in
        let newx =round (!scale *.  (float x)) in
        let newy =round (!scale *.  (float y)) in
        let newix =round (!scale *.  (float ix)) in
        let newiy =round (!scale *.  (float iy)) in
          (
            IO.write_i16 out newx;
            IO.write_i16 out newy;
            IO.write_i16 out newix;
            IO.write_i16 out newiy;
(*
            IO.write_i16 out (truncate (round (!scale *.  (float(IO.read_i16 inp))))); (*x*)
            IO.write_i16 out (truncate (round (!scale *.  (float(IO.read_i16 inp))))); (*y*)
            IO.write_i16 out (truncate (round (!scale *.  (float(IO.read_i16 inp))))); (*ix*)
            IO.write_i16 out (truncate (round (!scale *.  (float(IO.read_i16 inp))))); (*iy*)
            *)
            let cnt_items = IO.read_byte inp in
            (
              IO.write_byte out cnt_items;
              for it = 1 to cnt_items do
                (
                  IO.write_byte out (IO.read_byte inp); (*texID*)
                  IO.write_i32 out (IO.read_i32 inp); (*recID *)
                  let lx = IO.read_i16 inp in 
                  let ly = IO.read_i16 inp in 
                  let newlx = round ((!scale *. (float (lx + x))) -. (float newx)) in
                  let newly = round ((!scale *. (float (ly + y))) -. (float newy)) in
                    (
                      IO.write_i16 out newlx;
                      IO.write_i16 out newly;
                    );
                    (*
                  IO.write_i16 out (truncate (round (!scale *.  (float(IO.read_i16 inp))))); (*xi*)
                  IO.write_i16 out (truncate (round (!scale *.  (float(IO.read_i16 inp))))); (*yi*)
                  *)
                  IO.write_byte out (IO.read_byte inp); (*alpha*)
                  IO.write_byte out (IO.read_byte inp); (*flip*)
                )
              done;
            )
          );

      )
    done;
    IO.close_in inp;
    IO.close_out out;
  );(*}}}*)

value copyAnimations dir =
  let inp =IO.input_channel (open_in (!inp_dir /// dir /// "animations.dat")) in 
  let out = IO.output_channel (open_out (!outdir /// dir /// "animations" ^ (get_postfix ()) ^ ".dat")) in
  let cnt_objects = IO.read_ui16 inp in
    (
      IO.write_ui16 out cnt_objects;
      for _i = 1 to cnt_objects do
        (
          write_utf out (read_utf inp) (*objname*);
          let cnt_animations = IO.read_ui16 inp in
          (
            IO.write_ui16 out cnt_animations; 
            for _j = 1 to cnt_animations do
              (
                write_utf out (read_utf inp); (* animname*)
                IO.write_real_i32 out (IO.read_real_i32 inp); (* framerate *) 
                let cnt_rects = IO.read_byte inp in
                  (
                    IO.write_byte out cnt_rects;
                    for i = 1 to cnt_rects do
                      (
                        IO.write_i16 out (truncate (!scale *. (float (IO.read_i16 inp)))); (*x*)
                        IO.write_i16 out (truncate (!scale *. (float (IO.read_i16 inp)))); (*y*)
                        IO.write_i16 out (truncate (!scale *. (float (IO.read_i16 inp))));  (*w*)
                        IO.write_i16 out (truncate (!scale *. (float (IO.read_i16 inp))));  (*h*)
                      )
                    done;
                    let cnt_frames = IO.read_ui16 inp in
                      (
                        IO.write_ui16 out cnt_frames;
                        for i = 1 to cnt_frames do
                          IO.write_i32 out (IO.read_i32 inp)
                        done;
                      )
                  );
              )
            done;
          ); 
        )
      done;
      IO.close_in inp;
      IO.close_out out;
    );


value convert idTex  imgs =
  let convert_dir dir imgs = 
    let res_dir = !outdir /// dir in
      (
        match Sys.file_exists res_dir with
        [ False -> Unix.mkdir res_dir 0o755
        | _ -> ()
        ];
        let newTexInfo = res_dir /// "texInfo" ^ (get_postfix ()) ^".dat" in
        let newTexInfo = IO.output_channel (open_out newTexInfo) in
          (
            copyAnimations dir;
            copyFrames dir;
            (*
            ignore(Sys.command (Printf.sprintf "cp -f %s/%s/animations.dat %s" !inp_dir dir res_dir));
            ignore(Sys.command (Printf.sprintf "cp -f %s/%s/frames.dat %s" !inp_dir dir res_dir));
            *)
            IO.write_ui16 newTexInfo 1;
            write_utf newTexInfo ((string_of_int idTex) ^ (get_postfix ()) ^ ".png");
            IO.write_ui16 newTexInfo (List.length imgs);
            List.iteri begin fun i (urlId,(sx,sy,isRotate,img)) ->
            (
              let (iw,ih) = Images.size img in
              (
                IO.write_ui16 newTexInfo sx;
                IO.write_ui16 newTexInfo sy;
                IO.write_ui16 newTexInfo iw;
                IO.write_ui16 newTexInfo ih;
             (*   IO.write_byte newTexInfo (match isRotate with [ True -> 1 | _ -> 0]); *)
              );
            )
            end imgs;
            IO.close_out newTexInfo;
          );
        ) 
  in
  let images = 
    List.fold_left begin fun res (((_,name), _) as info) -> 
      let (imgs_by_dir, imgs) = 
        try
          MList.pop_assoc name res 
        with
          [ Not_found -> ([], res) ]
      in
      [  (name , [ info :: imgs_by_dir ]) :: imgs ] 
    end [] imgs 
  in
  List.iter (fun (dir, images) -> convert_dir dir (List.rev images)) images;

  
value postfixs = [ "_ex"; "_sh" ];

value run () =
  let _ = Sys.command (Printf.sprintf "cp -f %s/info_objects.xml %s" !inp_dir !outdir) in
  let images = 
    Array.fold_left begin fun images path -> 
      let () = Printf.printf "try convert %s\n%!" path in 
      match Sys.is_directory (!inp_dir /// path) with
      [ True -> 
          let pstfx = String.sub path ((String.length path) - 3) 3  in
          match List.mem pstfx postfixs with
          [ True ->  images
          | _ ->
              let dirs = 
                List.filter_map begin fun p ->
                  let path = path ^ p in
                  let dir = !inp_dir /// path in
                  match (Sys.file_exists dir) && (Sys.is_directory dir) with
                  [ True -> Some path
                  | _ -> None
                  ]
                end [ "" :: postfixs ]
            in
            get_images dirs images
          ]
      | _ -> images 
      ]
    end [] (Sys.readdir !inp_dir)
  in
(*  let images = [(0,"pizda", List.fold_left (fun res (_,_,img) ->  res @ img) [] images)] in *)
  let images = List.fast_sort (fun (s1,_) (s2,_) -> compare s2 s1) images in  
  let textures = List.fold_left begin fun textures  (_,images) -> 
 (*   let () = Printf.printf "Layout %s\n%!" path in *)
    let (placed,_, textures) = MaxRects.layout ~pages:textures images in
    textures
  end [] images in 
(*  let textures = MaxRects.layout_last_page 1024 textures in *)
  List.iteri begin fun cnt (w,h,imgs,_,_) ->
    let cnt = cnt + !start_num in
    let rgb = Rgba32.make w h {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
    let new_img = Images.Rgba32 rgb in
      (
        Printf.printf "Save %d.png \n%!" cnt;
        List.iter begin fun imgs -> 
          (
            convert cnt imgs;
            List.iter begin fun (_,(sx,sy,isRotate,img)) ->
              let (iw,ih) = Images.size img in
                try
                  Images.blit img 0 0 new_img sx sy iw ih;
                with 
                  [ Invalid_argument _ -> 
                      (
                        match img with
                        [ Images.Index8 _ -> prerr_endline "index8"
                        | Images.Rgb24 _ -> prerr_endline "rgb24"
                        | Images.Rgba32 _ -> prerr_endline "rgba32"
                        | _ -> prerr_endline "other"
                        ];
                        raise Exit;
                      )
                  ]
            end imgs;
          )
        end imgs;
        let save_img = !outdir /// (string_of_int cnt) ^ (get_postfix ()) in
          (
            Images.save (save_img ^ ".png") (Some Images.Png) [] new_img;
            match !gen_pvr with
            [ True -> Utils.pvr_png save_img
            | _ -> ()
            ]
          );
      )
  end textures;

(*
value () = convert "an_chicken_ex";
*)

value () =
  (
    Arg.parse 
      [
        ("-inp",Arg.Set_string inp_dir,"input directory");
        ("-o",Arg.Set_string outdir, "output directory");
        ("-pvr",Arg.Set gen_pvr,"generate pvr file");
        ("-n",Arg.Set_int start_num,"set first name texture ");
        ("-p",Arg.Set_int TextureLayout.countEmptyPixels, "count Empty pixels between images");
        ("-min",Arg.Set_int MaxRects.min_size, "Min size texture");
        ("-scale", Arg.Set_float scale, "Scale factor")
      ]
      (fun _ -> ())
      "";
    run ();
  );


