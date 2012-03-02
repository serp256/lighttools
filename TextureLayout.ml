
value max_size = ref 2048;
value min_size = ref 1;

type rect = {
  x           : int;
  y           : int;
  w           : int;
  h           : int;
  isRotate  : bool
};


value rotate = ref True;

type ltype = [= `vert | `hor | `rand | `maxrect ];

value countEmptyPixels = ref 2;

value point_in_rect x y rect =
  (x>= rect.x) && (y >= rect.y) && (x <= rect.x + rect.w) && (y <= rect.y + rect.h);

value rect_in_rect rect2 rect1 =
  point_in_rect rect2.x rect2.y rect1 &&
  point_in_rect (rect2.x + rect2.w) rect2.y rect1 &&
  point_in_rect rect2.x (rect2.y + rect2.h) rect1 &&
  point_in_rect (rect2.x + rect2.w) (rect2.y + rect2.h) rect1;

value calc_subrect rect bound result =
  let str = ref "" in
  let rects =  
    let bx = bound.x - !countEmptyPixels in
    match rect.x < bx && bound.x <= rect.x + rect.w && ((bound.y >= rect.y && bound.y <= rect.y + rect.h) || (bound.y < rect.y && bound.y + bound.h > rect.y)) with (*left rect *)
    [ True -> 
        (
          str.val := !str ^ "left ";
          [ {x =rect.x ; y = rect.y; w = bx - rect.x; h = rect.h; isRotate = False} ]
        )
    | _ -> []
    ]
  in
  let rects =
    let by = bound.y - !countEmptyPixels in
    match rect.y < by && bound.y <= rect.y + rect.h && ((bound.x >= rect.x && bound.x <= rect.x + rect.w) || (bound.x < rect.x && bound.x + bound.w > rect.x))   with (* top rect *)
    [ True ->
        (
          str.val := !str ^ "top ";
          [ {x = rect.x; y = rect.y; w = rect.w; h = by - rect.y; isRotate = False} :: rects]
        )
    | _ -> rects
    ]
  in
  let rects =
    let x = bound.x + bound.w + !countEmptyPixels
    and rect_right = rect.x + rect.w 
    in
    match rect_right > x && bound.x + bound.w >= rect.x && ((bound.y >= rect.y && bound.y <= rect.y + rect.h) || (bound.y < rect.y && bound.y + bound.h > rect.y)) with (* right rect *)
    [ True ->
        (
          str.val := !str ^ "right ";
          [ {x = x; y = rect.y; w = rect_right - x; h =rect.h; isRotate = False} :: rects];
        )
    | _ -> rects
    ]
  in
  let y = bound.y + bound.h + !countEmptyPixels
  and rect_bottom = rect.y + rect.h 
  in
  let rects =
    match rect_bottom > y && bound.y + bound.h >= rect.y && ((bound.x >= rect.x && bound.x <= rect.x + rect.w) || (bound.x < rect.x && bound.x + bound.w > rect.x)) with (* bottom rect *)
    [ True ->
        (
          str.val := !str ^ "bottom ";
          [ {x = rect.x; y = y; w = rect.w; h = rect_bottom - y; isRotate = False} :: rects ]
        )
    | _ -> rects
    ]
  in
  match rects with
  [ [] -> [ rect :: result ]
  | _ -> rects @ result
  ];

