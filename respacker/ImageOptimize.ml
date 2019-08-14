open RBase;



value isImagesIntersect (id1,(x1,y1)) (id2,(x2,y2)) =
  match (DynArray.get items id1).item with
  [ `image texInfo1 -> 
    match (DynArray.get items id2).item with
    [ `image texInfo2 ->
      let left = max x1 x2
      and right = min (x1 +. (float texInfo1.width)) (x2 +. (float texInfo2.width)) in
      if left > right
      then False
      else 
        let top = max y1 y2
        and bottom = min (y1 +. (float texInfo1.height)) (y2 +. (float texInfo2.height)) in
        if top > bottom
        then False
        else True
    | _ -> False
    ]
  | _ -> False
  ];
  
exception Next;

value totalUsage id =

  let foldChilds cnt childs = DynArray.fold_left (fun cnt child -> match child with [ `chld (id', _, _, _) when id = id' -> cnt + 1 | _ -> cnt ]) cnt childs in

  DynArray.fold_left (fun cnt item ->
      match item.item with
      [ `image _ -> cnt
      | `sprite children -> foldChilds cnt children
      | `clip frames -> DynArray.fold_left (fun cnt frame -> foldChilds cnt frame.children) cnt frames
      ]
    ) 0 items;

value rec usageFrom address id = (* сделать енум *)
  let address = ref address in
  let rec findElement (elid,addr) = (*{{{*)
    let findInChildren children from = 
      let numChildren = DynArray.length children in
      let rec findChildren i = 
        if numChildren > i
        then
          match DynArray.get children i with
          [ `chld (id',_,pos,_) when id' = id -> (i,pos)
          | _ -> findChildren (i+1)
          ]
        else raise Next
      in
      findChildren from
    in
    match addr with
    [ `sprite children cNum -> 
      try 
        let (cNum,pos) = findInChildren children cNum in
        ((elid,`sprite children (cNum + 1)),pos)
      with [ Next -> nextElement elid ]
    | `clip frames fNum cNum ->
        let numFrames = DynArray.length frames in
        let rec findInFrame fi si =
          if numFrames > fi
          then 
            let frame = DynArray.get frames fi in
            try 
              let (cNum,pos) = findInChildren frame.children si in
              ((elid,`clip frames fi (cNum + 1)),pos)
            with [ Next -> findInFrame (fi + 1) 0 ]
          else nextElement elid
        in
        findInFrame fNum cNum 
    ] (*}}}*)
  and nextElement (elid:int) = (*{{{*)
    let nid = elid + 1 in
    if nid >= DynArray.length items
    then raise Enum.No_more_elements
    else 
      let nel = DynArray.get items nid in
      try
        let addr = 
          match nel.item with
          [ `sprite children -> `sprite children 0
          | `clip frames -> `clip frames 0 0 
          | `image _ -> raise Next
          ]
        in
        findElement (nid,addr)
      with [ Next -> nextElement nid ]
  in(*}}}*)
  Enum.make 
    ~next:begin fun () ->
      let ((addr,pos) as res) = findElement !address in
      (
        address.val := addr;
        match addr with
        [ (elid, addr) ->
          match addr with
          [ `clip frames f c -> ((elid, `clip frames f (c - 1)), pos)
          | `sprite childs c -> ((elid, `sprite childs (c - 1)), pos)
          ]
        ]
      )
    end
    ~count:(fun () -> failwith "can't calculate count")
    ~clone:(fun () -> usageFrom !address id);



value nextChild ?(offset=1) (_,el) =
  match el with
  [ `clip frames fNum cNum -> 
    let frame = DynArray.get frames fNum in
    if DynArray.length frame.children > cNum + offset
    then
      match DynArray.get frame.children (cNum + offset) with
      [ `chld (id,_,pos,_) -> Some (id,pos)
      | _ -> None
      ]
    else None
  | `sprite children cNum when DynArray.length children > cNum + offset -> 
      match DynArray.get children (cNum + offset) with
      [ `chld (id,_,pos,_) -> Some (id,pos)
      | _ -> None 
      ]
  | _ -> None
  ];

value string_of_address (id,el) =
  match el with
  [ `sprite _ cNum -> Printf.sprintf "sprite: %d:%d" id cNum
  | `clip _ fNum cNum -> Printf.sprintf "clip: %d:%d:%d" id fNum cNum
  ];

value remove_unused_images () = 
  let imgUsage = HSet.create 11 in
  (
    let add_children = DynArray.iter (fun [ `chld (id,_,_,_) -> HSet.add imgUsage id | _ -> ()]) in
    for i = 0 to DynArray.length items - 1 do
      match (DynArray.get items i).item with
      [ `sprite children -> add_children children
      | `clip frames -> DynArray.iter (fun {children=children} -> add_children children) frames
      | _ -> ()
      ]
    done;
    let in_exports id = try let () = ignore(DynArray.index_of (fun (_,iid) -> iid = id) exports) in True with [ Not_found -> False ] in
    for i = 0 to DynArray.length items - 1 do
      match DynArray.get items i with
      [ {item_id=id;item=`image _} -> 
        match HSet.mem imgUsage id || in_exports id with
        [ False ->
(*           let () = Printf.printf "remove unused img: %d\n%!" id in *)
          Hashtbl.remove images id
        | True -> ()
        ]
      | _ -> ()
      ]
    done;
  );

