
value max_size = ref 2048;
value min_size = ref 2048;


(* размещаем на одной странице, постепенно увеличивая ее размер *)
value rec layout_page init_rects rects w h = 
  let init_rects =
    match init_rects with
    [ [] -> [{ TextureLayout.x = 0; y = 0; w; h; isRotate = False  } ]
    | _ -> init_rects 
    ]
  in
  let () = Printf.printf "Layout page x:%d y:%d w:%d h:%d \n%!" 0 0 w h in
  let (placed, empty, rest) = TextureLayout.maxrects rects [] init_rects [] in
  match rest with 
  [ [] -> (w, h, placed, empty,rest) (* разместили все *)
  | _  -> (!max_size, !max_size, [], init_rects, rest)
  ];

(* размещаем на нескольких страницах *)
value rec layout_multipage rects pages = 
  let (need_new_page, pages)  = 
    List.fold_left begin fun (need, res) ((w,h,placed', empty') as page) ->
      match need with
      [ True -> 
          let (w, h, placed, empty, rest) = layout_page empty' rects w h in
          match rest with
          [ [] ->  (False, [(w,h, placed' @ placed , empty) :: res])
          | _ -> (need, [page :: res ]) 
          ]
      | _ -> (need, [ page :: res ])
      ]
    end (True, []) pages
  in
  let pages = List.rev pages in
    match need_new_page with
    [ True -> 
        let (w, h, placed, empty,rects) = layout_page [] rects !min_size !min_size in
        let () = Printf.printf "Placed length %d \n%!" (List.length placed) in
        let () = Printf.printf "Rects length %d \n%!" (List.length rects) in
        let () = Printf.printf "Empty length %d \n%!" (List.length empty) in
        pages @ [ (w,h,placed,empty) ]
    | _ -> pages
    ];

value layout  ?(pages=[])  rects =
  (
    layout_multipage rects pages;
  );