value rec maxrects rects placed empty unfit = 
  match rects with
  [ [] -> (placed, empty, unfit)    (* все разместили *)
  | [ ((info, img) as r) :: rects']  -> 
      match empty with 
      [ []  -> (placed, empty, (List.append rects unfit))
      | _   -> 
          let (rw,rh) = Images.size img in
          let (rect, containers) = 
            List.fold_left begin fun (res, containers) c ->
              let container = 
                match rw > c.w || rh > c.h with
                [ True -> 
                    match !rotate with
                    [ True -> 
                        match rw > c.h || rh > c.w with
                        [ True -> None
                        | _ -> Some {(c) with isRotate = True}
                        ]
                    | _ -> None
                    ]
                | _ -> 
                    match !rotate with
                    [ False -> Some {(c) with isRotate=False} 
                    | _ -> 
                        match rw < rh with
                        [ True -> 
                            match rw > c.h || rh > c.w with 
                            [ True -> Some {(c) with isRotate= False}
                            | _ -> Some {(c) with isRotate = True}
                            ]
                        | _  -> Some {(c) with isRotate=False}
                        ] 
                    ]
                ]
              in
              match container with
              [ None -> (res, [c :: containers ]) 
              | Some container ->
                  match res with
                  [ Some res -> 
                      let restop =
                        match res.isRotate with
                        [ True -> res.y + rw 
                        | _ -> res.y + rh
                        ]
                      and ctop = 
                        match container.isRotate with
                        [ True -> container.y + rw
                        | _ -> container.y + rh
                        ]
                      in
                      match restop > ctop || ((restop = ctop) && container.x < res.x) with
                      [ True -> (Some container, [ res :: containers ])
                      | _ -> (Some res, [ container :: containers])
                      ]
                  | _ -> (Some container, containers)
                  ]
              ]
            end (None,[]) empty
          in 
          match rect with
          [ None -> maxrects rects' placed empty [ r :: unfit] 
          | Some c ->
              let (rh,rw) =
                match c.isRotate with
                [ True -> (rw,rh)
                | _ -> (rh,rw)
                ]
              in
              let y = c.y + rh + !countEmptyPixels in
              let rect1 = 
                match y < c.y + c.h with
                [ True -> Some {x = c.x; y = y; w = c.w; h = c.h - rh - !countEmptyPixels; isRotate = False } 
                | _ -> None
                ]
              in
              let x = c.x + rw + !countEmptyPixels in
              let rect2 = 
                match x < c.x + c.w with
                [ True -> Some { x; y = c.y; w = c.w - rw - !countEmptyPixels; h = c.h; isRotate = False  }
                | _ -> None
                ]
              in
              let rec find_subrects rects res_rects = 
                match rects with
                [ [] -> res_rects
                | [ rect :: rects ] -> find_subrects rects (calc_subrect rect {x=c.x; y=c.y; w = rw; h= rh; isRotate = False } res_rects)
                ] 
              in
              let containers = find_subrects containers [] in
              let containers =
                match rect1 with
                [ Some rect -> 
                    (
                      [ rect :: containers ] 
                    )
                | _ -> containers
                ]
              in
              let containers = 
                match rect2 with
                [ Some rect ->
                    (
                      [ rect :: containers ] 
                    )
                | _ -> containers
                ]
              in
              let rec filter_rects rects i res = 
                match rects with
                [ [] -> res
                | [ r :: rects ] -> 
                    let inRect =
                      try 
                        (
                          ignore(BatList.findi (fun j rect -> (i <> j) && rect_in_rect r rect) containers);
                          True
                        )
                      with
                        [ Not_found -> False ] 
                    in
                    match inRect with
                    [ True -> filter_rects rects (i + 1) res
                    | _ -> filter_rects rects (i + 1) [ r :: res ]
                    ]
                ]
              in
              let img =
                match c.isRotate with
                [ True ->
                    let (w,h) = Images.size img in
                    match img with
                    [ Images.Rgba32 img -> 
                        let image = Rgba32.create h w in
                          (
                            for i = 0 to (h-1) do
                              for j = 0 to (w-1) do
                                Rgba32.set image i j (Rgba32.get img j i)
                              done
                            done;
                            Images.Rgba32 image
                          )
                    | Images.Index8 img -> 
                        let image = Index8.create h w in
                          (
                            for i = 0 to (h-1) do
                              for j = 0 to (w-1) do
                                Index8.set image i j (Index8.get img j i)
                              done
                            done;
                            Images.Index8 image
                          )
                    | Images.Index16 img -> 
                        let image = Index16.create h w in
                          (
                            for i = 0 to (h-1) do
                              for j = 0 to (w-1) do
                                Index16.set image i j (Index16.get img j i)
                              done
                            done;
                            Images.Index16 image
                          )
                    | Images.Rgb24 img -> 
                        let image = Rgb24.create h w in
                          (
                            for i = 0 to (h-1) do
                              for j = 0 to (w-1) do
                                Rgb24.set image i j (Rgb24.get img j i)
                              done
                            done;
                            Images.Rgb24 image
                          )
                    | Images.Cmyk32 img -> 
                        let image = Cmyk32.create h w in
                          (
                            for i = 0 to (h-1) do
                              for j = 0 to (w-1) do
                                Cmyk32.set image i j (Cmyk32.get img j i)
                              done
                            done;
                            Images.Cmyk32 image
                          )
                    ]
                | _ -> img
                ]
              in
              maxrects rects' [ (info, (c.x, c.y, c.isRotate, img)) :: placed ] (filter_rects containers 0 []) unfit
          ]
      ]
  ];

(* 
  пробуем упаковать прямоугольники в заданные пустые прямоугольники.
  возвращаем оставшиеся прямоугольники и страницы
*)
value rec tryLayout ~type_rects rects placed empty unfit = 
  match rects with
  [ [] -> (placed, unfit)    (* все разместили *)
  | [r :: rects']  -> 
    match empty with 
    [ []  -> (placed, (List.append rects unfit))
    | _   -> 
    
      let rec putToMinimalContainer ((info,img) as data) placed containers used_containers = 
        match containers with 
        [ [] -> raise Not_found
        | [ c :: containers'] -> 
          let (rw,rh) = Images.size img in
          if rw > c.w || rh > c.h 
          then
            putToMinimalContainer data  placed containers' [c :: used_containers]
          else
            let type_rects =
              match type_rects with
              [ `rand -> match Random.int 2 with [ 0 -> `vert | 1 -> `hor | _ -> assert False ]
              | (`vert | `hor) as t -> t
              | `maxrect -> assert False
              ] 
            in
            let rects = 
              match type_rects with
              [ `vert ->
                  [
                    { x = c.x; y = c.y + rh + !countEmptyPixels; w = rw; h = c.h - rh - !countEmptyPixels; isRotate = False  };
                    { x = c.x + rw + !countEmptyPixels; y = c.y; w = c.w - rw - !countEmptyPixels; h = c.h; isRotate = False  }
                  ]
              | `hor -> 
                  [
                    { x = c.x; y = c.y + rh + !countEmptyPixels; w = c.w; h = c.h - rh - !countEmptyPixels; isRotate = False  };
                    { x = c.x + rw + !countEmptyPixels; y = c.y; w = c.w - rw - !countEmptyPixels; h = rh; isRotate = False  }
                  ]
              ]
            in 
            (
              [(info,(c.x,c.y,c.isRotate, img)) :: placed], 
              List.append containers' (List.append used_containers rects)
            )
        ]
      in 
    
      (* пытаемся впихнуть наибольший прямоугольник в наименьшую пустую область *)
      try 
        let (placed', empty') = putToMinimalContainer r placed empty []  
        in tryLayout ~type_rects rects' placed' (List.sort begin fun c1 c2 -> 
          let s1 = c1.w*c1.h 
          and s2 = c2.w*c2.h
          in 
          if s1 = s2 
          then 0
          else if s1 > s2 
          then 1
          else -1  
        end empty') unfit
      with [Not_found -> tryLayout ~type_rects rects' placed empty [r :: unfit]]
    ]
  ];


(* размещаем на одной странице, постепенно увеличивая ее размер *)
value rec layout_page ~type_rects ~sqr rects w h = 
  let mainrect = { x = 0; y = 0; w; h; isRotate = False  } in
  let () = Printf.printf "Layout page x:%d y:%d w:%d h:%d \n%!" 0 0 w h in
  let (placed, rest) = 
    match type_rects with
    [ `maxrect ->
        let (placed, _, rest) = maxrects rects [] [mainrect] [] in
        (placed, rest)
    | _ -> tryLayout ~type_rects rects [] [mainrect] [] 
    ]
  in
  match rest with 
  [ [] -> (w, h, placed, rest) (* разместили все *)
  | _  -> 
      let (w', h') = 
        match sqr with
        [ True -> (w*2, h*2)
        | _ -> 
          if w > h 
          then (w, (h*2))
          else ((w*2), h)
        ]
      in 
      if w' > !max_size 
      then (* не в местили в максимальный размер. возвращаем страницу *)
        (!max_size, !max_size, placed, rest)
      else
        layout_page ~type_rects ~sqr rects w' h'
  ];


(* размещаем на нескольких страницах *)
value rec layout_multipage ~type_rects ~sqr rects pages = 
  let (w, h, placed, rest) = 
    layout_page ~type_rects ~sqr
      (List.sort 
        begin fun (_,i1)  (_,i2) -> 
          let (w1,h1) = Images.size i1
          and (w2,h2) = Images.size i2 in
          let s1 = w1*h1 and s2 = w2*h2 in
          if s1 = s2 then 0
          else if s1 > s2 then -1
          else 1
      end rects
    ) !min_size !min_size 
  in 
  match rest with 
  [ [] -> [ (w,h,placed) :: pages]
  | _  -> layout_multipage ~type_rects ~sqr rest [(w,h,placed) :: pages]
  ];


(* 
 возвращает список страниц. каждая страница не больше 2048x2048
*)
value layout ?(type_rects=`maxrect) ?(sqr=True) rects =
  (
    Random.self_init ();
    layout_multipage ~type_rects ~sqr rects [];
  );


value pvr_png img = 
  match Sys.command (Printf.sprintf "PVRTexTool -yflip0 -fOGLPVRTC4 -i%s.png -o %s.pvr" img img) with
  [ 0 -> ()
  | _ -> failwith (Printf.sprintf "Failed pvr %s.png" img)
  ];
