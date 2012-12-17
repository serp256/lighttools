
open ExtList;
value max_size = ref 2048;
value min_size = ref 32;

type rect = {
  x           : int;
  y           : int;
  w           : int;
  h           : int;
  isRotate  : bool
};

type page 'image_info  = {
  width: int;
  height: int;
  placed_images: list ('image_info * (int*int*bool*Images.t));
  empty_rects: list rect;
};

value create_page width height = 
  {
    width = width;
    height = height;
    placed_images = [];
    empty_rects = [ { x = 0; y = 0; w = width; h = height; isRotate = False } ];
  };

type textureSize = [ Pot | Sqr | Npot ];



value rotate = ref True;
value countEmptyPixels = ref 2;
value do_degree4 x = 
  match x mod 4 with
  [ 0 -> x
  | n -> x + 4 - n
  ];

module MaxRects = struct

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

  value maxrects isDegree4 rects empty = 
    loop rects [] empty [] where
      rec loop rects placed empty unfit = 
        match rects with
        [ [] -> (placed, empty, unfit)    (* все разместили *)
        | [ ((info, img) as r) :: rects']  -> 
            match empty with 
            [ []  -> (placed, empty, (List.append rects unfit))
            | _   -> 
                let (rw,rh) = Images.size img in
                let (rw,rh) = match isDegree4 with [ True -> (do_degree4 rw,do_degree4 rh) | False -> (rw,rh) ] in
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
                [ None -> loop rects' placed empty [ r :: unfit ] 
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
                                ignore(List.findi (fun j rect -> (i <> j) && rect_in_rect r rect) containers);
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
                    loop rects' [ (info, (c.x, c.y, c.isRotate, img)) :: placed ] (filter_rects containers 0 []) unfit
                ]
            ]
        ]
;

end;

(* размещаем на одной странице, постепенно увеличивая ее размер *)
value layout_page_pot ~sqr rects = 
  loop !max_size !max_size where
    rec loop w h =
      let main_rect = { x = 0; y = 0; w; h; isRotate = False  } in
    (*   let () = Printf.printf "Layout page x:%d y:%d w:%d h:%d \n%!" 0 0 w h in *)
      let (placed_images, empty_rects, rest) = MaxRects.maxrects sqr rects [main_rect] in
      match rest with 
      [ [] -> ({width = w; height = h; placed_images; empty_rects}, rest) (* разместили все *)
      | _  -> 
          let (w', h') = 
            match sqr with
            [ True -> (w*2, h*2)
            | _ -> 
                match w < !max_size with
                [ True -> (w * 2, h)
                | _ -> (!min_size, h*2)
                ]
            ]
          in 
          if h' > !max_size 
          then (* не в местили в максимальный размер. возвращаем страницу *)
            ( {width = max_size.val; height= max_size.val; placed_images; empty_rects}, rest)
          else
            loop w' h'
      ];

value min_diff = 1;

value layout_page_npot ?(width=max_size.val) ?(height=max_size.val) rects =
  loop width height (width / 2) (height/ 2) `none where
    rec loop w h dw dh changeH =
      let main_rect = { x = 0; y = 0; w; h; isRotate = False  } in
      let (placed_images, empty_rects, rest) = MaxRects.maxrects False rects [main_rect] in
      match rest with 
      [ [] ->
(*         let () = Printf.printf "All in rect : w : %d; h : %d; dw : %d; dh : %d \n%!" w h dw dh in  *)
        match dw = min_diff && dh = min_diff with
        [ True -> ({width=w; height=h; placed_images; empty_rects}, rest) (* разместили все *)
        | _ -> 
          let (w', h', changeH) =
            match w < h  with
            [ True -> 
                match dh = min_diff with
                [ True -> (w - dw, h, `width)
                | _ -> (w, h - dh, `height)
                ]
            | _ ->
                match dw = min_diff with
                [ True -> (w, h - dh, `height)
                | _ -> (w-dw,h,`width)
                ]
            ]
          in
          loop w' h' dw dh changeH
        ]
      | _  -> 
        match (w = !max_size && h = !max_size) with
        [ True -> ({width=w;height=h;placed_images;empty_rects}, rest)
        | _ -> 
            let (w',h', dw', dh', changeH') =
              match changeH with
              [ `width -> 
                  match dw = min_diff with
                  [ True -> ( w, h , dw, dh / 2, `none)
                  | _ -> (w + dw, h, dw / 2, dh, `none)
                  ]
              | `height -> 
                  match dh = min_diff with
                  [ True -> (w, h, dw / 2, dh, `none)
                  | _ -> (w, h + dh, dw, dh / 2, `none)
                  ]
              | `none -> 
                  match dw > dh with
                  [ True -> (w, h, dw /2, dh, `none)
                  | _ -> (w, h, dw, dh /2, `none)
                  ]
              ]
            in
            loop w' h' dw' dh' changeH'
        ]
    ];

value layout_page ~tsize rects = 
  let rects = 
    List.sort 
      ~cmp:begin fun (_,i1)  (_,i2) -> 
        let (w1,h1) = Images.size i1
        and (w2,h2) = Images.size i2 in
        let s1 = w1*h1 and s2 = w2*h2 in
        if s1 = s2 then 0
        else if s1 > s2 then -1
        else 1
    end rects
  in
  match tsize  with
  [ Sqr | Pot -> layout_page_pot ~sqr:(tsize = Sqr) rects 
  | Npot ->  layout_page_npot rects 
  ];

