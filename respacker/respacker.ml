(* Скрипт пакует данные swf потрошителя *)
open ExtList;
open ExtString;
open Printf;

value (//) = Filename.concat;
value (=|=) k v = (("",k),v);
value (=.=) k v = k =|= string_of_float v;
value (=*=) k v = k =|= string_of_int v;

value bgcolor = {Color.color = {Color.r = 0; g = 0; b = 0}; alpha = 0};

value jfloat = fun [ `Float s -> s | _ -> failwith "not a float" ];
value jint = fun [ `Int s -> s | _ -> failwith "not a float" ];
value jnumber = fun [ `Int s -> float s | `Float f -> f | _ -> failwith "not a float" ];
value jobject = fun [ `Assoc s -> s | _ -> failwith "not an object" ];
value jstring = fun [ `String s -> s | _ -> failwith "not a string" ];
value jlist = fun [ `List s -> s | _ -> failwith "not a list" ];


module Rectangle = struct

  type t = {x:float; y:float; width:float; height:float;};
  value empty = {x=0.;y=0.;width=0.;height=0.};
  value create x y width height = {x;y;width;height};

  value isIntersect rect1 rect2 = 
    let left = max rect1.x rect2.x
    and right = min (rect1.x +. rect1.width) (rect2.x +. rect2.width) in
    if left > right
    then False
    else
      let top = max rect1.y rect2.y
      and bottom = min (rect1.y +. rect1.height) (rect2.y +. rect2.height) in
      if top > bottom
      then False
      else True;

  value join r1 r2 =
    let xr1 = r1.x +. r2.width
    and yr1 = r1.y +. r1.height
    and xr2 = r2.x +. r2.width
    and yr2 = r2.y +. r2.height
    in
    let xr = max xr1 xr2
    and yr = max yr1 yr2
    and x = min r1.x r2.x
    and y = min r1.y r2.y
    in
    {x;y;width=xr-.x;height=yr-.y};


  value to_string {x=x;y=y;width=width;height=height} = Printf.sprintf "[x=%f,y=%f,width=%f,height=%f]" x y width height;

end;


type pos = {x:float;y:float};
type texinfo = {page:mutable int; tx:mutable int;ty:mutable int; width: int;height:int};
type child = [= `chld of (int * option string * pos) | `box of (pos * string) ];
type children = DynArray.t child;
type clipcmd = [ ClpPlace of (int * (int * option string * pos)) | ClpClear of (int*int) | ClpChange of (int * list [= `posX of float | `posY of float | `move of int]) ];
type frame = {children:children; commands: mutable option (DynArray.t clipcmd); label: option string; duration: mutable int};
type item = [= `image of texinfo | `sprite of children | `clip of DynArray.t frame ];
type iteminfo = {item_id:int; item:item; deleted: mutable bool};

value images = Hashtbl.create 11;
value items : DynArray.t iteminfo = DynArray.create ();
value exports: DynArray.t (string*int) = DynArray.create ();

exception Not_equal;

value compare_images img1 img2 = 
  match img1 with
  [ Images.Rgba32 i1 ->
    match img2 with
    [ Images.Rgba32 i2 when i1.Rgba32.height = i2.Rgba32.height && i1.Rgba32.width = i2.Rgba32.width ->
      try
        for i = 0 to i1.Rgba32.height - 1 do
          match Rgba32.get_scanline i1 i = Rgba32.get_scanline i2 i with
          [ True -> ()
          | False -> raise Not_equal
          ]
        done;
        True
      with [ Not_equal -> False ]
    | _ -> False
    ]
  | _ -> False
  ];


value dynarray_compare ?(compare=(=)) dyn1 dyn2 = 
  let len = DynArray.length dyn1 in
  if len <> DynArray.length dyn2 
  then False
  else
    let i = ref 0 in
    let eq = ref True in
    (
      while !eq && !i < len do
        if compare (DynArray.get dyn1 !i) (DynArray.get dyn2 !i)
        then incr i
        else eq.val := False
      done;
      !eq;
    );


value compare_frame f1 f2 = 
  f1.label = f2.label
  &&
  f1.duration = f2.duration
  &&
  dynarray_compare f1.children f2.children;

value compare_item item1 item2 = 
  match (item1,item2) with
  [ (`sprite children1 ,`sprite children2) -> dynarray_compare children1 children2
  | (`clip frames1, `clip frames2) ->
      dynarray_compare ~compare:compare_frame frames1 frames2
  | (`sprite _,`clip _) | (`clip _ ,`sprite _) -> False
  ];

value push_item item =
  try
    DynArray.index_of (fun {item=i} -> match i with [ `image _ -> False | (`sprite _ | `clip _ ) as el -> compare_item el item]) items
    (*
    match item with
    [ `sprite _ | `clip _ -> DynArray.index_of (fun (_,i) -> compare_item i item) items
    | `image _ -> raise Not_found
    ]
    *)
  with 
  [ Not_found ->
    (
      DynArray.add items {item_id=(DynArray.length items);item=(item :> item);deleted=False};
      (DynArray.length items) - 1;
    )
  ];



exception Finded of int;
value add_image path = 
  let () = Printf.fprintf stdout "%s\n" path in
  let img = Images.load path [] in
  try
    Hashtbl.iter begin fun id img' ->
      if compare_images img img'
      then raise (Finded id)
      else ()
    end images;
  let id = DynArray.length items 
  in
  (
    let (width,height) = Images.size img in
    DynArray.add items {item_id=id;item=(`image {page=0;tx=0;ty=0;width;height});deleted=False};
    Hashtbl.add images id img;
    id
  );
  with [ Finded id -> id ];


