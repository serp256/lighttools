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
  let len = BatIO.read_i16 inp in
  BatIO.really_nread inp len;

value write_utf out str=
  (
    BatIO.write_i16 out (String.length str);
    BatIO.nwrite out str;
  );

value inp_dir = "../../mobile-farm/Resources/library";
(*
value inp_dir = "input"; 
 *)
value outdir = "output";

value get_images dir images  =
  let texInfo = inp_dir /// dir /// texInfo in
  let frameInfo =BatFile.open_in (inp_dir /// dir /// "frames.dat") in 
  let rec getLayers cnt layers =
    match cnt with
    [ 0 -> layers 
    | _ ->
        (
          ignore(BatIO.read_byte frameInfo);
          let imgId = BatIO.read_i32 frameInfo in
          let lx = BatIO.read_ui16 frameInfo in
          let ly = BatIO.read_ui16 frameInfo in
          let alpha = BatIO.read_byte frameInfo in
          let flip = 
            match BatIO.read_byte frameInfo with
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
    [ 0 -> frames 
    | _ ->
        let x = BatIO.read_ui16 frameInfo in
        let y = BatIO.read_ui16 frameInfo in
        let iconX = BatIO.read_ui16 frameInfo in
        let iconY = BatIO.read_ui16 frameInfo in
        let layers = getLayers (BatIO.read_byte frameInfo) [] in
        getFrames (cnt - 1) [ {x;y; iconX;iconY; layers} :: frames ]

    ]
  in
  let frames = getFrames (BatIO.read_i32 frameInfo) [] in
  let texInfo = BatFile.open_in texInfo in 
  let countTex = BatIO.read_ui16 texInfo in
  let () = Printf.printf "count textures : %d\n%!" countTex in
  let rec imagesByTexture img countImage id s images =
    match countImage with
    [ 0 -> (id, s, images) 
    | _ ->
        let sx = BatIO.read_ui16 texInfo in
        let sy = BatIO.read_ui16 texInfo in
        let iw = BatIO.read_ui16 texInfo in
        let ih = BatIO.read_ui16 texInfo in
        imagesByTexture img (countImage - 1) (id +1) (s + iw * ih) [ ((id,dir), Images.sub img sx sy iw ih) :: images ]
    ]
  in
  let rec readTexture countTex (id,s,images) =
    match countTex with
    [ 0 -> (s,dir, images)
    | _ ->
        let name = inp_dir /// dir /// read_utf texInfo in
        let () = Printf.printf "Try open %s\n%!" name in
        let texture = Images.load name [] in 
        let count = BatIO.read_ui16 texInfo in
        readTexture (countTex - 1) (imagesByTexture texture count id s images) 
    ]
  in
  let res = [ readTexture countTex (0,0,[]) :: images ] in
    (
      BatIO.close_in texInfo;
      res
    );

value convert dir idTex imgs =
  let dir = outdir /// dir in
    (
      Printf.printf "Convert rects for %s\n%!" dir;
      match Sys.file_exists dir with
      [ False -> Unix.mkdir dir 0o755
      | _ -> ()
      ];
      let newTexInfo = dir /// "texInfo.dat" in
      let newTexInfo = BatFile.open_out ~mode:[`create ] newTexInfo in
        (
          BatIO.write_ui16 newTexInfo 1;
          write_utf newTexInfo (".." /// (string_of_int idTex) ^ ".png");
          BatIO.write_ui16 newTexInfo (List.length imgs);
          BatList.iteri begin fun i (urlId,(sx,sy,isRotate,img)) ->
          (
            let (iw,ih) = Images.size img in
            (
              BatIO.write_ui16 newTexInfo sx;
              BatIO.write_ui16 newTexInfo sy;
              BatIO.write_ui16 newTexInfo iw;
              BatIO.write_ui16 newTexInfo ih;
           (*   BatIO.write_byte newTexInfo (match isRotate with [ True -> 1 | _ -> 0]); *)
            );
          )
          end imgs;
          BatIO.close_out newTexInfo;
        );
      );
    
value run () =
  let images = 
    Array.fold_left begin fun images path -> 
      let () = Printf.printf "try convert %s\n%!" path in 
      match Sys.is_directory (inp_dir /// path) with
      [ True -> get_images path images
      | _ -> images 
      ]
    end [] (Sys.readdir inp_dir)
  in
(*  let images = [(0,"pizda", List.fold_left (fun res (_,_,img) ->  res @ img) [] images)] in *)
  let images = List.fast_sort (fun (s1,_,_) (s2,_,_) -> compare s2 s1) images in  
  let textures = List.fold_left begin fun textures  (_,path,images) -> 
    let (texId, placed, textures) = MaxRects.layout ~pages:textures images in
      (
        convert path texId placed;
        textures;
      )
  end [] images in 
  BatList.iteri begin fun cnt (w,h,imgs,_) ->
    let rgb = Rgba32.make w h {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
    let new_img = Images.Rgba32 rgb in
      (
        Printf.printf "Save %d.png \n%!" cnt;
        BatList.iteri begin fun i (_,(sx,sy,isRotate,img)) ->
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
        Images.save (outdir /// ((string_of_int cnt) ^ ".png")) (Some Images.Png) [] new_img;
      )
  end textures;

(*
value () = convert "an_chicken_ex";
*)

value () = run ();


