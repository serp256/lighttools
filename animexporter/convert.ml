value texInfo = "texInfo.dat";
value frames = "frames.dat";

value (///) = Filename.concat;

type layer =
  {
    imgId   : int;
    x       : int;
    y       : int;
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
(*value inp_dir = "input"; *)
value outdir = "output";

value get_images dir images  =
  let texInfo = inp_dir /// dir /// texInfo in
  let () = Printf.printf "try open %s \n%!" texInfo in
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
        imagesByTexture img (countImage - 1) (id +1) (s + iw * ih) [ (id, Images.sub img sx sy iw ih) :: images ]
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

value convert dir textures images =
    (
      Printf.printf "find rects for %s\n%!" dir;
      let textures = MaxRects.layout ~pages:textures images in
      let dir = outdir /// dir in
        (
          match Sys.file_exists dir with
          [ False -> Unix.mkdir dir 0o755
          | _ -> ()
          ];
          let newTexInfo = dir /// "textInfo.dat" in
          let newTexInfo = BatFile.open_out ~mode:[`create ] newTexInfo in
            (
              BatIO.write_ui16 newTexInfo (List.length textures);
              BatList.iteri begin fun cnt (w,h,imgs,_) ->
                let () = write_utf newTexInfo ((string_of_int cnt) ^ ".png") in
                let () = BatIO.write_ui16 newTexInfo (List.length imgs) in
                  (
                    BatList.iteri begin fun i (urlId,(sx,sy,isRotate,img)) ->
                    (
                      let (iw,ih) = Images.size img in
                      (
                        BatIO.write_ui16 newTexInfo sx;
                        BatIO.write_ui16 newTexInfo sy;
                        BatIO.write_ui16 newTexInfo iw;
                        BatIO.write_ui16 newTexInfo ih;
                        BatIO.write_byte newTexInfo (match isRotate with [ True -> 1 | _ -> 0]);
                      );
                    )
                    end imgs;
                  )
              end textures;
              BatIO.close_out newTexInfo;
            );
            textures
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
  let textures = List.fold_left (fun textures  (_,path,images) -> convert path textures images) [] images in 
  BatList.iteri begin fun cnt (w,h,imgs,_) ->
    let rgb = Rgba32.make w h {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
    let new_img = Images.Rgba32 rgb in
      (
        BatList.iteri begin fun i (urlId,(sx,sy,isRotate,img)) ->
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
        end (List.rev imgs);
        Images.save (outdir /// ((string_of_int cnt) ^ ".png")) (Some Images.Png) [] new_img;
      )
  end textures;

(*
value () = convert "an_chicken_ex";
*)

value () = run ();