value add_child_image  dirname mobj = 
  let path = dirname // (jstring (List.assoc "file" mobj)) in
  add_image path;

value getpos jsinfo = {x= jnumber (List.assoc "x" jsinfo);y=jnumber (List.assoc "y" jsinfo)};

(* можно при добавлении картинок палить что они такие-же только разница в альфе - это легко 
 * а в группировке есть засада, что мы можем не понять что это одно и тоже так как мы с чем-то слепим и будет не круто
 * *)

(* value calc_diff oldchildrens newchildrens =  *)


value rec process_children dirname children = 
  let lst = 
    List.map begin fun child ->
      let child = jobject child in
      let ctype =  jstring (List.assoc "type" child) in
      let pos = getpos child in
      match ctype with
      [ "box" -> `box (pos,jstring (List.assoc "name" child))
      | _ ->
        let name = try Some (jstring (List.assoc "name" child)) with [ Not_found -> None ] in
        let id = 
          match ctype with
          [ "image" -> (add_child_image dirname child)
          | "clip" | "sprite" -> process_dir (dirname // (jstring (List.assoc "dir" child)))
          | _ -> assert False
          ]
        in
        `chld (id,name,pos)
      ]
    end (jlist children)
  in
  DynArray.of_list lst
and process_dir dirname = (* найти мету в этой директории и от нее плясать *)
  let () = printf "process directory: %s\n%!" dirname in
  let mobj = jobject (Ojson.from_file (dirname // "meta.json") ) in
  match jstring (List.assoc "type" mobj) with
  [ "image" -> add_child_image dirname mobj
  | "sprite" -> 
      let children = process_children dirname (List.assoc "children" mobj) in
      push_item (`sprite children)
  | "clip" ->
      let lframes = 
        List.map begin fun frame ->
          let frame = jobject frame in 
          let label = try Some (jstring (List.assoc "label" frame)) with [ Not_found -> None ] in
          let children = process_children dirname (List.assoc "children" frame) in
          let () = DynArray.filter (fun [ `chld _ -> True | _ -> False ]) children in
          {label;commands=None;children;duration=1}
        end (jlist (List.assoc "frames" mobj))
      in
      (* вычислим duration *)
      let frames = DynArray.create () in
      (
        List.iter begin fun frame -> 
          match (DynArray.length frames > 0, lazy (DynArray.last frames)) with
          [ (True, lazy lframe ) when compare_frame lframe frame -> lframe.duration := lframe.duration + 1
          | _ -> DynArray.add frames frame 
          ]
        end lframes;
        push_item (`clip frames)
      )
  | _ -> assert False
  ];



(*  merge images {{{ *)
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

value rec usageFrom address id = (* сделать енум *)
  let address = ref address in
  let rec findElement (elid,addr) = (*{{{*)
    let findInChildren children from = 
      let numChildren = DynArray.length children in
      let rec findChildren i = 
        if numChildren > i
        then
          match DynArray.get children i with
          [ `chld (id',_,pos) when id' = id -> (i,pos)
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
      let ((addr,_) as res) = findElement !address in
      (
        address.val := addr;
        res
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
      [ `chld (id,_,pos) -> Some (id,pos)
      | _ -> None
      ]
    else None
  | `sprite children cNum when DynArray.length children > cNum + offset -> 
      match DynArray.get children (cNum + offset) with
      [ `chld (id,_,pos) -> Some (id,pos)
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
    let add_children = DynArray.iter (fun [ `chld (id,_,_) -> HSet.add imgUsage id | _ -> ()]) in
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
      [ `chld (id1,label,pos1) ->
        match  (DynArray.get items id1).item with
        [ `image texInfo1 when not (HSet.mem alredySeen id1) ->
          let () = HSet.add alredySeen id1 in
          match DynArray.get children (!i + 1) with
          [ `chld (id2,_,pos2) ->
            match (DynArray.get items id2).item with
            [ `image texInfo2 ->
              let rect1 = Rectangle.create pos1.x pos1.y (float texInfo1.width) (float texInfo1.height)
              and rect2 = Rectangle.create pos2.x pos2.y (float texInfo2.width) (float texInfo2.height) in
              if not (Rectangle.isIntersect rect1 rect2)
              then ()
              else
(*                 let () = Printf.printf "fineded intersect images: [%s] and [%s] \n" (string_of_address (makeAddr !i)) (string_of_address (makeAddr (!i+1))) in *)
                let dx = pos1.x -. pos2.x
                and dy = pos1.y -. pos2.y in
                let usage = usageFrom (makeAddr (!i+2)) id1 in
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
                  (
                    has_changes.val := True;
(*                     Printf.printf "merge %d and %d for (%s)\n%!" id1 id2 (String.concat ";" (List.map (fun (addr,pos) -> Printf.sprintf "[%s]" (string_of_address addr)) places)); *)
                    (* надо найти самое длинное *)
                    let cNum = DynArray.length children in
                    let rec findMaxOffset rect offset = (*{{{*)
                      if !i + offset + 1 < cNum 
                      then
                        match DynArray.get children (!i + offset + 1) with
                        [ `chld (id,_,pos) ->
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
                              then findMaxOffset (Rectangle.join rect rect') (offset + 1) 
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
                          [ `chld (id,_,pos) ->
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
                          DynArray.insert children !i (`chld (id1,label,{x=rect.(0);y=rect.(1)})); (* FIXME: label skipped *)
                          let dx = pos1.x -. rect.(0)
                          and dy = pos1.y -. rect.(1) in
                          (* А теперь все вхождения пореплейсить нахуй *)
                          List.iter begin fun ((_,el),pos) ->
                            let gpos = {x= pos.x -. dx; y = pos.y -. dy} in
                            match el with
                            [ `sprite children cNum ->
                              (
                                DynArray.delete_range children cNum (maxOffset + 1);
                                DynArray.insert children cNum (`chld (id1,None,gpos)); (* FIXME: fix label *)
                              )
                            | `clip frames fNum cNum ->
                                let frame = DynArray.get frames fNum in
                                (
                                  DynArray.delete_range frame.children cNum (maxOffset + 1);
                                  DynArray.insert frame.children cNum (`chld (id1,None,gpos));
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
    [ `sprite children -> mergeChildren (fun cNum -> (el.item_id,`sprite children cNum)) children
    | `clip frames ->
        let makeAddr fNum cNum = (el.item_id,`clip frames fNum cNum) in
        for fi = 0 to DynArray.length frames - 1 do
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
(*}}}*)


value optimize_sprites () = 
  for i = 0 to DynArray.length exports - 1 do
    let (name,id) = DynArray.get exports i in
    let item = DynArray.get items id in
    match item.item with
    [ `sprite children -> 
      if DynArray.length children = 1 (* если тут один чайлд - то это просто картинка *)
      then 
        match DynArray.get children 0 with
        [ `chld (id,_,pos) when pos.x = 0. && pos.y = 0. -> 
          (
            DynArray.set exports i (name,id); (* FIXME: check pos *)
            item.deleted := True;
          )
        | `chld _ -> () 
        | _ -> assert False 
        ]
      else ()
    | _ -> ()
    ]
  done;


value is_simple_clip frames = 
  try
    for fi = 0 to DynArray.length frames - 1 do
      let f = DynArray.get frames fi in
      if DynArray.length f.children > 1 
      then raise Exit
      else ()
    done;
    True;
  with [ Exit -> False ];


value make_clip_commands () = 
  for i = 0 to DynArray.length items - 1 do
    match DynArray.get items i with
    [ {item_id=id;item=`clip frames;_} when not (is_simple_clip frames) ->
      (
        let fframe = DynArray.get frames 0 in
        let pchildren = ref (DynArray.copy fframe.children) in
        for f = 1 to DynArray.length frames - 1 do
          let frame = DynArray.get frames f in
          let commands = DynArray.create () in
          let len = DynArray.length frame.children in 
          (
            for c = 0 to len - 1 do
              match DynArray.get frame.children c with
              [ `chld ((id,_,pos) as child) ->
                try
                  let pidx = DynArray.index_of (fun [ `chld (id',_,pos) -> id' = id | _ -> assert False ]) !pchildren  in
                  match DynArray.get !pchildren pidx with
                  [ `chld (_,_,pos') ->
                    let changes = if pidx <> 0 then [ `move c ] else [] in
                    let changes = if pos.x <> pos'.x then [ `posX pos.x :: changes ] else changes in
                    let changes = if pos.y <> pos'.y then [ `posY pos.y :: changes ] else changes in
                    (
                      DynArray.delete !pchildren pidx;
                      match changes with
                      [ [] -> ()
                      | changes -> DynArray.add commands (ClpChange (pidx + c,changes)) 
                      ]
                    )
                  | _ -> assert False
                  ]
                with [ Not_found -> DynArray.add commands (ClpPlace (c,child)) ]
              | _ -> prerr_endline "boxes not supported in clips yeat"
              ]
            done;
            (* еще удалить надо *)
            let clen = DynArray.length !pchildren in
            if clen > 0 
            then
              DynArray.add commands (ClpClear len clen)
            else ();
            frame.commands := Some commands;
            pchildren.val := DynArray.copy frame.children;
          )
        done;
      )
    | _ -> ()
    ]
  done;

value indir = ref "input";
value outdir = ref "output";


value group_images () = 
  for i = 0 to DynArray.length exports do

  done;

value images_by_symbols () =
  let imgs = 
    DynArray.fold_left begin fun res (_,id) ->
      let item = DynArray.get items id in
      match item.item with
      [ `image _ -> [ [ (item.item_id,(Hashtbl.find images item.item_id)) ] :: res ]
      | `sprite children ->
          let imgs = 
            DynArray.fold_left begin fun res child ->
              match child with
              [ `chld (id,_,_) ->
                match (DynArray.get items id).item with
                [ `image _ -> [ (id,Hashtbl.find images id) :: res ]
                | _ -> assert False
                ]
              | _ -> res
              ]
            end [] children
          in
          [ imgs :: res ]
      | `clip frames ->
          let imgs = 
            DynArray.fold_left begin fun res frame ->
              DynArray.fold_left begin fun res -> fun
                [ `chld (id,_,_) ->
                  match (DynArray.get items id).item with
                  [ `image _ -> [ (id,Hashtbl.find images id) :: res ]
                  | _ -> assert False
                  ]
                | _ -> res
                ]
              end res frame.children
            end [] frames
          in
          [ imgs :: res ]
      ]
    end [] exports
  in
  merge imgs [] where
    rec merge imgs res =
      match imgs with
      [ [] -> res
      |  [ imgs :: rest ] ->
          let (commons,others) = 
            List.partition begin fun imgs' ->
              List.exists begin fun (id,_) ->
                List.exists (fun (id',_) -> id = id') imgs'
              end imgs
            end rest
          in
          merge others [ imgs @ (List.concat commons) :: res ]
      ]
;

type fmt = [ FPng | FPvr | FPlx of string ];

value do_work isXml separate fmt indir suffix outdir =
(
  Printf.printf "DOWORK: %s -> %s[%s]\n%!" indir outdir suffix;
  Array.iter begin fun fl ->
    let dirname = indir // fl in
    let (name,item_id) = 
      if Sys.is_directory dirname
      then (fl,process_dir dirname)
      else 
        let item_id = add_image dirname in
        (Filename.chop_extension fl,item_id)
    in
    DynArray.add exports (name,item_id)
  end (Sys.readdir indir);
  merge_images();
  optimize_sprites();
  make_clip_commands ();
  let pack_textures starts_with images = 
    let pages = TextureLayout.layout ~type_rects:`maxrect ~sqr:(fmt = FPvr) images in
    List.mapi begin fun i (w,h,imgs) ->
      let idx = i + starts_with in
      let texture = Rgba32.make w h bgcolor in
      (
        List.iter begin fun (key,(x,y,_,img)) ->
        (
          let img = match img with [ Images.Rgba32 img -> img | Images.Rgb24 img -> Rgb24.to_rgba32 img | _ -> assert False ] in
          Rgba32.blit img 0 0 texture x y img.Rgba32.width img.Rgba32.height;
          match (DynArray.get items key).item with
          [ `image inf -> ( inf.tx := x; inf.ty := y; inf.page := idx)
          | _ -> assert False
          ]
        )
        end imgs;
        let imgbasename = Printf.sprintf "%d%s" idx suffix in 
        let imgname = imgbasename ^ ".png"  in
        (
          Images.save (outdir // imgname) (Some Images.Png) [] (Images.Rgba32 texture);
          match fmt with
          [ FPvr -> Utils.pvr_png (outdir // imgbasename)
          | FPlx plt -> Utils.plx_png plt (outdir // imgbasename)
          | FPng -> ()
          ];
          imgname;
        )
      )
    end pages
  in
  let textures = 
    match separate with
    [ True -> 
      let images = images_by_symbols () in
        List.fold_left begin fun res images ->
          let textures = pack_textures (List.length res) images in
          res @ textures
        end [] images
    | False ->
        let images = Hashtbl.fold (fun id img res -> [ (id,img) :: res ]) images [] in
        pack_textures 0 images
    ]
  in
  let group_children children = 
    let qchld = Stack.create () in
    (
      DynArray.iter begin fun 
        [ `chld _ as chld when Stack.is_empty qchld -> Stack.push chld qchld
        | `chld img as chld -> 
            match Stack.pop qchld with
            [ `chld pimg -> Stack.push (`atlas [ img ; pimg ]) qchld
            | `atlas els -> Stack.push (`atlas [ img :: els ]) qchld
            | `box _ as b -> (Stack.push b qchld; Stack.push chld qchld)
            ]
        | `box _ as b -> Stack.push b qchld
        ]
      end children;
      let res = RefList.empty () in
      (
        Stack.iter begin fun 
          [ `atlas els -> RefList.push res (`atlas (List.rev els))
          | _ as el -> RefList.push res el
          ]
        end qchld;
        RefList.to_list res;
      )
    )
  in
  match isXml with
  [ True -> (*{{{*)
    (* Теперича сохранить xml и усе *)
    let out = open_out (outdir // (Printf.sprintf "lib%s.xml" suffix)) in
    let xmlout = Xmlm.make_output ~indent:(Some 2) (`Channel out) in
    (
      Xmlm.output xmlout (`Dtd None);
      Xmlm.output xmlout (`El_start (("","lib"),[]));
      Xmlm.output xmlout (`El_start (("","textures"),[])); 
      List.iter (fun imgname -> (Xmlm.output xmlout (`El_start (("","texture"),["file" =|= imgname])); Xmlm.output xmlout `El_end)) textures;
      Xmlm.output xmlout `El_end;
      Xmlm.output xmlout (`El_start (("","items"),[]));(* write items {{{ *)
      let write_child (id,name,pos) =
        (
          let attrs = [ "id" =*= id; "posX" =.= pos.x; "posY" =.= pos.y ] in
          let attrs = match name with [ Some n -> [ "name" =|= n :: attrs ] | None -> attrs ] in
          Xmlm.output xmlout (`El_start (("","child"),attrs));
          Xmlm.output xmlout `El_end
        )
      in
      let write_sprite_children children = 
        List.iter begin fun 
          [ `chld params -> write_child params
          | `box (pos,name) ->
            (
              Xmlm.output xmlout (`El_start (("","box"),[ "posX" =.= pos.x; "posY" =.= pos.y; "name" =|= name ]));
              Xmlm.output xmlout `El_end
            )
          | `atlas els -> 
            (
              Xmlm.output xmlout (`El_start (("","atlas"),[]));
              List.iter write_child els;
              Xmlm.output xmlout `El_end;
            )
          ]
        end (group_children children)
      in
      DynArray.iter begin fun 
        [ {item_id=id;item;deleted=False} -> (*{{{*)
          match item with
          [ `image info when Hashtbl.mem images id -> 
            (
              let attributes = 
                [
                  "type" =|= "image";
                  "texture" =*= info.page;
                  "x" =*= info.tx;
                  "y" =*= info.ty;
                  "width" =*= info.width;
                  "height" =*= info.height
                ]
              in
              Xmlm.output xmlout (`El_start (("","item"),[ "id" =*= id :: attributes ]));
              Xmlm.output xmlout `El_end;
            )
          | `sprite children ->
            (
              Xmlm.output xmlout (`El_start (("","item"),[ "id" =*= id ; "type" =|= "sprite" ]));
              write_sprite_children children;
              Xmlm.output xmlout `El_end;
            )
          | `clip frames when is_simple_clip frames ->
              (
                Xmlm.output xmlout (`El_start (("","item"),[ "id" =*= id ; "type" =|= "iclip" ]));
                DynArray.iter begin fun frame ->
                  (
                    let attrs = [ "duration" =*= frame.duration ] in 
                    let attrs = match frame.label with [ Some l -> [ "label" =|= l :: attrs ] | None -> attrs ] in
                    let imgattrs = 
                      match DynArray.get frame.children 0 with 
                      [ `chld (id,_,pos) -> [ "img" =*= id; "posX" =.= pos.x; "posY" =.= pos.y ]
                      | _ -> assert False
                      ]
                    in
                    Xmlm.output xmlout (`El_start (("","frame"),attrs @ imgattrs));
                    Xmlm.output xmlout `El_end;
                  )
                end frames;
                Xmlm.output xmlout `El_end;
              )
          | `clip frames ->
            (
              Xmlm.output xmlout (`El_start (("","item"),[ "id" =*= id ; "type" =|= "clip" ]));
              DynArray.iter begin fun frame ->
                (
                  let attrs = [ "duration" =*= frame.duration ] in 
                  let attrs = match frame.label with [ Some l -> [ "label" =|= l :: attrs ] | None -> attrs ] in
                  Xmlm.output xmlout (`El_start (("","frame"),attrs));
                  Xmlm.output xmlout (`El_start (("","children"),[]));
                  DynArray.iter (fun [ `chld params -> write_child params | `box _ -> assert False ]) frame.children;
                  Xmlm.output xmlout `El_end;
                  match frame.commands with
                  [ Some commands ->
                    (
                      Xmlm.output xmlout (`El_start (("","commands"),[]));
                      DynArray.iter begin fun
                        [ ClpPlace (idx,(id,name,pos)) ->
                          (
                            let attrs = [ "idx" =*= idx; "id" =*= id; "posX" =.= pos.x; "posY" =.= pos.y ] in
                            let attrs = match name with [ Some n -> [ "name" =|= n :: attrs ] | None -> attrs ] in
                            Xmlm.output xmlout (`El_start (("","place"),attrs));
                            Xmlm.output xmlout `El_end;
                          )
                        | ClpClear from count -> 
                          (
                            Xmlm.output xmlout (`El_start (("","clear-from"),[ "idx" =*= from; "count" =*= count ]));
                            Xmlm.output xmlout `El_end
                          )
                        | ClpChange idx changes -> 
                          (
                            let changes = 
                              List.map begin fun
                                [ `move z -> "move" =*= z
                                | `posX x -> "posX" =.= x
                                | `posY y -> "posY" =.= y
                                ]
                              end changes
                            in
                            Xmlm.output xmlout (`El_start (("","change"),["idx" =*= idx :: changes ]));
                            Xmlm.output xmlout `El_end;
                          )
                        ] 
                      end commands;
                      Xmlm.output xmlout `El_end;
                    )
                  | None -> ()
                  ];
                  Xmlm.output xmlout `El_end;
                )
              end frames;
              Xmlm.output xmlout `El_end;
            )
          | _ -> ()
          ]
        | _ -> ()
        ]
      end items;(*}}}*)
      Xmlm.output xmlout `El_end;(*}}}*)
      Xmlm.output xmlout (`El_start (("","symbols"),[])); (* write symbols {{{*)
      DynArray.iter begin fun (cls,id) ->
        (
          Xmlm.output xmlout (`El_start (("","symbol"),[ "class" =|= cls; "id" =*= id ]));
          Xmlm.output xmlout `El_end;
        )
      end exports;
      Xmlm.output xmlout `El_end;(*}}}*)
      Xmlm.output xmlout `El_end;
      close_out out;
    )(*}}}*) 
  | False -> (*{{{*)
    let out = open_out (outdir // (Printf.sprintf "lib%s.bin" suffix)) in
    let binout = IO.output_channel out in
    let write_option_string = fun
      [ Some name -> 
        (
          IO.write_byte binout (String.length name);
          IO.nwrite binout name;
        )
      | None -> IO.write_byte binout 0
      ]
    in
    let nreg = Str.regexp "^instance[0-9]+$" in
    let write_name = fun
      [ Some name when Str.string_match nreg name 0 -> IO.write_byte binout 0
      | Some name ->
        (
          IO.write_byte binout (String.length name);
          IO.nwrite binout name;
        )
      | None -> IO.write_byte binout 0
      ]
    in
    (
      IO.write_ui16 binout (List.length textures);
      List.iter (fun imgname -> IO.write_string binout imgname) textures;
      let cnt_items = 
        DynArray.fold_left begin fun cnt it -> 
          if it.deleted then cnt
          else
            match it.item with 
            [ `image _ when not (Hashtbl.mem images it.item_id) -> cnt 
            | _ -> cnt + 1 
            ]
        end 0 items 
      in
      IO.write_ui16 binout cnt_items;
      let write_child (id,name,pos) =
        (
          IO.write_ui16 binout id;
          IO.write_double binout pos.x;
          IO.write_double binout pos.y;
          write_name name;
        )
      in
      let write_sprite_children children = 
        let children = group_children children in
        let () = IO.write_byte binout (List.length children) in
        List.iter begin fun 
          [ `chld params -> 
            (
              IO.write_byte binout 0;
              write_child params
            )
          | `box (pos,name) ->
            (
              IO.write_byte binout 2;
              IO.write_double binout pos.x;
              IO.write_double binout pos.y;
              IO.write_string binout name;
            )
          | `atlas els -> 
            (
              IO.write_byte binout 1;
              IO.write_byte binout (List.length els);
              List.iter write_child els;
            )
          ]
        end children
      in
      let write_children children = 
        let () = IO.write_byte binout (DynArray.length children) in
        DynArray.iter begin fun 
          [ `chld (id,name,pos) ->
            (
              IO.write_ui16 binout id;
              IO.write_double binout pos.x;
              IO.write_double binout pos.y;
              write_name name;
            )
          | `box (pos,name)-> assert False
          ]
        end children
      in
      DynArray.iter begin fun 
        [ {item_id=id;item;deleted=False} ->
          match item with
          [ `image info when Hashtbl.mem images id ->
            (
              IO.write_ui16 binout id;
              IO.write_byte binout 0; (* this is image *)
              IO.write_ui16 binout info.page;
              IO.write_ui16 binout info.tx;
              IO.write_ui16 binout info.ty;
              IO.write_ui16 binout info.width;
              IO.write_ui16 binout info.height;
            )
          | `sprite children ->
            (
              IO.write_ui16 binout id;
              IO.write_byte binout 1;
              write_sprite_children children;
            )
          | `clip frames when is_simple_clip frames ->
            (
              IO.write_ui16 binout id;
              IO.write_byte binout 2;
              IO.write_ui16 binout (DynArray.length frames);
              DynArray.iter begin fun frame ->
                (
                  IO.write_byte binout frame.duration;
                  write_option_string frame.label;
                  match DynArray.get frame.children 0 with
                  [ `chld (id,name,pos) -> 
                    (
                      IO.write_ui16 binout id;
                      IO.write_double binout pos.x;
                      IO.write_double binout pos.y;
                    )
                  | _ -> assert False
                  ]
                )
              end frames
            )
          | `clip frames ->
            (
              IO.write_ui16 binout id;
              IO.write_byte binout 3;
              IO.write_ui16 binout (DynArray.length frames);
              DynArray.iter begin fun frame ->
                (
                  IO.write_byte binout frame.duration;
                  write_option_string frame.label;
                  write_children frame.children;
                  match frame.commands with
                  [ None -> IO.write_byte binout 0
                  | Some commands ->
                    (
                      IO.write_byte binout 1;
                      IO.write_ui16 binout (DynArray.length commands);
                      DynArray.iter begin fun
                        [ ClpPlace (idx,(id,name,pos)) ->
                          (
                            IO.write_byte binout 0;
                            IO.write_ui16 binout idx;
                            IO.write_ui16 binout id;
                            write_name name;
                            IO.write_double binout pos.x;
                            IO.write_double binout pos.y;
                          )
                        | ClpClear from count ->
                          (
                            IO.write_byte binout 1;
                            IO.write_ui16 binout from;
                            IO.write_ui16 binout count;
                          )
                        | ClpChange idx changes ->
                          (
                            IO.write_byte binout 2;
                            IO.write_ui16 binout idx;
                            IO.write_byte binout (List.length changes);
                            List.iter begin fun
                              [ `move z -> (IO.write_byte binout 0; IO.write_ui16 binout z)
                              | `posX x -> (IO.write_byte binout 1; IO.write_double binout x)
                              | `posY y -> (IO.write_byte binout 2; IO.write_double binout y)
                              ]
                            end changes;
                          )
                        ]
                      end commands
                    )
                  ]
                )
              end frames;
            )
          | _ -> ()
          ]
        | _ -> ()
        ]
      end items;
      IO.write_ui16 binout (DynArray.length exports);
      DynArray.iter begin fun (cls,id) ->
        (
          IO.write_string binout cls;
          IO.write_ui16 binout id;
        )
      end exports;
      close_out out;
    ) (*}}}*)
  ];
);

value () = 
  let xml = ref False in
  let separate = ref False in
  let pvr = ref False in
  let plt = ref None in
  let libs = ref [] in
  let maxt_size = ref (!TextureLayout.max_size) in
  let p_maxt_sizes = ref [] in
  (
    Arg.parse 
      [ 
        ("-i",Arg.Set_string indir,"input directory") ; 
        ("-o",Arg.Set_string outdir,"output directory") ; 
        ("-xml",Arg.Set xml, "lib in xml format") ; 
        ("-sep",Arg.Set separate,"each symbol in separate texture");
        ("-maxt",Arg.Int (fun v -> maxt_size.val := v),"max texture size");
        ("-pvr",Arg.Set pvr,"make pvr");
        ("-plt",Arg.String (fun s -> plt.val := Some s),"make pallete textures");
        ("-pmaxt",
          Arg.Tuple 
            [
              Arg.String (fun pname -> p_maxt_sizes.val := [ (pname,0) :: !p_maxt_sizes]); 
              Arg.Int (fun s -> p_maxt_sizes.val := [ (fst (List.hd !p_maxt_sizes),s) :: (List.tl !p_maxt_sizes)] )
            ],
          "tex size for concrete profile"
        )
      ] 
      (fun id -> libs.val := [id :: !libs]) "usage msg";
    match !libs with
    [ [] -> failwith "need some libs"
    | libs -> 
      (
        List.iter begin fun lib ->
          let outd = !outdir // lib in
          (
            if Sys.file_exists outd  
            then 
            (
              match Sys.command (Printf.sprintf "rm -rf %s" outd) with
              [ 0 -> ()
              | n -> failwith (Printf.sprintf "Can't delete %s" outd)
              ];
            )
            else ();
            Unix.mkdir outd 0o755;
          )
        end libs;
        TextureLayout.rotate.val := False;
        let fmt = 
          match !pvr with
          [ True -> 
            match !plt with
            [ None -> FPvr
            | Some _ -> failwith "It's wrong to make both pvr and plx"
            ]
          | False ->
              match !plt with
              [ Some plt -> FPlx plt
              | None -> FPng
              ]
          ]
        in
        Array.iter begin fun profile ->
          List.iter begin fun lib ->
            let indir = !indir // profile // lib in
            if Sys.file_exists indir
            then 
              (
                let maxt_size = 
                  try
                    List.assoc profile !p_maxt_sizes
                  with [ Not_found -> !maxt_size ] in
                TextureLayout.max_size.val := maxt_size;
                let suffix = match profile with [ "default" -> "" | _ -> profile ]
                and outdir = !outdir // lib in
                do_work !xml !separate fmt indir suffix outdir;
                (* нужно за собой прибраца *)
                Hashtbl.clear images;
                DynArray.clear items;
                DynArray.clear exports;
              )
            else ()
          end libs
        end (Sys.readdir !indir);
      )
    ]
  );

(*
----
<lib>
<textures><texture file=""/></textures>
<items>
<item id="1" type="image" texture="0" x="" y="" width="" height=""/>
<item id="2"
<item id="2" type="sprite">
  <child id="3" xPos="" yPos=""/>
  <child id="4" xPos="" yPos=""/>
</item>
<item id="10" type="clip">
<frame duration="" posX="" posY="" item="3">
<child id=2 posX posY/>
</frame>
<frame duration="" posX="" posY="" item="3"/>
<frame duration="" posX="" posY="" item="3"/>
</item>
<exports>
<export class="ESkins.Bg_Exp" item="2"/>
</exports>
</lib>
----
*)
