
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
  let (placed, empty, rest) = TextureLayout.maxrects ~not_rotate:True rects [] init_rects [] in
  match rest with 
  [ [] -> (w, h, placed, empty,rest) (* разместили все *)
  | _  -> (!max_size, !max_size, [], init_rects, rest)
  ];

(* размещаем на нескольких страницах *)
value rec layout_multipage rects pages = 
  let (need_new_page,_,i,placed, pages)  = 
    List.fold_left begin fun (need,i,res_i,res_placed, res) ((w,h,placed', empty') as page) ->
      match need with
      [ True -> 
          let (w, h, placed, empty, rest) = layout_page empty' rects w h in
          match rest with
          [ [] ->  (False, i+1, i, placed, [(w,h, placed' @ placed , empty) :: res])
          | _ -> (need, i+1, res_i, res_placed, [page :: res ]) 
          ]
      | _ -> (need, i+1, res_i,res_placed, [ page :: res ])
      ]
    end (True,0,0,[], []) pages
  in
  let pages = List.rev pages in
    match need_new_page with
    [ True -> 
        let (w, h, placed, empty,rects) = layout_page [] rects !min_size !min_size in
        (List.length pages, placed, pages @ [ (w,h,placed,empty) ])
    | _ -> (i, placed, pages)
    ];

value layout  ?(pages=[])  rects =
  (
    layout_multipage rects pages;
  );