(* Размещаем все картинки на сколько влезет страницах *)
value layout ~tsize rects = 
  loop rects [] where
    rec loop rects pages =
      let (page,rest) = layout_page ~tsize rects in
      match rest with 
      [ [] -> [ page :: pages ]
      | _  -> loop rest [ page :: pages ]
      ];


(* Размещаем картинки с флажком нужно впихнуть целиком или нужно, впихиваем в максимально возможные страницы *)
value layout_max ?(tsize=Npot) images = 
  let try_place wholly rects pages =
    List.fold_left begin fun (rects,pages) page ->
      match rects with
      [ [] -> ([],[ page :: pages])
      | rects ->
        let (placed,empty_rects,unfit) = MaxRects.maxrects False rects page.empty_rects  in
        match unfit with
        [ [] -> 
          ([],
          [ 
            {(page) with placed_images = placed @ page.placed_images; empty_rects}
            :: pages
          ])
        | _ when wholly -> (* что-то не влезло, а должно было *)
            ( rects, [ page :: pages ])
        | _ -> (* что-то не влезло ну нормально *)
          ( unfit, 
          [ {(page) with placed_images = placed @ page.placed_images; empty_rects}
            :: pages
          ])
        ]
      ]
    end (rects,[]) pages
  in
  let rec alloc_new_pages wholly unfit pages = 
    let new_page = create_page !max_size !max_size in
    let (placed,empty_rects,unfit) = MaxRects.maxrects False unfit new_page.empty_rects in
    let pages = [ new_page :: pages ] in
    match unfit with
    [ [] -> pages
    | _ when wholly -> failwith "can't place images wholly"
    | _ -> 
        match try_place False unfit pages with
        [ ([],pages) -> pages
        | (unfit,pages) -> alloc_new_pages False unfit pages
        ]
    ]
  in
  let pages = 
    List.fold_left begin fun pages (wholly,rects) ->
      let (unfit,pages) = try_place wholly rects pages in
      match unfit with
      [ [] -> pages
      | _ -> alloc_new_pages wholly unfit pages
      ]
    end [ create_page !max_size !max_size ] images
  in
  List.map begin fun page -> 
    (* здесь покромсать пэйджи в соответствии с алгоритмом tsize *)
    let images = List.map (fun (info,(_,_,_,image)) -> (info,image)) page.placed_images in
    let (page,rest) = layout_page ~tsize images in
    let () = assert (rest = []) in
    page
  end pages;

(* Размещаем картинки с флажком нужно впихнуть целиком или нет, запихиваем в минимально возможные страницы *)
(* value layout_min ?(tsize=Npot) images = ( *)



(*
value try_place_on_pages wholly (* нужно обязательно впихнуть в одну или нет *)  pages rects = 
  let (need_new_page,placed,rest, pages)  = 
    List.fold_left begin fun (need,res_placed,rest',res) ((w,h,placed',(empty',rects')) as page) ->
      match need with
      [ True -> 
          let (w, h, placed, empty, rest) = 
            match tsize with
            [ Sqr | Pot -> layout_page ~sqr:(tsize=Sqr) ~init_rects:empty' rects w h 
            | Npot -> layout_page_npot ~init_rects:empty' rects w h 0 0 `none
            ]
          in
          match rest with
          [ [] ->  (False, placed, rest', [ (w,h, placed' @ placed, (empty, rects' @ rects)) :: res])
          | _ -> (need, res_placed, rest', [ page :: res ]) 
          ]
      | _ -> (need, res_placed, rest', [ page :: res ])
      ]
    end (True,[],[],[]) pages
  in

value layout_wholly ?(tsize=Npot) ?(pages=[]) rects =
  let () = print_endline "layout wholly" in
  let (need_new_page,placed,rest, pages)  = 
    List.fold_left begin fun (need,res_placed,rest',res) ((w,h,placed',(empty',rects')) as page) ->
      match need with
      [ True -> 
          let (w, h, placed, empty, rest) = 
            match tsize with
            [ Sqr | Pot -> layout_page ~sqr:(tsize=Sqr) ~init_rects:empty' rects w h 
            | Npot -> layout_page_npot ~init_rects:empty' rects w h 0 0 `none
            ]
          in
          match rest with
          [ [] ->  (False, placed, rest', [ (w,h, placed' @ placed, (empty, rects' @ rects)) :: res])
          | _ -> (need, res_placed, rest' @ rest, [ page :: res ]) 
          ]
      | _ -> (need, res_placed, rest', [ page :: res ])
      ]
    end (True,[],[],[]) pages
  in
  let pages = List.rev pages in
  match need_new_page with
  [ True -> 
      let () = print_endline "need new page" in
      let (w, h, placed, empty, rest) = 
        match tsize with
        [ Sqr | Pot -> layout_page ~sqr:(tsize=Sqr) rects !min_size !min_size 
        | Npot -> layout_page_npot rects !max_size !max_size (!max_size / 2) (!max_size / 2) `none
        ]
      in
      let () = if rest <> [] then failwith ("Can't place all images in 1 texture") else () in
      pages @ [ (w,h,placed,(empty,rects)) ]
  | _ -> pages
  ];
*)
