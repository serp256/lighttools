
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
value do_degree4 x = (x + 4) - (x mod 4);

module MaxRects = struct

  value point_in_rect x y rect =
    let res =  (x>= rect.x) && (y >= rect.y) && (x <= rect.x + rect.w) && (y <= rect.y + rect.h) in
    (
      (*
      Printf.printf "POINT IN RECT [%d; %d] in [%d; %d; %d; %d]: %B \n%!" x y rect.x rect.y (rect.x + rect.w) (rect.y + rect.h) res;
      *)
      res;
    );

  value rect_in_rect rect2 rect1 =
    point_in_rect rect2.x rect2.y rect1 &&
    point_in_rect (rect2.x + rect2.w) rect2.y rect1 &&
    point_in_rect rect2.x (rect2.y + rect2.h) rect1 &&
    point_in_rect (rect2.x + rect2.w) (rect2.y + rect2.h) rect1;

  value calc_subrect rect bound result =
    let str = ref "" in
    let rects =  
      let bx = bound.x in
      let () = assert (bx mod 4 = 0) in
      match rect.x < bx && bound.x <= rect.x + rect.w && ((bound.y >= rect.y && bound.y <= rect.y + rect.h) || (bound.y < rect.y && bound.y + bound.h > rect.y)) with (*left rect *)
      [ True -> 
          (
            str.val := !str ^ "left ";
            [ {x =rect.x ; y = rect.y; w = bx - rect.x - !countEmptyPixels; h = rect.h; isRotate = False} ]
          )
      | _ -> []
      ]
    in
    let rects =
      let by = bound.y in
      match rect.y < by && bound.y <= rect.y + rect.h && ((bound.x >= rect.x && bound.x <= rect.x + rect.w) || (bound.x < rect.x && bound.x + bound.w > rect.x))   with (* top rect *)
      [ True ->
          (
            str.val := !str ^ "top ";
            [ {x = rect.x; y = rect.y; w = rect.w; h = by - rect.y - !countEmptyPixels; isRotate = False} :: rects]
          )
      | _ -> rects
      ]
    in
    let rects =
      let x = bound.x + bound.w 
      and rect_right = rect.x + rect.w 
      in
      match rect_right > x && bound.x + bound.w >= rect.x && ((bound.y >= rect.y && bound.y <= rect.y + rect.h) || (bound.y < rect.y && bound.y + bound.h > rect.y)) with (* right rect *)
      [ True ->
          (
            str.val := !str ^ "right ";
            let l = do_degree4 (x + !countEmptyPixels) in
            let w = rect_right - l in
            match w > 0 with
            [ True -> [ {x = l; y = rect.y; w = w; h =rect.h; isRotate = False} :: rects]
            | _ -> rects 
            ]
          )
      | _ -> rects
      ]
    in
    let y = bound.y + bound.h
    and rect_bottom = rect.y + rect.h 
    in
    let rects =
      match rect_bottom > y && bound.y + bound.h >= rect.y && ((bound.x >= rect.x && bound.x <= rect.x + rect.w) || (bound.x < rect.x && bound.x + bound.w > rect.x)) with (* bottom rect *)
      [ True ->
          (
            str.val := !str ^ "bottom ";
            let t = do_degree4 (y + !countEmptyPixels) in
            let h = rect_bottom - t in
            match h > 0 with
            [ True -> [ {x = rect.x; y = t; w = rect.w; h = h; isRotate = False} :: rects ]
            | _ -> rects
            ]
          )
      | _ -> rects
      ]
    in
    match rects with
    [ [] -> 
        match rect = bound with
        [ True -> result
        |  _ -> [ rect :: result ]
        ]
    | _ -> 
        let rects = List.filter (fun rect -> rect.w > !countEmptyPixels && rect.h > !countEmptyPixels) rects in
        rects @ result
    ];

  value rotate_img img = 
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
    ];

  value checkPlaced placed = 
    (*
    let () = Printf.printf "CHECK PLACED %d\n%!" (List.length placed) in
    *)
    List.iteri begin fun i (idi,(x,y,_,img)) -> 
      let (w,h) = Images.size img in
      let recti = {x;y;w;h;isRotate=False} in
      List.iteri begin fun j (idj,(xj, yj, _, imgj)) -> 
        match i <> j with
        [ True ->
            let (w,h) = Images.size imgj in
            let rectj = {x=xj;y=yj;w;h;isRotate=False} in
            match rect_in_rect recti rectj with
            [ True ->
                (
                  (*
                  Printf.printf "rect1 %d : [%d; %d; %d; %d]; rect2 %d : [%d; %d; %d; %d]\n%!" idi recti.x recti.y (recti.x +recti.w) (recti.y + recti.h) idj rectj.x rectj.y (rectj.x +rectj.w) (rectj.y + rectj.h);
                  *)
                  assert False
                )
            | _ ->  ()
            ]
        | _ -> ()
        ]
      end placed;
    end placed;

  value checkPlacedAndEmpty placed empty= 
    (*
    let () = Printf.printf "CHECK PLACED AND EMPTY %d %d\n%!" (List.length placed) (List.length empty) in
    *)
    List.iter begin fun (idi,(x,y,_,img)) -> 
      let (w,h) = Images.size img in
      let recti = {x;y;w;h;isRotate=False} in
      List.iter begin fun rectj -> 
        match rect_in_rect recti rectj || rect_in_rect rectj recti with
        [ True ->
            (
              (*
              Printf.printf "rect1 %d : [%d; %d; %d; %d]; rect_empty : [%d; %d; %d; %d]\n%!" idi recti.x recti.y (recti.x +recti.w) (recti.y + recti.h) rectj.x rectj.y (rectj.x +rectj.w) (rectj.y + rectj.h);
              *)
              assert False
            )
        | _ -> ()
        ]
      end empty;
    end placed;

  value maxrects isDegree4 rects empty = 
    (* let () = Printf.printf "START MAX RECTS %d %dx%d\n%!" (List.length empty) (List.hd empty).w (List.hd empty).h in     *)
    loop rects [] empty [] where
      rec loop rects placed empty unfit = 
