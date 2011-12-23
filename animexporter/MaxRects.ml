
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
value rec layout_multipage name size rects pages = 
  let (need_new_page,placed,rest, pages)  = 
    List.fold_left begin fun (need,res_placed,rest',res) ((w,h,placed', empty', rects') as page) ->
      match need with
      [ True -> 
          let (w, h, placed, empty, rest) = layout_page empty' rects w h in
          match rest with
          [ [] ->  (False, placed, rest', [(w,h, placed' @ [ (name, placed)] , empty, rects' @ [(name, rects)]) :: res])
          | _ -> (need, res_placed, rest' @ rest, [page :: res ]) 
          ]
      | _ -> (need, res_placed, rest',[ page :: res ])
      ]
    end (True,[],[],[]) pages
  in
  let pages = List.rev pages in
    match need_new_page with
    [ True -> 
        let (w, h, placed, empty, rest) = layout_page [] rects size size in
        ( placed, rest, pages @ [ (w,h,[(name, placed)],empty, [(name,rects)]) ])
    | _ -> ( placed, [], pages)
    ];

value rec layout_last_page size init_pages =
  let rec getLast pages resPages =
    match pages with
    [ [] -> assert False
    | [ p ] -> (p, List.rev resPages)
    | [ p :: pgs ] -> getLast pgs [p :: resPages]
    ]
  in
  let ((_,_,_,_,rects), pages) = getLast init_pages [] in
    (
          let (new_pages, changeSize) = 
            List.fold_left begin fun (pages,cs) (name,rs) -> 
              let (_, rest, pages) = layout_multipage name size rs pages in
              let cs = 
                match cs with
                [ False -> False
                | _ -> rest = []
                ]
              in
              (pages, cs )
            end ([],True) rects
          in
          match changeSize && List.length new_pages < 4 with
          [ True -> layout_last_page (size / 2) (pages @ new_pages)
          | _ -> init_pages
          ]
    );

value layout ?(pages=[]) name rects =
  (
    TextureLayout.rotate.val := False;
    layout_multipage name !min_size rects pages;
  );
