open ExtList;

value estimateLine k b pnts =
  if pnts <> [] then (List.fold_left (fun sum (x, y) -> sum +. sqrt ((y -. k *. x -. b) ** 2.)) 0. pnts) /. (float_of_int (List.length pnts))
  else 0.;

type poly = {
  endA: mutable (int * int);
  endB: mutable (int * int);
  points: mutable list (int * int);
};

(*  
 *  generate contour, steps:
 *    1) find contour segments using "marching squares" algorithm (http://en.wikipedia.org/wiki/Marching_squares)
 *    2) making polygon from segments
 *    3) approximating this polygon by streight lines to minimize vertexes number
 *)

value gen ?(alphaThreshold = 0) ?(lineThreshold = 5.) img = 
  let extendedImg = Rgba32.(make (img.width + 4) (img.height + 4) Color.({ Rgba.color = { Rgb.r = 0xff; g = 0xff; b = 0xff }; alpha = 0 })) in (* extending dimensions by adding 4 pixels cause it helps make contour without breaks, where non-transparent pixels of original image are border *)
  let () = Rgba32.(blit img 0 0 extendedImg 2 2 img.width img.height) in
  let img = extendedImg in

  let w = img.Rgba32.width in
  let h = img.Rgba32.height in

  let binImg = Array.make_matrix (w - 1) (h - 1) 0 in    
    (
      (* making binary image. in this implementation, "pixel" means block 2x2 pixels *)
      let applyThreshold col row =
        Color.Rgba.(
          let c1 = (Rgba32.get img col row).alpha
          and c2 = (Rgba32.get img (col + 1) row).alpha
          and c3 = (Rgba32.get img col (row + 1)).alpha
          and c4 = (Rgba32.get img (col + 1) (row + 1)).alpha in
            if (c1 + c2 + c3 + c4) / 4 <= alphaThreshold then 0 else 1
        )
      in      
        for i = 0 to w - 2 do
          for j = 0 to h - 2 do
            binImg.(i).(j) := applyThreshold i j;
          done;
        done;
      
      (* no need in inner transparent holes, only transparent areas which borders on frame border needed, lets fill it with 2 *)
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

      (* filling rest transparent areas with 1, now image contains no inner holes *)
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

          (* making contour of segments set. images may contain some trash pixels and therefore more than one contour. we choose longest contour *)
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

          let contours = List.sort ~cmp:(fun a b -> ~-1 * (compare (List.length a) (List.length b))) (findContours !segments []) in
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
                      if est < lineThreshold then (contour, [ (col, row) :: approxPnts ])
                      else ([ (col, row) :: contour ], [])
                ) ([ (fstCol, fstRow) ], []) (List.tl points)        
              in contour
          in
            List.map (fun (x, y) -> (int_of_float x, int_of_float y)) contour;
        );
    );