(*         let () = Printf.printf "maxrects loop [%d:%d:%d:%d]\n%!" (List.length
 *         rects) (List.length placed) (List.length empty) (List.length unfit)
 *         in *)
        (*
        let () = checkPlacedAndEmpty placed empty in
        let () = checkPlaced placed in 
        *)
        match rects with
        [ [] -> (List.rev placed, empty, unfit)    (* все разместили *)
        | [ ((info, img) as r) :: rects']  -> 
            match empty with 
            [ []  -> (List.rev placed, empty, (List.append rects unfit))
            | _   -> 
                let (rw,rh) = Images.size img in
                (*
                let (rw,rh) = match isDegree4 with [ True -> (do_degree4 rw,do_degree4 rh) | False -> (rw,rh) ] in
                *)
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
                    let nrect = {(c) with w=rw;h=rh;isRotate = False} in
                    let rec find_subrects rects res_rects = 
                      match rects with
                      [ [] -> res_rects
                      | [ rect :: rects ] -> find_subrects rects (calc_subrect rect nrect res_rects)
                      ]
                    in
                    let containers = find_subrects containers [] in
                    let containers = 
                      let y = do_degree4 (c.y + rh + !countEmptyPixels) in
                      match y < c.y + c.h with
                      [ True -> [ { (c) with y; h = c.h + c.y - y; isRotate = False } :: containers ]
                      | _ -> containers
                      ]
                    in
                    let containers = 
                      let x = do_degree4 (c.x + rw + !countEmptyPixels) in
                      match x < c.x + c.w with
                      [ True -> [ { (c) with x; w = c.x + c.w - x; isRotate = False  } :: containers ]
                      | _ -> containers
                      ]
                    in
                    (* здесь может быть не совсем верно нах. *)
                    let rec filter_rects rects i res = 
                      match rects with
                      [ [] -> res
                      | [ r :: rects ] -> 
                          let inRect =
                            try 
                              (
                                ignore(List.findi (fun j rect -> (i <> j) && (rect_in_rect r rect)) containers);
                                True
                              )
                            with [ Not_found -> False ] 
                          in
                          match inRect with
                          [ True -> filter_rects rects (i + 1) res
                          | _ -> filter_rects rects (i + 1) [ r :: res ]
                          ]
                      ]
                    in
                    let img =
                      match c.isRotate with
                      [ True -> rotate_img img
                      | _ -> img
                      ]
                    in
                      (
                        (*
                        Printf.printf "containers after find_subrects: ";
                        Printf.printf "place %d %dx%d  img to %d:%d:%d:%d\n%!" info rw rh c.x c.y c.w c.h;
                        checkPlacedAndEmpty [ (info, (c.x, c.y, c.isRotate, img)) :: placed ] containers;
                        *)
                        loop rects' [ (info, (c.x, c.y, c.isRotate, img)) :: placed ] (filter_rects containers 0 []) unfit
                      )
                ]
            ]
        ]