value do_merge_images () = 
  let has_changes = ref False in begin
  let alredySeen = HSet.create 1 in

  let rec mergeChildren makeAddr (children:children)  = 
    let i = ref 0 in
    while !i < DynArray.length children - 1 do
      match DynArray.get children !i with
      [ `chld (id1,None,pos1,_) ->
        match  (DynArray.get items id1).item with
        [ `image texInfo1 when not (HSet.mem alredySeen id1) ->
          let () = HSet.add alredySeen id1 in
          match DynArray.get children (!i + 1) with
          [ `chld (id2,None,pos2,_) ->
            match (DynArray.get items id2).item with
            [ `image texInfo2 ->
              let rect1 = Rectangle.create pos1.x pos1.y (float texInfo1.width) (float texInfo1.height)
              and rect2 = Rectangle.create pos2.x pos2.y (float texInfo2.width) (float texInfo2.height) in
              
(*              let () = Printf.printf "fineded intersect images: [%s] and [%s] \n" (string_of_address (makeAddr !i)) (string_of_address (makeAddr (!i+1))) in *)

              let () = Printf.printf "Rect_1 (%s) Rect_2 (%s)\n" (RBase.Rectangle.to_string rect1) (RBase.Rectangle.to_string rect2) in
              
              if not (Rectangle.isIntersect rect1 rect2)
              then ()
              else
                 let () = Printf.printf "fineded intersect images: [%s] and [%s] \n" (string_of_address (makeAddr !i)) (string_of_address (makeAddr (!i+1))) in
                let dx = pos1.x -. pos2.x
                and dy = pos1.y -. pos2.y in

                let usage = usageFrom (makeAddr (!i+2)) id1 in
(*                let usage = usageFrom (makeAddr (!i)) id1 in  *)

                let rec findAll res = (*{{{*)
                  match Enum.get usage with
                  [ Some ((addr,pos) as r) ->
                    (* если следующий елемент такойже и такойже дистанс между ними то круто *)
                    match nextChild addr with
                    [ Some (nid,npos) when nid = id2 ->
                      let dx' = pos.x -. npos.x in
                      if dx = dx'
                      then
                        let dy' = pos.y -. npos.y in
                        if dy = dy' then findAll [ r :: res ] else None
                      else None
                    | _ -> None
                    ]
                  | None -> Some res 
                  ] (*}}}*)
                in
                match findAll [] with (*{{{*)
                [ Some places -> (* ура у нас есть что заменить *) 
                  let placesNum = List.length places in
                  let usagesNum = totalUsage id2 in
                  let () = Printf.printf "\tchecking id2 %d not used anywhere except places (%d, %d) \n%!" id2 placesNum usagesNum in
                    if placesNum <> usagesNum - 1
                    then ()
                    else
                      (
                        has_changes.val := True;
    (*                     Printf.printf "merge %d and %d for (%s)\n%!" id1 id2 (String.concat ";" (List.map (fun (addr,pos) -> Printf.sprintf "[%s]" (string_of_address addr)) places)); *)
                        (* надо найти самое длинное *)
                        let cNum = DynArray.length children in
                        let () = Printf.printf "\tsearching max offset for pair %d %d\n%!" id1 id2 in
                        let rec findMaxOffset rect offset = (*{{{*)
                          if !i + offset + 1 < cNum 
                          then
                            match DynArray.get children (!i + offset + 1) with
                            [ `chld (id,_,pos,_) ->
                              match (DynArray.get items id).item with
                              [ `image texInfo ->
                                let rect' = Rectangle.create pos.x pos.y (float texInfo.width) (float texInfo.height) in
                                if not (Rectangle.isIntersect rect rect')
                                then 
    (*                               let () = print_endline "does not intersect, stop find offset" in *)
                                  offset 
                                else
                                  (* это кандидат на расширение, пробуем его во всех плэйсах *)
                                  let dx = pos1.x -. pos.x
                                  and dy = pos1.y -. pos.y in
                                  let res = 
                                    List.for_all begin fun (addr,pos) ->
                                      match nextChild ~offset:(offset + 1) addr with
                                      [ Some (id',pos') when id = id' -> 
                                        let dx' = pos.x -. pos'.x in
                                        if dx' = dx
                                        then
                                          let dy' = pos.y -. pos'.y in
                                          if dy = dy' then True else False
                                        else False
                                      | _ -> False
                                      ]
                                    end places
                                  in
                                  if res 
                                  then
                                    let usagesNum = totalUsage id in 
                                    let () = Printf.printf "\t\toffset %d seems to be ok, comparing places num of %d usages %d %d\n%!" offset id placesNum usagesNum in
                                      if placesNum = usagesNum - 1
                                      then findMaxOffset (Rectangle.join rect rect') (offset + 1)
                                      else offset
                                  else 
    (*                                 let () = print_endline "not all distances are same, stop find offset" in *)
                                    offset
                              | _ -> 
    (*                               let () = print_endline "does not image, stop find offset" in *)
                                  offset 
                              ]
                            | _ -> offset
                            ]
                          else 
    (*                         let () = print_endline "end of childrens, stop find offset" in *)
                            offset  (*}}}*)
                        in
                        let maxOffset = findMaxOffset (Rectangle.join rect1 rect2) 1 in
                        (
    (*                       Printf.printf "maxOffset %d\n%!" maxOffset; *)
                          (* здесь схлопываем нахуй *)
                          let imgs = 
                            Array.init (maxOffset + 1) begin fun offset -> 
                              match DynArray.get children (!i + offset) with
                              [ `chld (id,_,pos,_) ->
    (*                             let () = Printf.printf "get image: %d\n%!" id in *)
                                let img = 
          (*                         try *)
                                    Hashtbl.find images id 
          (*
                                  with
                                    [ Not_found -> Hashtbl.find removed_img id ]
          *)
                                in
                                (
                                  (id,img,pos)
                                )
                              | _ -> assert False
                              ]
                            end
                          in
                          let rect = [| max_float; max_float ; ~-.max_float; ~-.max_float |] in
                          (
                            Array.iter begin fun (_,img,pos) -> 
                              (
                                if rect.(0) > pos.x then rect.(0) := pos.x else ();
                                if rect.(1) > pos.y then rect.(1) := pos.y else ();
                                let (width,height) = Images.size img in
                                (
                                  if rect.(2) < pos.x +. (float width) then rect.(2) := pos.x +. (float width) else ();
                                  if rect.(3) < pos.y +. (float height) then rect.(3) := pos.y +. (float height) else ();
                                )
                              )
                            end imgs;
                            let gwidth = truncate (rect.(2) -. rect.(0) +. 0.5)
                            and gheight = truncate (rect.(3) -. rect.(1) +. 0.5) in
                            let gimg = Rgba32.make gwidth gheight bgcolor in
        (*                     let debug_dir = Printf.sprintf "/tmp/respacker/%d" id1 in *)
                            (
        (*                       Unix.mkdir debug_dir 0o755; *)
                              Array.iter begin fun (id,img,pos) ->
        (*                         let () = Images.save (debug_dir // (Printf.sprintf "%d.png" id)) (Some Images.Png) [] img in *)
                                let x = truncate (pos.x -. rect.(0) )
                                and y = truncate (pos.y -. rect.(1)) 
                                and img = match img with [ Images.Rgba32 img -> img | _ -> assert False ] in
                                Rgba32.blit ~alphaBlend:True img 0 0 gimg x y img.Rgba32.width img.Rgba32.height
                              end imgs;
        (*                       Images.save (debug_dir // "result.png") (Some Images.Png) [] (Images.Rgba32 gimg); *)
                              Hashtbl.replace images id1 (Images.Rgba32 gimg);
                              DynArray.set items id1 {item_id=id1;item=`image {(texInfo1) with width = gwidth; height = gheight};deleted=False};
                              DynArray.delete_range children !i (maxOffset+1);
                              DynArray.insert children !i (`chld (id1,None,{x=rect.(0);y=rect.(1)},None)); (* FIXME: label skipped *)
                              let dx = pos1.x -. rect.(0)
                              and dy = pos1.y -. rect.(1) in
                              (* А теперь все вхождения пореплейсить нахуй *)
                              List.iter begin fun ((_,el),pos) ->
                                let gpos = {x= pos.x -. dx; y = pos.y -. dy} in
                                match el with
                                [ `sprite children cNum ->
                                  (
                                    DynArray.delete_range children cNum (maxOffset + 1);
                                    DynArray.insert children cNum (`chld (id1,None,gpos,None)); (* FIXME: fix label *)
                                  )
                                | `clip frames fNum cNum ->
                                    let frame = DynArray.get frames fNum in
                                    (
                                      DynArray.delete_range frame.children cNum (maxOffset + 1);
                                      DynArray.insert frame.children cNum (`chld (id1,None,gpos,None));
                                    )
                                ]
                              end places;
                            )
                          );
                        )
                      )
                | None -> ()
                ] (*}}}*)
            | _ -> ()
            ]
          | _ -> ()
          ]
        | _ -> ()
        ]
      | _ -> ()
      ];
      incr i;
    done
  in
  for i = 0 to (DynArray.length items - 1) do
    let el = DynArray.get items i in
    match el.item with
    [ `sprite children -> 
        mergeChildren (fun cNum -> (el.item_id,`sprite children cNum)) children
    | `clip frames ->
        let makeAddr fNum cNum = (el.item_id,`clip frames fNum cNum) in
        for fi = 0 to DynArray.length frames - 1 do
          let () = Printf.printf "scaning frame %d\n%!" fi in
          let frame = DynArray.get frames fi in
          mergeChildren (makeAddr fi) frame.children
        done
    | `image _ -> ()
    ]
  done; 
  !has_changes;
  end;

value merge_images () = 
(
  let rec loop () = 
    match do_merge_images () with
    [ True -> loop ()
    | False -> ()
    ]
  in
  loop ();
  remove_unused_images();
);
