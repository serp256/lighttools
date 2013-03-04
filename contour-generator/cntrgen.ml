open Arg;

value (//) = Filename.concat;

value indir = ref ".";
value graph = ref False;
value libName = ref "";
value suffix = ref "";
value readRects = ref True;

Arg.parse [
  ("-i", Set_string indir, "input dir");
  ("-v", Set graph, "show visualisation");
  ("-l", Set_string libName, "generate contour for give library");
  ("-s", Set_string suffix, "search for files like 'animations<suffix>.dat', 'texInfo<suffix>.dat' and so on, where suffix -- value, passed through this option");
  ("-skip-rects", Clear readRects, "skip reading rects, read contour instead (for files, which were processed by cntrgen")
] (fun _ -> ()) "contour generator";

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
  contour:mutable list (int * int);
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
  let inp = IO.input_channel (open_in (!indir // lib // ("texInfo" ^ !suffix ^ ".dat"))) in
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
  let inp = IO.input_channel (open_in (!indir // lib // ("frames" ^ !suffix ^ ".dat"))) in 
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
    let inp = IO.input_channel (open_in (!indir // lib // ("animations" ^ !suffix ^ ".dat"))) in 
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
                    if !readRects then
                      for i = 1 to rnum do {
                        rects.val := [ { rx = IO.read_i16 inp; ry = IO.read_i16 inp; rw = IO.read_i16 inp; rh = IO.read_i16 inp } :: !rects ];
                      }
                    else
                      for i = 1 to rnum do
                        ignore(IO.read_i32 inp);
                      done;

                    let fnum = IO.read_ui16 inp in
                    (
                      for i = 1 to fnum do {
                        frames.val := [ (IO.read_i32 inp) :: !frames ];
                      };

                      let frames = List.rev !frames
                      and rects = List.rev !rects in
                        anims.val := [ { aname; frameRate; fnum; rnum; frames; rects; contour = [] } :: !anims ];
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
  let out = IO.output_channel (open_out (!indir // lib // ("animations" ^ !suffix ^ ".dat"))) in
  (
    IO.write_ui16 out (List.length objs);

    List.iter (fun obj -> (
      Printf.printf "writing obj %s\n%!" obj.oname;
      write_utf out obj.oname;
      IO.write_ui16 out obj.anum;

      List.iter (fun anim -> (
        write_utf out anim.aname;
        IO.write_real_i32 out (Int32.of_float anim.frameRate);

        IO.write_byte out (List.length anim.contour);
        List.iter (fun (x, y) -> IO.write_i32 out ((x lsl 16) lor (y land 0xffff))) anim.contour;

        IO.write_ui16 out anim.fnum;
        List.iter (fun frame -> IO.write_i32 out frame) anim.frames;
      )) obj.anims
    )) objs;

    IO.close_out out;
  );

value alphaThreshold = 0;
value lineEstimateThreshold = 5.;

value estimateLine k b pnts =
  if pnts <> [] then
    (List.fold_left (fun sum (x, y) -> sum +. sqrt ((y -. k *. x -. b) ** 2.)) 0. pnts) /. (float_of_int (List.length pnts))
  else 0.;

value imgPos = ref 0;

type contourSement = {
  endA: mutable (int * int);
  endB: mutable (int * int);
  points: mutable list (int * int);
};

(* generate contour, steps:
 * 1) generate first frame image
 * 2) find contour segments using "marching squares" algorithm (http://en.wikipedia.org/wiki/Marching_squares)
 * 3) making polygon from segments
 * 4) approximating this polygon by streight lines to minimize vertexes number
 *)

value genContour regions frames anim =
  let frame = DynArray.get frames (List.hd anim.frames) in
  let (x, y, w, h) =
    List.fold_left (fun (x, y, w, h) layer ->
      let (_, regions) = DynArray.get regions layer.texId in
      let region = DynArray.get regions layer.recId in
        (min x layer.lx, min y layer.ly, max w (layer.lx + region.regw), max h (layer.ly + region.regh))
    ) (max_int, max_int, 0, 0) frame.layers
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
        [ Images.Rgba32 texImg -> Rgba32.map (fun colorA colorB -> Color.Rgba.merge colorA colorB) texImg region.regx region.regy frameImg (layer.lx - x + 2) (layer.ly - y + 2) region.regw region.regh (* inc x and y by 2 pixels cause width and height are more on 4 pixels, see previous comment*)
        | _ -> assert False
        ];
      );                
    ) frame.layers;
    Hashtbl.iter (fun _ texImg -> Images.destroy texImg) texImgs;

    let w = frameImg.Rgba32.width
    and h = frameImg.Rgba32.height in
    let binImg = Array.make_matrix (w - 1) (h - 1) 0 in    
    (

      if !graph then
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
        )
      else ();

      (* making binary image. in this implementation, "pixel" means block 2x2 pixels *)
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
      
      (* filling inner object holes, we need only transparent areas, which borders on frame border *)

      (* filling needed areas by 2 *)
      (* Printf.printf "w, h %d %d\n%!" w h; *)


      let fill col row colIncr rowIncr =
        while 0 <= !col && !col < (w - 1) && 0 <= !row && !row < (h - 1) && binImg.(!col).(!row) <> 1 do
          binImg.(!col).(!row) := 2;
          rowIncr row;
          colIncr col;
        done
      in
      (
        for col = 0 to w - 2 do
          fill (ref col) (ref 0) (fun _ -> ()) incr;
          fill (ref col) (ref (h - 2)) (fun _ -> ()) decr;
        done;

        for row = 0 to h - 2 do
          fill (ref 0) (ref row) incr (fun _ -> ());
          fill (ref (w - 2)) (ref row) decr (fun _ -> ());
        done;
      );

(*       let rec fill col row =
        (
          let col = col + 1 in if 0 <= col && col < (w - 1) && 0 <= row && row < (h - 1) && binImg.(col).(row) = 0 then ( binImg.(col).(row) := 2; fill col row; ) else ();
          let row = row + 1 in if 0 <= col && col < (w - 1) && 0 <= row && row < (h - 1) && binImg.(col).(row) = 0 then ( binImg.(col).(row) := 2; fill col row; ) else ();
          let col = col - 1 in if 0 <= col && col < (w - 1) && 0 <= row && row < (h - 1) && binImg.(col).(row) = 0 then ( binImg.(col).(row) := 2; fill col row; ) else ();
          let row = row - 1 in if 0 <= col && col < (w - 1) && 0 <= row && row < (h - 1) && binImg.(col).(row) = 0 then ( binImg.(col).(row) := 2; fill col row; ) else ();
        )
      in
      (
        for i = 0 to w - 2 do fill i 0; fill i (h - 2); done;
        for i = 0 to h - 2 do fill 0 i; fill (w - 2) i; done;
      ); *)

(*       for j = 0 to h - 2 do
        for i = 0 to w - 2 do
          Printf.printf "%d" binImg.(i).(j);
        done;

        Printf.printf "\n";
      done;  *)     

      (* filling rest transparent areas with 1 *)
      for i = 0 to w - 2 do
        for j = 0 to h - 2 do
          if binImg.(i).(j) = 0 then binImg.(i).(j) := 1 else ()
        done;
      done;

      (* calculating contour segments by iterating "contouring grid" (each cell represented by 2x2 pixels, in this implementation "pixel" means block 2x2 of real pixels, so contouring cell is block of 3x3 pixels ) *)
      let segments = ref [] in
      (
        for j = 0 to h - 3 do
          for i = 0  to w - 3 do
            let cellType = if binImg.(i).(j) = 1 then 0x8 else 0 in
            let cellType = if binImg.(i + 1).(j) = 1 then cellType lor 0x4 else cellType in
            let cellType = if binImg.(i + 1).(j + 1) = 1 then cellType lor 0x2 else cellType in
            let cellType = if binImg.(i).(j + 1) = 1 then cellType lor 0x1 else cellType in
            (
              let addSegment x1 y1 x2 y2 = segments.val := [ (x1, y1, x2, y2) :: !segments ] in
                match cellType with
                [ 0 | 15 -> ()
                | 1 | 14 -> addSegment i (j + 1) (i + 1) (j + 2)
                | 2 | 13 -> addSegment (i + 1) (j + 2) (i + 2) (j + 1)
                | 3 | 12 -> addSegment i (j + 1) (i + 2) (j + 1)
                | 4 | 11 -> addSegment (i + 1) j (i + 2) (j + 1)
                | 6 | 9 -> addSegment (i + 1) j (i + 1) (j + 2)
                | 7 | 8 -> addSegment i (j + 1) (i + 1) j
                | 5 -> ( addSegment i (j + 1) (i + 1) j; addSegment (i + 1) (j + 2) (i + 2) (j + 1); )
                | 10 -> ( addSegment i (j + 1) (i + 1) (j + 2); addSegment (i + 1) j (i + 2) (j + 1); )
                | _ -> assert False
                ];
            )
          done;
        done;

        (* making contour of segments set. images may contain some trash pixels and therefore more than one contour. we choose most long contour *)
        let findContour points =
          if points = [] then ([], [])
          else
            let contourLine = let (x1, y1, x2, y2) = List.hd points in { endA = (x1, y1); endB = (x2, y2); points = [ (x1, y1); (x2, y2) ]} in
            let contour = DynArray.of_list (List.tl points) in        
            let merge = ref True in
            (
              while !merge do
                merge.val := False;

                let i = ref 1 in            
                  while !i < DynArray.length contour do
                    let (x1, y1, x2, y2) = DynArray.get contour !i in
                    let pntA = (x1, y1) in
                    let pntB = (x2, y2) in
                      if contourLine.endA = pntB then
                      (
                        contourLine.endA := pntA;
                        contourLine.points := [ pntA :: contourLine.points ];
                        DynArray.delete contour !i;
                        merge.val := True;
                      )
                      else if contourLine.endA = pntA then
                      (
                        contourLine.endA := pntB;
                        contourLine.points := [ pntB :: contourLine.points ];
                        DynArray.delete contour !i;
                        merge.val := True;
                      )
                      else if contourLine.endB = pntB then
                      (
                        contourLine.endB := pntA;
                        contourLine.points := contourLine.points @ [ pntA ];
                        DynArray.delete contour !i;
                        merge.val := True;
                      )                  
                      else if contourLine.endB = pntA then
                      (
                        contourLine.endB := pntB;
                        contourLine.points := contourLine.points @ [ pntB ];
                        DynArray.delete contour !i;
                        merge.val := True;
                      )
                      else incr i;
                  done;
              done;

              (contourLine.points, DynArray.to_list contour);
            )
        in
        let rec findContours points contours =
          match points with
          [ [] -> contours
          | points -> let (contour, points) = findContour points in findContours points [ contour :: contours ]
          ]
        in
        let contours = List.sort (fun a b -> ~-1 * (compare (List.length a) (List.length b))) (findContours !segments []) in
        let points = List.map (fun (x, y) -> (float_of_int x, float_of_int y)) (List.hd contours) in
        let contour =
          if points = [] then []
          else
            let (fstCol, fstRow) = List.hd points in
            let (contour, _) = (* approximating contour *)
              List.fold_left (fun (contour, approxPnts) (col, row) ->
                let (_col, _row) = List.hd contour in
                let k = (row -. _row) /. (col -. _col) in
                let b = row -. col *. k in
                  let est = estimateLine k b approxPnts in
                    if est < lineEstimateThreshold then
                      (contour, [ (col, row) :: approxPnts ])
                    else
                      ([ (col, row) :: contour ], [])
              ) ([ (fstCol, fstRow) ], []) (List.tl points)        
            in contour
        in
        let contour = List.map (fun (x, y) -> (int_of_float x, int_of_float y)) contour in
        (
          (* Printf.printf "%d %s\n" (List.length contour) (String.concat " " (List.map (fun (x, y) -> Printf.sprintf "(%d, %d)" x y) contour)); *)
          Printf.printf "%d\n%!" (List.length contour);

          if (!graph) then
          (
            Graphics.draw_poly (Array.of_list (List.map (fun (x, y) -> (x + !imgPos, 600 - y)) contour));
            imgPos.val := !imgPos + w + 30;            
          )
          else ();

          Rgba32.destroy frameImg;
          anim.contour := List.map (fun (x, y) -> (max 0 (x - 2), max 0 (y - 2))) contour; (* minor correction: cause points will be represented as 32-bit ints (16 bits per coordinate), storing sign information too difficult, so negative coordinates will be rounded to 0 *)
        );
      );
    );
  );

if !graph then
(
  Graphics.open_graph "";
  Graphics.resize_window 1200 600;
  Graphics.set_line_width 2;
  Graphics.set_color 0xff0000;
)
else ();

Array.iter (fun fname ->
  if Sys.is_directory (!indir // fname) && (!libName <> "" && !libName = fname || !libName = "") then
    let objs = readObjs fname
    and frames = readFrames fname
    and regions = readTexInfo fname in      
    (
      if not (ExtString.String.ends_with fname "_sh") then
      (
        if !graph then Graphics.set_window_title fname else ();

        List.iter (fun obj ->
          let () = Printf.printf "processing object %s...\n%!" obj.oname in
            List.iter (fun anim -> let () = Printf.printf "\tprocessing animation %s... %!" anim.aname in genContour regions frames anim) obj.anims
        ) objs;

        if !graph then
        (
          ignore(Graphics.wait_next_event [Graphics.Key_pressed]);
          Graphics.clear_graph ();
          imgPos.val := 0;
        )
        else ();        
      )
      else
        Printf.printf "skip %s\n%!" fname;

      writeObjs fname objs;
    )
  else ()
) (Sys.readdir !indir);

(* ignore(Graphics.wait_next_event [Graphics.Key_pressed]);
Graphics.close_graph (); *)