;

end;

(* размещаем на одной странице, постепенно увеличивая ее размер *)
value layout_page_pot ~sqr rects = 
  let () = print_endline ("layout page pot " ^ (string_of_int !max_size)) in
  loop !min_size !min_size where
    rec loop w h =
      let main_rect = { x = 0; y = 0; w; h; isRotate = False  } in
      let () = Printf.printf "Layout page sqr:%b; x:%d y:%d w:%d h:%d \n%!" sqr 0 0 w h in
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
         let () = Printf.printf "All in rect : w : %d; h : %d; dw : %d; dh : %d \n%!" w h dw dh in  
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
  let () = Printf.printf "layout page: %d\n%!" (List.length rects) in
  (* FIXME: не уверен что нужно 
  let rects = 
    List.sort 
      ~cmp:begin fun (_,i1)  (_,i2) -> 
        let (w1,h1) = Images.size i1
        and (w2,h2) = Images.size i2 in
        let s1 = w1*h1 and s2 = w2*h2 in
        if s1 = s2 then 0
        else if s1 > s2 then 1
        else -1
    end rects
  in
  *)
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



  value stringify_images images = 
    let l = 
      List.map begin fun (wholly,imgs) ->
        let imgs = 
          String.concat ","
            (List.map begin fun (_,img) ->
              let (w,h) = Images.size img in
              Printf.sprintf "<%d:%d>" w h 
            end imgs)
        in
        Printf.sprintf "%B:%s" wholly imgs
      end images
    in
    String.concat ";" l;

