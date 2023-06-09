open ExtList;
open ExtString;

value texInfo = "texInfo.dat";
value frames = "frames.dat";

value (///) = Filename.concat;


value read_utf inp = 
  (
    let len = IO.read_i16 inp in
    let () = Printf.printf "read utf len %d\n%!" len in
      (
        IO.really_nread inp len;
      )
  );

value write_utf out str=
  (
    IO.write_i16 out (String.length str);
    IO.nwrite out str;
  );

  value no_anim_prefix = [ "an_"; "bl_"; "dc_"; "mn_" ];

value inp_dir = ref "input"; 
value outdir = ref "output";
value gen_pvr = ref False;
value gen_dxt = ref False;
value degree4 = ref False;
value is_gamma = ref False;
value scale = ref 1.;
value without_cntr = ref False;
value is_android = ref False;
value no_anim = ref False;
value suffix = ref "";

value json_name = ref "";
value get_postfix () = !suffix;
(*
value get_postfix () =
  let sfx = 
    match !is_android with
    [ True -> "andr"
    | _ -> ""
    ]
  in
  match !scale with
  [ 1. -> sfx
  | _ -> "x" ^ (snd ( ExtString.String.replace ~str:(string_of_float !scale) ~sub:"." ~by:"")) ^ sfx
  ];
  *)

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


type rects = 
  {
    rx : int;
    ry : int;
    rw : int;
    rh : int;
  };

type animation =
  {
    a_name : string;
    a_framerate : int32;
    a_rects : DynArray.t rects;
    a_frames : DynArray.t int;
  };

type obj = 
  {
    obj_name : string;
    animations : DynArray.t animation;
  };


value cnt_open = ref 0;


value check_no_anim name = 
  match no_anim_prefix with
  [ [] -> True
  | _ -> (List.exists (fun pref -> (String.starts_with name pref)) no_anim_prefix)
  ];

value readObjs dir = 
  let () = Printf.printf "readObjs %s \n%!" dir in
  let inp =IO.input_channel (open_in (!inp_dir /// dir /// "animations.dat")) in 
  let () = incr cnt_open in
  let cnt_objs = IO.read_ui16 inp in
  let objs = DynArray.make cnt_objs in
    (
      for i = 1 to cnt_objs do
        let name = read_utf inp in
        let cnt_anim = IO.read_ui16 inp in
        let animations = DynArray.make cnt_anim in
          (
            Printf.printf "obj name : %s \n%!" name;
            for j = 1 to cnt_anim do
              let a_name = read_utf inp in
              let a_framerate = IO.read_real_i32 inp in
              let cnt_rects = IO.read_byte inp in
              let rects = DynArray.make cnt_rects in
                (
                  for k = 1 to cnt_rects do
                    let rx = IO.read_i16 inp in
                    let ry = IO.read_i16 inp in
                    let rw = IO.read_i16 inp in
                    let rh = IO.read_i16 inp in
                    DynArray.add rects {rx;ry;rw;rh}
                  done;
                  let cnt_frames = IO.read_ui16 inp in
                  let () = Printf.printf "animation : %s; cnt_rects : %d; cnt_frames : %d \n%!" a_name cnt_rects cnt_frames in
                  let cnt = 
                    match no_anim.val && (check_no_anim dir)  with
                    [ True -> 1 
                    | _ -> cnt_frames 
                    ]
                  in
                  let frames:DynArray.t int = DynArray.make cnt in
                    (
                      for k = 1 to cnt_frames do
                        match !no_anim && (check_no_anim dir) with
                        [ True when k = 1 ->  DynArray.add frames (IO.read_i32 inp)
                        | False -> DynArray.add frames (IO.read_i32 inp)
                        | _ -> ignore(IO.read_i32 inp)
                        ]
                      done;
                      DynArray.add animations {a_name; a_framerate; a_rects = rects; a_frames= frames}
                    )
                )
            done;
            DynArray.add objs {obj_name = name; animations}
          )
      done;
      IO.close_in inp;
			Printf.printf "END READ OBJS \n";
  let () = decr cnt_open in
      objs
    );

type layer =
  {
    texId   : mutable int;
    recId   : mutable int;
    lx      : int;
    ly      : int;
    alpha   : int;
    flip    : int;
    scale   : int32;
  };

type frame = 
  {
    x       : int;
    y       : int;
    iconX   : int;
    iconY   : int;
    layers  : DynArray.t layer;
    pnts    : mutable list (int * int * string);
  };

value read_frames dir =
  let () = Printf.printf "read_frames %s \n%!" dir in
  let fname = !inp_dir /// dir /// "frames.dat" in
  let () = Printf.printf "fname %s\n%!" fname in
  let inp = IO.input_channel (open_in fname) in
  let () = incr cnt_open in
  let cnt_frames = IO.read_i32 inp in
	let _ = Printf.printf "%d" cnt_frames in
  let frames = DynArray.make cnt_frames in
    (
      for i = 1 to cnt_frames do
        let x = IO.read_i16 inp in
        let y = IO.read_i16 inp in
        let iconX = IO.read_i16 inp in
	let _ = Printf.printf "iconX %d" iconX in
        let iconY = IO.read_i16 inp in
	let _ = Printf.printf "iconY %d" iconY in

        let pntsNum = IO.read_byte inp in
        let pnts =

				let _ = Printf.printf "pntsNum %d\n!" pntsNum in
          List.init pntsNum (fun _ ->
            let x = IO.read_i16 inp in
            let y = IO.read_i16 inp in
            let label = read_utf inp in
              (x, y, label)
          )
        in

        let cnt_layers = IO.read_byte inp in
        let () = Printf.printf "cnt_layers %d\n%!" cnt_layers in
        let layers = DynArray.make cnt_layers in
          (
            for j = 1 to cnt_layers do
              let texId = IO.read_byte inp in
              let recId = IO.read_i32 inp in
              let () = Printf.printf "recId %d\n%!" recId in
              let lx = IO.read_i16 inp in
              let ly = IO.read_i16 inp in
              let alpha = IO.read_byte inp in
              let flip = IO.read_byte inp in
              let scale = IO.read_real_i32 inp in
                DynArray.add layers {texId; recId; lx; ly; alpha; flip; scale }
            done;
            DynArray.add frames {x;y;iconX;iconY;layers;pnts}
          )
      done;
      IO.close_in inp;
			Printf.printf "END READ FRAMES";
  let () = decr cnt_open in
      frames
    );

value old_new_rect_ids = Hashtbl.create 0;

value get_images dirs images  =
	let () = Printf.printf "START GET_IMAGES" in 
  let get_images_by_dir dir s images = 
    let () = Printf.printf "get_images_by_dir %s \n"  dir in
    let objs = readObjs dir in
    let frames' = read_frames dir in
    let texInfo = !inp_dir /// dir /// texInfo in
    let texInfo = IO.input_channel (open_in texInfo) in 
  let () = incr cnt_open in
    let objs = readObjs dir in
    let countTex = IO.read_ui16 texInfo in
    let () = Printf.printf "count textures : %d\n%!" countTex in
    let rec imagesByTexture img countImage (texId,oldRectId,newRectId) s images =
      let () = Printf.printf "imagesByTexture countImage:%d; textId:%d oldRectId:%d; newREctId: %d \n%!" countImage texId oldRectId newRectId in
      match countImage with
      [ 0 -> ((texId,oldRectId,newRectId), s, images) 
      | _ ->
          let sx = IO.read_ui16 texInfo in
          let sy = IO.read_ui16 texInfo in
          let iw = IO.read_ui16 texInfo in
          let ih = IO.read_ui16 texInfo in
          let image = Images.sub img sx sy iw ih in
          let image = 
            match !scale with
            [ 1. -> image
            | scale ->
              let srcFname = Filename.temp_file "src" "" in
              let dstFname = Filename.temp_file "dst" ""  in
              (
                Images.save srcFname (Some Images.Png) [] image;
(*
                Printf.printf "convert -resize %d%% -filter catrom %s %s\n" (int_of_float (scale *. 100.)) srcFname dstFname;
*)
                let cnm  = 
                  match scale > 1. with
                  [ True -> Printf.sprintf "convert -resize %d%% -filter catrom %s png32:%s" (int_of_float (scale *. 100.)) srcFname dstFname
                  | _ ->Printf.sprintf "convert -interpolative-resize %d%% -sharpen 0x.1 %s png32:%s" (int_of_float (scale *. 100.)) srcFname dstFname 
                  ]
                in
                if Sys.command (Printf.sprintf "convert -resize %d%% -filter catrom %s png32:%s" (int_of_float (scale *. 100.)) srcFname dstFname) <> 0 then failwith "convert returns non-zero exit code"
                else ();

                let img = Images.load dstFname [] in
                (
                  match img with
                  [ Images.Index8 _ -> Printf.printf("img type: Index8\n")
                  | Images.Rgb24 _ -> Printf.printf("img type: Rgb24\n")
                  | Images.Index16 _ -> Printf.printf("img type: Index16\n")
                  | Images.Rgba32 _ -> Printf.printf("img type: Rgba32\n")
                  | Images.Cmyk32 _ -> Printf.printf("img type: Cmyk32\n")
                  ];

                  Sys.remove srcFname;
                  Sys.remove dstFname;
                  img;
                );
              )
            ]
          in
          let res_img = 
            match !degree4 with
            [ True -> 
                let (iw', ih') = Images.size image in
                let iw = TextureLayout.do_degree4 iw' 
                and ih = TextureLayout.do_degree4 ih' 
                in
                let rgb = Rgba32.make iw ih {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
                let res_img = Images.Rgba32 rgb in
                  ( 
                    Images.blit image 0 0 res_img 0 0 iw' ih';
                    res_img
                  )
            | _ -> image
            ]
          in
            (
              try
                let () = Printf.printf "texId : %d; recId : %d \n%!" texId oldRectId in
                let l_id = ref 0 in
                let frameId = 
                  DynArray.index_of begin fun frame -> 
                    try 
                      let i = DynArray.index_of (fun l -> l.texId = texId && l.recId = oldRectId ) frame.layers in 
                        (
                          l_id.val := i;
                          True
                        )
                    with 
                      [ Not_found -> False ] 
                  end frames'
                in
                let () = Printf.printf "Find obj %s \n%!" dir in
                let obj = DynArray.get objs (DynArray.index_of (fun obj -> obj.obj_name = dir) objs) in
                let () = Printf.printf "Find anim  framed %d \n%!" frameId in
                let anim = DynArray.get obj.animations (DynArray.index_of (fun anim -> try let _ = DynArray.index_of (fun f_id -> f_id = frameId) anim.a_frames in True with [ Not_found -> False ]) obj.animations) in 
                  (
                    Hashtbl.add old_new_rect_ids (dir,oldRectId) newRectId;
                    imagesByTexture img (countImage - 1) (texId,(oldRectId +1),(newRectId+1)) (s + iw * ih) [ ((texId,oldRectId,dir, anim.a_name ^ "__" ^(string_of_int !l_id)), res_img) :: images ]
                  )
              with
                [ Not_found -> imagesByTexture img (countImage - 1) (texId,(oldRectId + 1),newRectId) s images ]
            )
      ]
    in
    let rec readTexture countTex (texId,s,images) =
      let () = Printf.printf "readTexture count : %d; texId : %d  \n" countTex texId in
      match countTex with
      [ 0 -> (s,images)
      | _ ->
          let name = !inp_dir /// dir /// read_utf texInfo in
          let () = Printf.printf "Try open %s\n%!" name in
          let texture = Images.load name [] in 
          let count = IO.read_ui16 texInfo in
          let (id, s, images) = imagesByTexture texture count (texId, 0, 0) s images in
          readTexture (countTex - 1) (texId + 1, s, images)
      ]
    in
    let res = readTexture countTex (0,s,images) in
      (
        IO.close_in texInfo;
  let () = decr cnt_open in
        res
      )
  in
  let res = 
    List.fold_left begin fun (s,imgs) dir ->
      get_images_by_dir dir s imgs 
    end (0, []) dirs  
  in
		(
			Printf.printf "END GET_IMAGES";
  		[ res :: images ];
		);


 

value copyFrames dir =
  let () = Printf.printf "Copy frames  %s \n%!" dir in
  let inp =IO.input_channel (open_in (!inp_dir /// dir /// "frames.dat")) in 
  let () = incr cnt_open in
  let out = IO.output_channel (open_out (!outdir /// dir /// "frames" ^ (get_postfix ()) ^  ".dat")) in
  let cnt_frames = IO.read_i32 inp in
  (
    IO.write_i32 out cnt_frames;
    for i = 1 to cnt_frames do
      (
        let x = IO.read_i16 inp in
        let y = IO.read_i16 inp in
        let ix = IO.read_i16 inp in
        let iy = IO.read_i16 inp in

        let pntsNum = IO.read_byte inp in
        let () = Printf.printf "PNTS COUNT %d\n" pntsNum in
        let pnts =
          List.init pntsNum (fun _ ->
            let x = IO.read_i16 inp in
            let y = IO.read_i16 inp in
            let label = read_utf inp in
              (x, y, label)
          )
        in

        let newx =round (!scale *.  (float x)) in
        let newy =round (!scale *.  (float y)) in
        let newix =round (!scale *.  (float ix)) in
        let newiy =round (!scale *.  (float iy)) in
        let newPnts = List.map (fun (x, y, label) -> (round (!scale *. (float x)), round (!scale *. (float y)), label)) pnts in
          (
            IO.write_i16 out newx;
            IO.write_i16 out newy;
            IO.write_i16 out newix;
            IO.write_i16 out newiy;

            IO.write_byte out pntsNum;
            List.iter (fun (x, y, label) -> ( IO.write_i16 out x; IO.write_i16 out y; write_utf out label; )) newPnts;
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
                  let recID = IO.read_i32 inp in 
                  let recID =
                    match !no_anim with
                    [ True ->
                          try
                            Hashtbl.find old_new_rect_ids (dir, recID) 
                          with
                            [ Not_found -> 0 ] 
                    | _ -> recID 
                    ]
                  in
                    (
                      IO.write_i32 out recID; (*recID *)
                    );
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
                  IO.write_real_i32 out (IO.read_real_i32 inp); (*flip*)
                )
              done;
            )
          );

      )
    done;
    IO.close_in inp;
  let () = decr cnt_open in
    IO.close_out out;
		Printf.printf "END COPY FRAMES";
  );(*}}}*)

value copyAnimations dir =
  let inp =IO.input_channel (open_in (!inp_dir /// dir /// "animations.dat")) in 
  let () = incr cnt_open in
  let out = IO.output_channel (open_out (!outdir /// dir /// "animations" ^ (get_postfix ()) ^ ".dat")) in
  let cnt_objects = IO.read_ui16 inp in
    (
      Printf.printf "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
      Printf.printf "copyAnimations %s : %d \n%!" dir cnt_objects;
      assert (cnt_objects < 256);
      IO.write_ui16 out cnt_objects;
      for _i = 1 to cnt_objects do
        (
          let name = read_utf inp in
            (
              Printf.printf "objname : %S\n%!" name;
              write_utf out name (*objname*);
            );
          let cnt_animations = IO.read_ui16 inp in
          (
            Printf.printf "cnt_animations : %d\n%!" cnt_animations;
            assert (cnt_animations < 256);
            IO.write_ui16 out cnt_animations; 
            for _j = 1 to cnt_animations do
              (
                write_utf out (read_utf inp); (* animname*)
                IO.write_real_i32 out (IO.read_real_i32 inp); (* framerate *) 
                let cnt_rects = IO.read_byte inp in
                  (
                    Printf.printf ">>>>>>>>>>>>>>>>>>>>>>>>>cnt_rects %d\n%!" cnt_rects;

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
                    let cnt = 
                      match no_anim.val && (check_no_anim dir)  with
                      [ True -> 1 
                      | _ -> cnt_frames
                      ]
                    in
                      (
                        IO.write_ui16 out cnt;
                        for i = 1 to cnt_frames do
                          let frame_id = IO.read_i32 inp in
                          match (no_anim.val && (check_no_anim dir),i)  with
                          [ (False,_) | (True,1) -> IO.write_i32 out frame_id
                          | _ -> ()
                          ]
                        done;
                      )
                  );
              )
            done;
          ); 
        )
      done;
      IO.close_in inp;
  let () = decr cnt_open in
      IO.close_out out;
      Printf.printf "END COPY ANIMATIONS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
    );

type texInfo = 
  {
    count : mutable int;
    textures : DynArray.t (string * (DynArray.t (int * int * int * int)));
  };

value readTexInfo fname = 
	let () = Printf.printf "START readTexInfo\n" in 
  let inp = IO.input_channel (open_in fname) in
  let () = incr cnt_open in
    (
      let count = IO.read_byte inp in
      let textures = DynArray.make count in
        (
          for i = 1 to count do 
            (
              let name = read_utf inp in 
              let count_regs = IO.read_ui16 inp in 
              let regions = DynArray.make count_regs in
                (
                  for j = 1 to count_regs do 
                    let sx = IO.read_ui16 inp in
                    let sy = IO.read_ui16 inp in
                    let iw = IO.read_ui16 inp in
                    let ih = IO.read_ui16 inp in
                    DynArray.add regions (sx,sy,iw,ih)
                  done;
                  DynArray.add textures (name, regions)
                )
            )
          done;
          IO.close_in inp;
					Printf.printf "END readTexInfo \n";
  let () = decr cnt_open in
          {count; textures}
        )
    );

value writeTexInfo texInfo fname = 
  let newTexInfo = IO.output_channel (open_out fname) in
    (
      Printf.printf "writeTexInfo %s countTex: %d \n%!" fname texInfo.count;
      IO.write_byte newTexInfo texInfo.count;
      DynArray.iter begin fun (name_tex, regions) ->
        (
          write_utf newTexInfo name_tex;
          IO.write_ui16 newTexInfo (DynArray.length regions);
          DynArray.iter begin fun (sx, sy, iw, ih) ->
            (
              IO.write_ui16 newTexInfo sx;
              IO.write_ui16 newTexInfo sy;
              IO.write_ui16 newTexInfo iw;
              IO.write_ui16 newTexInfo ih;
            )
          end regions;
        )
      end texInfo.textures;
			Printf.printf "END WRITE TEXT INFO\n";
      IO.close_out newTexInfo;
    );


value changed_frames = HSet.create 0;


value changeFrames dir textureId rect_ids = 
  let fname = !outdir /// dir /// "frames" ^ (get_postfix ()) ^  ".dat" in
  let () = Printf.printf "CHANGE FRAMES %S %d %s\n" dir textureId fname in 
  let inp = IO.input_channel (open_in fname) in
  let () = incr cnt_open in
  let cnt_frames = IO.read_i32 inp in
  let frames = DynArray.make cnt_frames in
    (
			for i = 1 to cnt_frames do
        let x = IO.read_i16 inp in
        let y = IO.read_i16 inp in
        let iconX = IO.read_i16 inp in
        let iconY = IO.read_i16 inp in

        let pntsNum = IO.read_byte inp in
				let () = Printf.printf "CPUNT POINTS %d \n" pntsNum in
        let pnts =
          List.init pntsNum (fun _ ->
            let x = IO.read_i16 inp in
            let y = IO.read_i16 inp in
            let label = read_utf inp in
              (x, y, label)
          )
        in

        let cnt_layers = IO.read_byte inp in
        let layers = DynArray.make cnt_layers in
          (
            for j = 1 to cnt_layers do
              let texId = IO.read_byte inp in
              let recId = IO.read_i32 inp in
              let lx = IO.read_i16 inp in
              let ly = IO.read_i16 inp in
              let alpha = IO.read_byte inp in
              let flip = IO.read_byte inp in
              let scale = IO.read_real_i32 inp in
                (
                  (*
                  Printf.printf "old texId : %d; oldRecId : %d \n%!" texId recId;
                  *)
                  let (texId,recId) =
                    match HSet.mem changed_frames (dir,i,j) with
                    [ True -> (texId, recId)
                    | _ -> 
                          try
                            let newId = Hashtbl.find rect_ids (texId,recId) in
                              (
                                (*
                                Printf.printf "newTexId : %d; newRecId : %d\n%!" textureId newId;
                                *)
                                HSet.add changed_frames (dir, i, j);
                                (textureId, newId)
                              )
                          with
                           [ Not_found -> (texId, recId) ]
                    ]
                  in
                  DynArray.add layers {texId; recId; lx; ly; alpha; flip; scale }
                )
            done;
            DynArray.add frames {x;y;iconX;iconY;layers;pnts}
          )
      done;
      IO.close_in inp;
  let () = decr cnt_open in
      Hashtbl.clear rect_ids;
      let out = IO.output_channel (open_out fname) in
        (
          IO.write_i32 out (DynArray.length frames);
          DynArray.iter begin fun {x=x;y=y;iconX=iconX;iconY=iconY;layers=layers;pnts=pnts} -> 
            (
              IO.write_i16 out x;
              IO.write_i16 out y;
              IO.write_i16 out iconX;
              IO.write_i16 out iconY;

              IO.write_byte out (List.length pnts);
              List.iter (fun (x, y, label) -> ( IO.write_i16 out x; IO.write_i16 out y; write_utf out label; )) pnts;

              IO.write_byte out (DynArray.length layers);
              DynArray.iter begin fun {texId=texId;recId=recId;lx=lx;ly=ly;alpha=alpha;flip=flip;scale=scale} ->
                (
                  IO.write_byte out texId;
                  IO.write_i32 out recId;
                  IO.write_i16 out lx;
                  IO.write_i16 out ly;
                  IO.write_byte out alpha;
                  IO.write_byte out flip;
                  IO.write_real_i32 out scale;
                )
              end layers;
            )
          end frames;
          IO.close_out out;
					Printf.printf "END CHANGE Framesnm\n";
        )
    );


(*
value anim_name_hash = HSet.create 0;
*)
value convert idTex  imgs =
let () = Printf.printf "START CONVERT \n" in
  let convert_dir dir imgs = 
		let () = Printf.printf "CONVERT DIR %s\n" dir in 
    let res_dir = !outdir /// dir in
      (
        match Sys.file_exists res_dir with
        [ False -> Unix.mkdir res_dir 0o755
        | _ -> ()
        ];
        let newTexInfo = res_dir /// "texInfo" ^ (get_postfix ()) ^".dat" in
        let regions = DynArray.make (List.length imgs) in
        let rect_ids = Hashtbl.create 0 in
          (
            let j = ref 0 in
            List.iteri begin fun i ((texId,rectId,name,animname),(sx,sy,isRotate,img)) ->
              (
                Printf.printf "regions texId: %d; rectId: %d; name : %s:%s; pos : [%d ; %d]\n%!" texId rectId name animname sx sy;
                let rectId = Hashtbl.find old_new_rect_ids (name,rectId) in
(*
                match !no_anim with
                [ True -> 
                    match HSet.mem anim_name_hash (name,animname) with
                    [ False ->
                        (
                          Hashtbl.add rect_ids (texId,rectId) !j;
                          incr j;
                          HSet.add anim_name_hash (name,animname);
                          let (iw,ih) = Images.size img in
                          DynArray.add regions (sx, sy, iw, ih);
                        )
                    | _ -> ()
                    ]
                | _ -> 
                    *)
                    (
                      Printf.printf "newRectId %d \n%!" rectId;
                      Hashtbl.add rect_ids (texId,rectId) i;
                      let (iw,ih) = Images.size img in
                      DynArray.add regions (sx, sy, iw, ih);
                    )
                    (*
                ]
                *)
              )

            end imgs;
            let newTexture = ((idTex ^ (get_postfix ()) ^ ".png"), regions) in
            let texInfo = 
              match Sys.file_exists newTexInfo with
              [ True -> 
                  let texInfo = readTexInfo newTexInfo in
                    (
                      texInfo.count := texInfo.count + 1;
                      DynArray.add texInfo.textures newTexture;
                      texInfo
                    )
              | _ ->
                  (
                    copyAnimations dir;
                    copyFrames dir;
                    {count=1; textures = DynArray.init 1 (fun _ -> newTexture)};
                  )
              ]
            in
              (
                changeFrames dir (texInfo.count - 1) rect_ids;
                writeTexInfo texInfo newTexInfo;
              )
          );
        ) 
  in
  let images = 
    List.fold_left begin fun res (((_,_,name,_), _) as info) -> 
      let (imgs_by_dir, imgs) = 
        try
          MList.pop_assoc name res 
        with
          [ Not_found -> ([], res) ]
      in
      [  (name , [ info :: imgs_by_dir ]) :: imgs ] 
    end [] imgs 
  in
		(
			
  List.iter (fun (dir, images) -> convert_dir dir (List.rev images)) images;
			Printf.printf "END CONVERT \n";
		);

  
value postfixs = [ "_sh"; "_ex" ];

type pack_info = 
  {
    name : string;
    libs : list string;
    wholly : bool;
  };

value get_packs libs = 
  let libs = ref libs in
  let read_json json =
    match json with
    [ `Assoc packs ->
        (
          List.map begin fun (name,json) -> 
            (
              match json with
              [ `Assoc params ->
                  let wholly = 
                    try
                      match List.assoc "whooly" params with
                      [ `Bool wholly -> wholly
                      | _ -> assert False 
                      ]
                    with
                      [ Not_found -> False ]
                  in
                  let () = Printf.printf "WHOOLY : %B\n%!" wholly in
                  let include_libs = 
                    let ls = List.assoc "include" params in
                    match ls with
                    [ `List ls ->
                        List.fold_left begin fun res reg ->
                          match reg with
                          [ `String reg_str | `Intlit reg_str -> 
                              let reg = Str.regexp reg_str in
                              let (libs_filter,old_libs) = List.partition (fun lib -> Str.string_match reg lib 0) !libs in
                                (
                                  libs.val := old_libs;
                                  libs_filter @ res 
                                )
                          | _ -> assert False
                          ]
                        end [] ls
                    | _ -> assert False
                    ]
                  in
                  let pack_libs = 
                    try
                      let ls = List.assoc "exclude" params in
                      match ls with
                      [ `List ls ->
                        (
                          Printf.printf "include_libs  : [%s]  \n%!" (String.concat "; " include_libs);
                          let libs' =
                            List.fold_left begin fun res reg ->
                              match reg with
                              [ `String reg_str | `Intlit reg_str -> 
                                  let reg = Str.regexp reg_str in
                                  let (exclude_libs,libs_filter) = List.partition (fun lib -> Str.string_match reg lib 0) res in
                                    (
                                      Printf.printf "reg_str : %S; exclude_libs  : [%s]  \n%!" reg_str (String.concat "; " exclude_libs);
                                      libs.val := !libs @ exclude_libs ;
                                      libs_filter 
                                    )
                              | _ -> assert False
                              ]
                            end include_libs ls
                          in
                            (
                              Printf.printf "result libs  : [%s]  \n%!" (String.concat "; " libs');
                              libs'
                            )
                        ) 
                      | _ -> assert False
                      ]
                    with
                      [ Not_found -> include_libs ]
                  in
                    (
                      {name; libs=pack_libs; wholly}
                    )
              | _ -> assert False 
              ]
            ) 
          end packs,
          !libs
        )
    | _ -> assert False 
    ]
  in
  read_json (Ojson.from_file !json_name);

value run_pack pack =
  let () = Printf.printf "RUN PACK %S\n%!" pack.name in 
  let (lib_names, images) = 
    List.fold_left begin fun (libs,images) path -> 
      let () = Printf.printf "try convert %s\n%!" path in 
      match Sys.is_directory (!inp_dir /// path) with
      [ True -> 
          let pstfx = String.sub path ((String.length path) - 3) 3  in
          (
            [ path :: libs ],
            (*
            match List.mem pstfx postfixs with
            [ True ->  images
            | _ ->
                *)
                (*
                let postfixs = if !skip_exp_anim then List.remove postfixs "_ex" else postfixs in
  *)
                let postfixs = [] in
                (*
                  match !no_anim with
                  [ True -> []
                  | _ -> postfixs
                  ]
                in
                *)
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
              (*
            ]
      *)
          )
      | _ -> (libs, images )
      ]
    end ([],[]) pack.libs
  in
(*  let images = [(0,"pizda", List.fold_left (fun res (_,_,img) ->  res @ img) [] images)] in *)
  let images = List.fast_sort (fun (s1,_) (s2,_) -> compare s2 s1) images in  
  let (images:list (bool * (list ((int*int*string * string)* Images.t )))) = 
    match pack.wholly with
    [ True -> 
        [ 
          (True,
            List.fold_left begin fun res (_,images) -> 
              res @ images      
            end [] images
          )
        ]
    | _ ->
        List.map (fun (_, images) -> (True, images)) images
        (*
        match !scale > 1. && !is_android with
        [ True -> 
            List.fold_left begin fun res (_,images) ->
              List.fold_left begin fun (res:list (bool * (list ((int*int*string * string)* Images.t )))) (img:((int*int*string * string)* Images.t ))   ->
                let ((_,_,obj_name,anim_name),_) = img in
                  try
                    let ((imgs_by_anim:(bool * (list ((int*int*string * string)* Images.t )))), other_imgs) =
                      MList.pop_if begin fun (_, (imgs:(list ((int*int*string * string)* Images.t )))) ->
                        match imgs with
                        [ [ ((_,_,obj_name',anim_name'),_) :: _ ] -> obj_name'=obj_name && anim_name' = anim_name 
                        | _ -> False
                        ]
                      end (res:list (bool * (list ((int*int*string * string)* Images.t )))) 
                    in
                    let (_, imgs_by_anim) = imgs_by_anim in
                    [ (True, [img :: imgs_by_anim])  :: other_imgs ]
                  with
                  [ Not_found -> [ (True,[ img ]) :: res ]  ]
              end res images
            end [] images
        | _ -> List.map (fun (_, images) -> (True, images)) images
        ]
        *)
    ]
  in
  let (textures:list (TextureLayout.page (int * int * string *string))) = TextureLayout.layout_min images in
    (
      List.iteri begin fun cnt xyupizda ->
        let w = xyupizda.TextureLayout.width in
        let h = xyupizda.TextureLayout.height in
        let imgs = xyupizda.TextureLayout.placed_images in
      (*  let cnt = cnt + !start_num in *)
        let name_texture = pack.name ^ "_" ^ (string_of_int cnt) in
        let rgb = Rgba32.make w h {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
        let new_img = Images.Rgba32 rgb in
          (
                Printf.printf "Save %s.png \n%!" name_texture;
                convert name_texture imgs;
                List.iter begin fun ((texId, recId,name,animname ) ,(sx,sy,isRotate,img)) ->
                  let () = Printf.printf "INFO texId: %d; recId : %d; name:%s:%s\n%!" texId recId name animname in
                  let (iw,ih) = Images.size img in
                    try
                      (
                        (*
                        Printf.printf "Image size %d %d and pos [%d; %d] to img [%d; %d] \n%!" iw ih sx sy w h;
                        *)
                        Images.blit img 0 0 new_img sx sy iw ih;
                      )
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
            let save_img = !outdir /// name_texture  ^ (get_postfix ()) in
              (
                Printf.printf "Save image %s.png\n%!" save_img;
                match !is_gamma with
                [ True -> 
                    let tmp_name = save_img ^ "_tmp.png" in
                    (
                      Images.save tmp_name (Some Images.Png) [] new_img;
                      let cmd = Printf.sprintf "convert -gamma 1.1 %s %s.png" tmp_name save_img in
                        (
                          Printf.printf "%s\n%!" cmd;
                          match Sys.command cmd with
                          [ 0 -> Sys.remove tmp_name
                          | _ -> failwith "conver gamma return non-zero"
                          ];
                        )
                    )
                | _ -> 
                    Images.save (save_img ^ ".png") (Some Images.Png) [] new_img
                ];
              
                match !gen_pvr with
                [ True -> 
                    (
                      Utils.pvr_png save_img;
                      Utils.gzip_img (save_img ^ ".pvr");
                    )
                | _ -> ()
                ];

                if !gen_dxt then
                (
                  Utils.dxt_png save_img;
                  Utils.gzip_img (save_img ^ ".dds");
                )
                else ();
              );
          )
      end textures;
      Printf.printf "GENRATE COUNTERS\n%!";
     (* 
      match !without_cntr with
      [ False -> 
          List.iter begin fun lib ->
            let scale = 
              match !scale with
              [ 1. -> ""
              | _ -> "-s " ^ (get_postfix ())
              ]
            in
            let cmd = Printf.sprintf "cntrgen %s -l %s -i %s" scale lib !outdir in
              (
                Printf.printf "%s\n%!" cmd;
                match Sys.command cmd with
                [ 0 -> ()
                | _ -> failwith "ERROR GEN COUNTER"
                ]
              )
          end lib_names
      | _ -> ()
      ];
          *)
    );
(*
value () = convert "an_chicken_ex";
*)

value split_pack pack = 
  let (packs, remain_pack) = 
    List.fold_left begin fun (res, pack) pstfx  ->
      let new_name = pack.name ^ pstfx in
      let (new_libs, remain_libs) = List.partition (fun lib -> String.ends_with lib "_ex" || String.ends_with lib "_sh") pack.libs in
      ( [ {name=new_name; libs=new_libs; wholly = pack.wholly} :: res ], {(pack) with libs=remain_libs})
    end  ([], pack) [ "_ex" ]
  in
  packs @ [ remain_pack ];

value run () =
  let _ = Sys.command (Printf.sprintf "cp -f %s/info_objects.xml %s" !inp_dir !outdir) in
  let libs = Array.to_list (Sys.readdir !inp_dir) in
  let (packs, other_libs) = get_packs libs in
    (
      List.iter (fun pack -> Printf.printf "Pack %s : [%s]\n%!" pack.name (String.concat "; " pack.libs)) packs; 
      Printf.printf "Other libs : [%s]\n%!" (String.concat "; " other_libs);
      List.iter (fun pack -> 
        (
          let packs= split_pack pack in
            (
              List.iter (fun pack -> Printf.printf "Pack %s : [%s]\n%!" pack.name (String.concat "; " pack.libs)) packs; 
              List.iter (fun pack -> 
                match pack.libs with
                [ [] -> ()
                | _ -> run_pack pack
                ]
              )packs ;
            )
        )
      ) packs;
      (*
      run_pack {name="main"; libs=other_libs; wholly=False};
      *)
      match !without_cntr with
      [ False -> 
        (*
            let scale = 
              match !scale with
              [ 1. -> ""
              | _ -> "-s " ^ (get_postfix ())
              ]
      *)
            let scale = 
              match get_postfix () with
              [ "" -> ""
              | suffix -> "-s " ^ suffix
              ]
            in
            let cmd = Printf.sprintf "cntrgen %s -i %s" scale !outdir in
              (
                Printf.printf "%s\n%!" cmd;
                match Sys.command cmd with
                [ 0 -> ()
                | _ -> failwith "ERROR GEN COUNTER"
                ]
              )
      | _ -> ()
      ];
    );

value () =
  (
    Gc.set {(Gc.get()) with Gc.max_overhead = 2000000};
    Arg.parse 
      [
        ("-inp",Arg.Set_string inp_dir,"input directory");
        ("-o",Arg.Set_string outdir, "output directory");
        ("-pvr",Arg.Set gen_pvr,"generate pvr file");
        ("-dxt",Arg.Set gen_dxt,"generate dxt file");        
        ("-p",Arg.Set_int TextureLayout.countEmptyPixels, "count Empty pixels between images");
        ("-min",Arg.Set_int TextureLayout.min_size, "Min size texture");
        ("-max",Arg.Set_int TextureLayout.max_size, "Max size texture");
        ("-scale", Arg.Set_float scale, "Scale factor");
        ("-degree4", Arg.Set degree4, "Use degree 4 rects");
        ("-without-cntr", Arg.Set without_cntr, "Not generate counters");
        ("-android", Arg.Set is_android, "Textures for android");
        ("-no-anim", Arg.Set no_anim, "Skip expansion animations");
        ("-suffix", Arg.Set_string suffix, "add suffix to library name");
        ("-gamma", Arg.Set is_gamma, "add conver -gamma 1.1 call for result image");
      ]
      (fun name -> json_name.val := name)
      "";
      TextureLayout.countEmptyPixels.val := 0;
      TextureLayout.rotate.val := False;

(*
      if !scale >= 2. then TextureLayout.min_size.val := 512
      else ();

    if !scale >= 2. then TextureLayout.max_size.val := 4096
    else ();
*)
    run ();
  );


