open Arg;

value indir = ref ".";
value (//) = Filename.concat;

parse [ ("-i", Set_string indir, "input dir") ] (fun _ -> ()) "";

value read_utf inp = 
  let len = IO.read_i16 inp in
  	IO.really_nread inp len;

value write_utf out str =
(
  IO.write_i16 out (String.length str);
  IO.nwrite out str;
);

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

type rect = {
  rx:int;
  ry:int;
  rw:int;
  rh:int;
};

value rectToString rect = Printf.sprintf "rect(x:%d; y:%d; w:%d; h:%d)" rect.rx rect.ry rect.rw rect.rh; 

type layer = {
  texId:int;
  recId:int;
  lx:int;
  ly:int;
  alpha:int;
  flip:int;
};

value layerToString layer = Printf.sprintf "layer(texId:%d; recId:%d; lx:%d; ly:%d; alpha:%d; flip:%d)" layer.texId layer.recId layer.lx layer.ly layer.alpha layer.flip;

type frame = {
  fx:int;
  fy:int;
  ix:int;
  iy:int;
  lnum:int;
  layers:list layer;
};

value frameToString frame = Printf.sprintf "frame(fx:%d; fy:%d; ix:%d; iy:%d; lnum:%d)" frame.fx frame.fy frame.ix frame.iy frame.lnum;

type anim = {
  aname:string;
  frameRate:float;
  fnum:int;
  rnum:int;
  frames:list int;
  rects:list rect;
  ranges:DynArray.t (list int);
};

value animToString anim =
  let frames = String.concat "," (List.map (fun frame -> string_of_int frame) anim.frames) in
    Printf.sprintf "anim(aname:%s; frameRate:%f; fnum:%d; rnum:%d; frames:[ %s ])" anim.aname anim.frameRate anim.fnum anim.rnum frames;

type obj = {
  oname:string;
  anum:int;  
  anims:list anim;
};

value objToString obj = Printf.sprintf "obj(oname:%s; anum:%d)" obj.oname obj.anum;

type region = {
  regx:int;
  regy:int;
  regw:int;
  regh:int;
};

value regionToString reg = Printf.sprintf "region(regx:%d; regy:%d; regw:%d; regh:%d)" reg.regx reg.regy reg.regw reg.regh;

value readTexInfo lib =
  let inp = IO.input_channel (open_in (!indir // lib // "texInfo.dat")) in
  let texNum = IO.read_i16 inp in
  let regions = DynArray.make texNum in
  (
    for i = 1 to texNum do {
      let texFname = read_utf inp in
      let regNum = IO.read_i16 inp in
      let texRegions = DynArray.make regNum in
      (
        for j = 1 to regNum do {
          let regx = IO.read_i16 inp
          and regy = IO.read_i16 inp
          and regw = IO.read_i16 inp
          and regh = IO.read_i16 inp in
            DynArray.add texRegions { regx; regy; regw; regh };
        };

        DynArray.add regions (texFname, texRegions);
      );
    };

    IO.close_in inp;
    regions;
  );

value readFrames lib =
  let inp = IO.input_channel (open_in (!indir // lib // "frames.dat")) in 
    let cnt_frames = IO.read_i32 inp in
    let frames = DynArray.make cnt_frames in
    (
      for i = 1 to cnt_frames do {
        let fx = IO.read_i16 inp in
        let fy = IO.read_i16 inp in
        let ix = IO.read_i16 inp in
        let iy = IO.read_i16 inp in
        let lnum = IO.read_byte inp
        and layers = ref [] in
        (
          for it = 1 to lnum do {
            let texId = IO.read_byte inp
            and recId = IO.read_i32 inp
            and lx = IO.read_i16 inp
            and ly = IO.read_i16 inp
            and alpha = IO.read_byte inp
            and flip = IO.read_byte inp in
              layers.val := [ { texId; recId; lx; ly; alpha; flip } :: !layers ];
          };

          let layers = List.rev !layers in
            DynArray.add frames { fx; fy; ix; iy; lnum; layers };
        );
      };

      IO.close_in inp;
      frames;
    );

value readObjs lib =
  let objs = ref [] in
    let inp = IO.input_channel (open_in (!indir // lib // "animations.dat")) in 
    let cnt_objects = IO.read_ui16 inp in
      (
        for _i = 1 to cnt_objects do {
          let anims = ref [] in 
          (
            let oname = read_utf inp  (*objname*)
            and anum = IO.read_ui16 inp in
            (
              for _j = 1 to anum do {
                let rects = ref []
                and frames = ref []
                and aname = read_utf inp (* animname*)
                and frameRate = Int32.to_float (IO.read_real_i32 inp) in (* framerate *)
                (
                  let rnum = IO.read_byte inp in
                  (
                    for i = 1 to rnum do {
                      rects.val := [ { rx = IO.read_i16 inp; ry = IO.read_i16 inp; rw = IO.read_i16 inp; rh = IO.read_i16 inp } :: !rects ];
                    };

                    let colsNum = IO.read_i16 inp in
                      for i = 1 to colsNum do {
                        let rangesNum = IO.read_i16 inp in
                          for j = 1 to rangesNum do {
                            ignore(IO.read_i32 inp);  
                          };                          
                      };

                    let fnum = IO.read_ui16 inp in
                    (
                      for i = 1 to fnum do {
                        frames.val := [ (IO.read_i32 inp) :: !frames ];
                      };

                      let frames = List.rev !frames
                      and rects = List.rev !rects in
                        anims.val := [ { aname; frameRate; fnum; rnum; frames; rects; ranges = DynArray.make 0 } :: !anims ];
                    );
                  );
                );                
              };

              let anims = List.rev !anims in
                objs.val := [ { oname; anum; anims } :: !objs ];
            );
          );          
        };

        IO.close_in inp;
        List.rev !objs;
      );

value writeObjs lib objs =  
  let out = IO.output_channel (open_out (!indir // lib // "animations.dat")) in
  (
    IO.write_ui16 out (List.length objs);

    List.iter (fun obj -> (
      Printf.printf "writing obj %s\n%!" obj.oname;
      write_utf out obj.oname;
      IO.write_ui16 out obj.anum;

      List.iter (fun anim -> (
        write_utf out anim.aname;
        IO.write_real_i32 out (Int32.of_float anim.frameRate);

        IO.write_byte out anim.rnum;
        List.iter (fun rect -> (
          IO.write_i16 out rect.rx;
          IO.write_i16 out rect.ry;
          IO.write_i16 out rect.rw;
          IO.write_i16 out rect.rh;
        )) anim.rects;

        IO.write_ui16 out (DynArray.length anim.ranges);
        DynArray.iter (fun colRanges -> (
          IO.write_ui16 out (List.length colRanges);
          List.iter (fun range -> IO.write_i32 out range) colRanges;
        )) anim.ranges;

        IO.write_ui16 out anim.fnum;
        List.iter (fun frame -> IO.write_i32 out frame) anim.frames;
      )) obj.anims
    )) objs;

    IO.close_out out;
  );

value alphaThreshold = 0;
value rangeMinSize = 10;
value lineEstimateThreshold = 3.;

value estimate k b pnts =
  if pnts <> [] then
    (List.fold_left (fun sum (x, y) -> sum +. sqrt ((y -. k *. x -. b) ** 2.)) 0. pnts) /. (float_of_int (List.length pnts))
  else 0.;

value imgPos = ref 0;

value genTmap regions frames anim =
  if anim.aname <> "middle_step_1_1" then ()
  else
  let frame = DynArray.get frames (List.hd anim.frames) in
  let (x, y, w, h) =
    List.fold_left (fun (x, y, w, h) layer ->
      let (_, regions) = DynArray.get regions layer.texId in
      let region = DynArray.get regions layer.recId in
        (min x (frame.fx + layer.lx), min y (frame.fy + layer.ly), max w (frame.fx + layer.lx + region.regw), max h (frame.fy + layer.ly + region.regh))
    ) (0, 0, 0, 0) frame.layers
  in
  let texImgs = Hashtbl.create 0 in
  let getTexImg texFname = try Hashtbl.find texImgs texFname with [ Not_found -> let texImg = Images.load texFname [] in ( Hashtbl.add texImgs texFname texImg; texImg; ) ] in
  let frameImg = Rgba32.(make (w - x + 4) (h - y + 4) Color.({ Rgba.color = { Rgb.r = 0xff; g = 0xff; b = 0xff }; alpha = 0 })) in (* width and height more on 4 pixels cause it helps make contour without breaks, where non-transparent pixels of original image are border *)
  (

    List.iter (fun layer ->
      let (texFname, regions) = DynArray.get regions layer.texId in
      let region = DynArray.get regions layer.recId in
      let texImg = getTexImg texFname in
      (
        match texImg with
        [ Images.Rgba32 texImg -> Rgba32.map (fun colorA colorB -> Color.Rgba.merge colorA colorB) texImg region.regx region.regy frameImg (frame.fx + layer.lx - x + 2) (frame.fy + layer.ly - y + 2) region.regw region.regh (* x and y more on 2 pixels cause width and height are more on 4 pixels, see previous comment*)
        | _ -> assert False
        ];
      );                
    ) frame.layers;
    Hashtbl.iter (fun _ texImg -> Images.destroy texImg) texImgs;

    let w = frameImg.Rgba32.width
    and h = frameImg.Rgba32.height in
    let binImg = Array.make_matrix (w - 1) (h - 1) 0 in
    let img = Rgb24.make w h { Color.Rgb.r = 0xff; g = 0xff; b = 0xff; } in
    (
      for i = 0 to w - 1 do
        for j = 0 to h - 1 do
          let c = Rgba32.get frameImg i j in
            Color.Rgba.(Color.Rgb.(Rgb24.set img i j { r = c.color.r; g = c.color.g; b = c.color.b }))
        done;
      done;

      Graphic_image.draw_image (Images.Rgb24 img) !imgPos (600 - h);
      Rgb24.destroy img;      

      let applyThreshold col row =
        Color.Rgba.(
          let c1 = (Rgba32.get frameImg col row).alpha
          and c2 = (Rgba32.get frameImg (col + 1) row).alpha
          and c3 = (Rgba32.get frameImg col (row + 1)).alpha
          and c4 = (Rgba32.get frameImg (col + 1) (row + 1)).alpha in
            if (c1 + c2 + c3 + c4) / 4 <= alphaThreshold then 0 else 1
        )
      in      
        for i = 0 to w - 2 do
          for j = 0 to h - 2 do
            binImg.(i).(j) := applyThreshold i j;
          done;
        done;
      
      let rec fill col row =
        (
          testCell (col + 1) row;
          testCell col (row + 1);
          testCell (col - 1) row;
          testCell col (row - 1);
        )        
      and testCell col row = if 0 <= col && col < (w - 1) && 0 <= row && row < (h - 1) && binImg.(col).(row) = 0 then ( binImg.(col).(row) := 2; fill col row; ) else () in
      (
        for i = 0 to w - 2 do testCell i 0; done;
        for i = 0 to w - 2 do testCell i (h - 2); done;
        for i = 0 to h - 2 do testCell 0 i; done;
        for i = 0 to h - 2 do testCell (w - 2) i; done;
      );

      for i = 0 to w - 2 do
        for j = 0 to h - 2 do
          if binImg.(i).(j) = 0 then binImg.(i).(j) := 1 else ()
        done;
      done;

(*       for j = 0 to h - 2 do
        let () =
          for i = 0 to w - 2 do
            Printf.printf "%d%!" binImg.(i).(j);
          done
        in
          Printf.printf "\n%!";
      done; *)

      Graphics.set_line_width 1;
      Graphics.set_color 0xff0000;

      let contour = ref [] in
      (
        for j = 0 to h - 3 do
          for i = 0  to w - 3 do
            let cellType = if binImg.(i).(j) = 1 then 0x8 else 0 in
            let cellType = if binImg.(i + 1).(j) = 1 then cellType lor 0x4 else cellType in
            let cellType = if binImg.(i + 1).(j + 1) = 1 then cellType lor 0x2 else cellType in
            let cellType = if binImg.(i).(j + 1) = 1 then cellType lor 0x1 else cellType in
            (
(*             let j = 600 - j in
            let i = i + !imgPos in *)
(*               match cellType with
              [ 0 | 15 -> ()
              | 1 | 14 -> Graphics.draw_poly_line [| (i, j - 1); (i + 1, j - 2) |]
              | 2 | 13 -> Graphics.draw_poly_line [| (i + 1, j - 2); (i + 2, j - 1) |]
              | 3 | 12 -> Graphics.draw_poly_line [| (i, j - 1); (i + 2, j - 1) |]
              | 4 | 11 -> Graphics.draw_poly_line [| (i + 1, j); (i + 2, j - 1) |]
              | 6 | 9 -> Graphics.draw_poly_line [| (i + 1, j); (i + 1, j - 2) |]
              | 7 | 8 -> Graphics.draw_poly_line [| (i, j - 1); (i + 1, j) |]
              | 5 -> ( Graphics.draw_poly_line [| (i, j - 1); (i + 1, j) |]; Graphics.draw_poly_line [| (i + 1, j - 2); (i + 2, j - 1) |]; )
              | 10 -> ( Graphics.draw_poly_line [| (i, j - 1); (i + 1, j - 2) |]; Graphics.draw_poly_line [| (i + 1, j); (i + 2, j - 1) |]; )
              | _ -> assert False
              ] *)

              match cellType with
              [ 0 | 15 -> ()
              | 1 | 14 -> Graphics.draw_poly_line [| (i, j + 1); (i + 1, j + 2) |]
              | 2 | 13 -> Graphics.draw_poly_line [| (i + 1, j + 2); (i + 2, j + 1) |]
              | 3 | 12 -> Graphics.draw_poly_line [| (i, j + 1); (i + 2, j + 1) |]
              | 4 | 11 -> Graphics.draw_poly_line [| (i + 1, j); (i + 2, j + 1) |]
              | 6 | 9 -> Graphics.draw_poly_line [| (i + 1, j); (i + 1, j + 2) |]
              | 7 | 8 -> Graphics.draw_poly_line [| (i, j + 1); (i + 1, j) |]
              | 5 -> ( Graphics.draw_poly_line [| (i, j + 1); (i + 1, j) |]; Graphics.draw_poly_line [| (i + 1, j + 2); (i + 2, j + 1) |]; )
              | 10 -> ( Graphics.draw_poly_line [| (i, j + 1); (i + 1, j + 2) |]; Graphics.draw_poly_line [| (i + 1, j); (i + 2, j + 1) |]; )
              | _ -> assert False
              ];

              match cellType with
              [ 0 | 15 -> ()
              | 1 | 14 -> contour.val := [ (i, j + 1, i + 1, j + 2) :: !contour ]
              | 2 | 13 -> contour.val := [ (i + 1, j, i + 2, j + 1) :: !contour ]
              | 3 | 12 -> contour.val := [ (i, j + 1, i + 2, j + 1) :: !contour ]
              | 4 | 11 -> contour.val := [ (i + 1, j, i + 2, j + 1) :: !contour ]
              | 6 | 9 -> contour.val := [ (i + 1, j, i + 1, j + 2) :: !contour ]
              | 7 | 8 -> contour.val := [ (i, j + 1, i + 1, j) :: !contour ]
              | 5 -> ( contour.val := [ (i, j + 1, i + 1, j) :: !contour ]; contour.val := [ (i + 1, j + 2, i + 2, j + 1) :: !contour ]; )
              | 10 -> ( contour.val := [ (i, j + 1, i + 1, j + 2) :: !contour ]; contour.val := [ (i + 1, j, i + 2, j + 1) :: !contour ]; )
              | _ -> assert False
              ];
            )
          done;
        done;

        Graphics.set_color 0x00ff00;
        List.iter (fun (x1, y1, x2, y2) -> Graphics.draw_poly_line [| (w + x1, y1); (w + x2, y2) |]) (List.rev !contour);
      );

      imgPos.val := !imgPos + w + 30;
    );

    Rgba32.destroy frameImg;        
  );





(*     let frameImg =
      let img = Rgba32.(make h w Color.({ Rgba.color = { Rgb.r = 0xff; g = 0xff; b = 0xff }; alpha = 0 })) in
      (
        for i = 0 to w - 1 do
          for j = 0 to h - 1 do
            let c = Rgba32.get frameImg i j in
              Rgba32.set img j i c
              (* Color.Rgba.(Color.Rgb.(Rgb24.set img j i { r = c.color.r; g = c.color.g; b = c.color.b })) *)
          done;
        done;
        img;
      )
    in
    let (w, h) = (h, w) in
 *)    
(*     let rec scanSide img w h col row colInc rowInc =
      if row < 0 || col < 0 then None
      else if row = h || col = w then None
      else
        let clr = Rgba32.get frameImg col row in
          if clr.Color.Rgba.alpha <= alphaThreshold then scanSide img w h (col + colInc) (row + rowInc) colInc rowInc
          else Some (float_of_int col, float_of_int row)
    in
      let scanSide = scanSide frameImg w h
      and points = ref [] in
      ( *)
        (* let points = ExtList.List.unique !points in *)
        (* let points = [ (50., 50.); (60., 20.); (00., 10.); (30., 10.); (30., 40.); (40., 30.); (40., 00.) ] in *)
   (*      let points = List.sort compare !points in
        let (colO, rowO) = List.hd points in
        let () = Printf.printf "%.0f %.0f\n" colO rowO in
        let points =
          List.sort (fun (colA, rowA) (colB, rowB) ->
            let est = (rowO -. rowA) *. colB +. (colA -. colO) *. rowB +. (colO *. rowA -. colA *. rowO) in
              if est < 0. then 1
              else if est > 0. then ~-1
              else 0
          ) (List.tl points)
        in
        let () = Printf.printf "%d %s\n" (List.length points) (String.concat " " (List.map (fun (col, row) -> Printf.sprintf "(%.0f,%.0f)" col row) points)) in
(*         let points =
          List.fold_left (fun pnts pnt ->
            match pnts with
            [ [ last :: _ ] ->
              let () = Printf.printf "(%.0f, %.0f), (%.0f, %.0f): %f\n" (fst pnt) (snd pnt) (fst last) (snd last) (sqrt ((fst pnt -. fst last) ** 2. +. (snd pnt -. snd last) ** 2.)) in
                if sqrt ((fst pnt -. fst last) ** 2. +. (snd pnt -. snd last) ** 2.) < 30. then [ pnt :: pnts ] else pnts
            | _ -> [ pnt :: pnts ]
            ]
          ) [] points in *)
        let points = [ (colO, rowO) :: points ] in
 *)
          (* Printf.printf "%d %s\n" (List.length points) (String.concat " " (List.map (fun (col, row) -> Printf.sprintf "(%.0f,%.0f)" col row) points)); *)



        (* let points = List.sort (fun (colA, rowA) (colB, rowB) -> let retval = compare colA colB in if retval <> 0 then retval else ~-1 * compare rowA rowB) !points in *)
        (* let points = ExtList.List.unique ~cmp:(fun (colA, _) (colB, _) -> colA = colB) points in *)


(*         for col = 0 to w - 1 do
          match scanSide col (h - 1) 0 ~-1 with
          [ Some pnt -> points.val := [ pnt :: !points ]
          | _ -> ()
          ];
        done;

        for col = w - 1 downto 0 do
          match scanSide col 0 0 1 with
          [ Some pnt -> points.val := [ pnt :: !points ]
          | _ -> ()
          ];
        done;

        let points = !points in
        let fstPnt = List.hd points in
        let (contour, _) = 
          List.fold_left (fun (contour, approxPnts) (col, row) ->
            let (_col, _row) = List.hd contour in
            let k = (row -. _row) /. (col -. _col) in
            let b = row -. col *. k in
              let est = estimate k b approxPnts in
              (* let () = Printf.printf "est %f\n" est in *)
                if est < lineEstimateThreshold then
                  (contour, [ (col, row) :: approxPnts ])
                else
                  ([ (List.hd approxPnts) :: contour ], [])
          ) ([ fstPnt ], []) (List.tl points)        
        in
        (* let contour = !points in *)
        (
          Printf.printf "%d %s\n" (List.length contour) (String.concat " " (List.map (fun (col, row) -> Printf.sprintf "(%.0f,%.0f)" col row) contour));
          
          let img = Rgb24.make w h { Color.Rgb.r = 0xff; g = 0xff; b = 0xff; } in
          (
            for i = 0 to w - 1 do
              for j = 0 to h - 1 do
                let c = Rgba32.get frameImg i j in
                  Color.Rgba.(Color.Rgb.(Rgb24.set img i j { r = c.color.r; g = c.color.g; b = c.color.b }))
              done;
            done;

            Graphic_image.draw_image (Images.Rgb24 img) !imgPos (600 - h);

            Graphics.set_line_width 1;
            Graphics.set_color 0xff0000;
            Graphics.draw_poly (Array.of_list (List.map (fun (col, row) -> (int_of_float col + !imgPos, 600 - int_of_float row)) contour));

            (* imgPos.val := !imgPos + w + 30; *)
            Rgb24.destroy img;
          );
        ); *)


Graphics.open_graph "";
Graphics.set_window_title "xyu";
Graphics.resize_window 1800 600;

Array.iter (fun fname ->
  if fname <> "pizda" && Sys.is_directory fname then
    let objs = readObjs fname
    and frames = readFrames fname
    and regions = readTexInfo fname in
    (
      List.iter (fun obj ->
        let () = Printf.printf "processing object %s...\n%!" obj.oname in
          if obj.oname = "tr_birch" then
            List.iter (fun anim -> let () = Printf.printf "\tprocessing animation %s\n%!" anim.aname in genTmap regions frames anim) obj.anims
          else ()
      ) objs;

      writeObjs fname objs;
    )
  else ()
) (Sys.readdir !indir);

ignore(Graphics.wait_next_event [Graphics.Key_pressed]);
Graphics.close_graph ();