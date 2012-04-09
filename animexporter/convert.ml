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

value get_images dir images  =
  let texInfo = !inp_dir /// dir /// texInfo in
  let frameInfo =IO.input_channel (open_in (!inp_dir /// dir /// "frames.dat")) in 
  let rec getLayers cnt layers =
    match cnt with
    [ 0 -> layers 
    | _ ->
        (
          ignore(IO.read_byte frameInfo);
          let imgId = IO.read_i32 frameInfo in
          let lx = IO.read_ui16 frameInfo in
          let ly = IO.read_ui16 frameInfo in
          let alpha = IO.read_byte frameInfo in
          let flip = 
            match IO.read_byte frameInfo with
            [ 0 -> False 
            | _ -> True
            ]
          in
            (
              getLayers (cnt-1) [ {imgId; lx; ly; alpha; flip} :: layers]
            )
        )
    ]
  in
  let rec getFrames cnt frames = 
    match cnt with
    [ 0 -> 
        ( 
          IO.close_in frameInfo;
          frames;
        )
    | _ ->
        let x = IO.read_ui16 frameInfo in
        let y = IO.read_ui16 frameInfo in
        let iconX = IO.read_ui16 frameInfo in
        let iconY = IO.read_ui16 frameInfo in
        let layers = getLayers (IO.read_byte frameInfo) [] in
        getFrames (cnt - 1) [ {x;y; iconX;iconY; layers} :: frames ]

    ]
  in
  let frames = getFrames (IO.read_i32 frameInfo) [] in
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
        imagesByTexture img (countImage - 1) (id +1) (s + iw * ih) [ ((id,dir), Images.sub img sx sy iw ih) :: images ]
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

value convert dir idTex imgs =
  let res_dir = !outdir /// dir in
    (
      match Sys.file_exists res_dir with
      [ False -> Unix.mkdir res_dir 0o755
      | _ -> ()
      ];
      let newTexInfo = res_dir /// "texInfo.dat" in
      let newTexInfo = IO.output_channel (open_out newTexInfo) in
        (
          ignore(Sys.command (Printf.sprintf "cp -f %s/%s/animations.dat %s" !inp_dir dir res_dir));
          ignore(Sys.command (Printf.sprintf "cp -f %s/%s/frames.dat %s" !inp_dir dir res_dir));
          IO.write_ui16 newTexInfo 1;
          write_utf newTexInfo ((string_of_int idTex) ^ ".png");
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
      );
    
value run () =
  let _ = Sys.command (Printf.sprintf "cp -f %s/info_objects.xml %s" !inp_dir !outdir) in
  let images = 
    Array.fold_left begin fun images path -> 
      let () = Printf.printf "try convert %s\n%!" path in 
      match Sys.is_directory (!inp_dir /// path) with
      [ True -> get_images path images
      | _ -> images 
      ]
    end [] (Sys.readdir !inp_dir)
  in
(*  let images = [(0,"pizda", List.fold_left (fun res (_,_,img) ->  res @ img) [] images)] in *)
  let images = List.fast_sort (fun (s1,_,_) (s2,_,_) -> compare s2 s1) images in  
  let textures = List.fold_left begin fun textures  (_,path,images) -> 
    let () = Printf.printf "Layout %s\n%!" path in
    let (placed,_, textures) = MaxRects.layout ~pages:textures path images in
    textures
  end [] images in 
(*  let textures = MaxRects.layout_last_page 1024 textures in *)
  List.iteri begin fun cnt (w,h,imgs,_,_) ->
    let cnt = cnt + !start_num in
    let rgb = Rgba32.make w h {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
    let new_img = Images.Rgba32 rgb in
      (
        Printf.printf "Save %d.png \n%!" cnt;
        List.iter begin fun (path, imgs) -> 
          (
            convert path cnt imgs;
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
        let save_img = !outdir /// (string_of_int cnt) in
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
      ]
      (fun _ -> ())
      "";
    run ();
  );