(* Размещаем картинки с флажком нужно впихнуть целиком или не нужно, впихиваем в максимально возможные страницы *)
value layout_max ?(tsize=Npot) images = 
  let () = Printf.printf "layout_max: %d [%s]\n%!" (List.length images) (stringify_images images) in
  let try_place wholly rects pages =
    let () = print_endline "try place" in
    List.fold_left begin fun (rects,pages) page ->
      match rects with
      [ [] -> ([],[ page :: pages])
      | rects ->
        let (placed_images,empty_rects,unfit) = MaxRects.maxrects (tsize=Sqr) rects page.empty_rects  in
        match unfit with
        [ [] -> 
          ([],
          [ 
            {(page) with placed_images = page.placed_images @ placed_images; empty_rects}
            :: pages
          ])
        | _ when wholly -> (* что-то не влезло, а должно было *)
            ( rects, [ page :: pages ])
        | _ -> (* что-то не влезло ну нормально *)
          ( unfit, 
          [ {(page) with placed_images = page.placed_images @ placed_images; empty_rects}
            :: pages
          ])
        ]
      ]
    end (rects,[]) pages
  in
  let rec alloc_new_pages wholly unfit pages = 
    let () = print_endline (Printf.sprintf "alloc new pages wholly : %b" wholly) in
    let new_page = create_page !max_size !max_size in
    let (placed_images,empty_rects,unfit) = MaxRects.maxrects False unfit new_page.empty_rects in
    match unfit with
    [ [] -> [ {(new_page) with placed_images; empty_rects} :: pages ]
    | _ when wholly -> failwith "can't place images wholly"
    | _ -> 
        match try_place False unfit pages with
        [ ([],pages) -> [ {(new_page) with placed_images; empty_rects} :: pages ]
        | (unfit,pages) -> 
            let pages = [ {(new_page) with placed_images; empty_rects} :: pages ] in
            alloc_new_pages False unfit pages
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
  (*
  let () = 
    Printf.printf "ALL allocated!!!! pages: %d [%s]\n%!" 
      (List.length pages) 
      (String.concat ";" (List.map (fun page -> Printf.sprintf "[%d:(%s)]" (List.length page.placed_images) (String.concat "," (List.map (fun (_,(x,y,_,image)) -> Printf.sprintf "x : %d; y=%d; w=%d; h=%d\n" x y) page.placed_images))) pages)) 
  in
  *)
  List.map begin fun page -> 
    (* здесь покромсать пэйджи в соответствии с алгоритмом tsize *)
    let images = List.map (fun (info,(_,_,_,image)) -> (info,image)) page.placed_images in
    let (page,rest) = layout_page ~tsize images in
    let () = assert (rest = []) in
    page
  end pages;

(* Размещаем картинки с флажком нужно впихнуть целиком или нет, запихиваем в минимально возможные страницы *)
value layout_min ?(tsize=Sqr) (images:list (bool * (list ('a * Images.t)) )) = 
  let () = Printf.printf "layout_min: %d [%s]\n%!" (List.length images) (String.concat ";" (List.map (fun (wholly,imgs) -> Printf.sprintf "%B:%d" wholly (List.length imgs)) images)) in
  let try_place wholly rects pages =
    let () = print_endline "try place" in
    List.fold_left begin fun (rects,pages) page ->
      match rects with
      [ [] -> ([],[ page :: pages])
      | rects ->
        let (placed_images,empty_rects,unfit) = MaxRects.maxrects True rects page.empty_rects  in
        let placed_images = List.rev placed_images in
        match unfit with
        [ [] -> 
          ([],
          [ 
            {(page) with placed_images = page.placed_images @ placed_images; empty_rects}
            :: pages
          ])
        | _ when wholly -> (* что-то не влезло, а должно было *)
            ( rects, [ page :: pages ])
        | _ -> (* что-то не влезло ну нормально *)
          ( unfit, 
          [ {(page) with placed_images = page.placed_images @ placed_images; empty_rects}
            :: pages
          ])
        ]
      ]
    end (rects,[]) pages
  in
  let  rec alloc_new_pages wholly unfit pages = 
    let () = print_endline (Printf.sprintf "alloc new pages wholly : %b" wholly) in
    let (new_page,unfit) = layout_page_pot ~sqr:True unfit in
    let new_page = {(new_page) with placed_images = List.rev new_page.placed_images } in
    match unfit with
    [ [] -> [ new_page :: pages ]
    | _ when wholly ->
          (
            (*
            let ((_,_,name,aname),_) = List.hd new_page.placed_images in
            Printf.printf "info %s:%s  \n%!" name aname;
            *)
            failwith "can't place images wholly";
          )
    | _ -> 
        match try_place False unfit pages with
        [ ([],pages) -> [ new_page :: pages ]
        | (unfit,pages) -> 
            let pages = [ new_page :: pages ] in
            alloc_new_pages False unfit pages
        ]
    ]
  in
  let pages = 
    match images with
    [ [] -> []
    | [ (wholly, rects) :: images ] -> 
        let pages = alloc_new_pages wholly rects [] in
        List.fold_left begin fun pages (wholly,rects) ->
          let (unfit,pages) = try_place wholly rects pages in
          match unfit with
          [ [] -> pages
          | _ -> alloc_new_pages wholly unfit pages
          ]
        end pages images
    ]
  in
  (*
  let () = 
    Printf.printf "ALL allocated!!!! pages: %d [%s]\n%!" 
      (List.length pages) 
      (String.concat ";" (List.map (fun page -> Printf.sprintf "[%d:(%s)]" (List.length page.placed_images) (String.concat "," (List.map (fun (_,_) -> "SOME INFO") page.placed_images))) pages)) 
  in
  *)
  pages;
  (*
  List.map begin fun page -> 
    (* здесь покромсать пэйджи в соответствии с алгоритмом tsize *)
    let images = List.map (fun (info,(_,_,_,image)) -> (info,image)) page.placed_images in
    let (page,rest) = layout_page ~tsize images in
    let () = assert (rest = []) in
    page
  end pages;
  *)



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
