(* Скрипт пакует данные swf потрошителя *)
open ExtList;
open ExtString;
open Printf;

value (//) = Filename.concat;
value (=|=) k v = (("",k),v);
value (=.=) k v = k =|= string_of_float v;
value (=*=) k v = k =|= string_of_int v;

value bgcolor = {Color.color = {Color.r = 0; g = 0; b = 0}; alpha = 0};

(* схлопним хуйню *)



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
type children = DynArray.t (int * option string * pos);
type frame = {children:children; label: option string; duration: mutable int};
type item = [= `image of texinfo | `sprite of children | `clip of DynArray.t frame ];
type iteminfo = (int * item);

value items : DynArray.t iteminfo = DynArray.create ();

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
    DynArray.index_of (fun (_,i) -> match i with [ `image _ -> False | (`sprite _ | `clip _ ) as el -> compare_item el item]) items
    (*
    match item with
    [ `sprite _ | `clip _ -> DynArray.index_of (fun (_,i) -> compare_item i item) items
    | `image _ -> raise Not_found
    ]
    *)
  with 
  [ Not_found ->
    (
      DynArray.add items (DynArray.length items,(item :> item));
      (DynArray.length items) - 1;
    )
  ];

value images = Hashtbl.create 11;


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
    DynArray.add items (id,(`image {page=0;tx=0;ty=0;width;height}));
    Hashtbl.add images id img;
    id
  );
  with [ Finded id -> id ];


value add_child_image  dirname mobj = 
  let path = dirname // (Json_type.Browse.string (List.assoc "file" mobj)) in
  add_image path;

value getpos jsinfo = let open Json_type.Browse in {x=number (List.assoc "x" jsinfo);y=number (List.assoc "y" jsinfo)};

(* можно при добавлении картинок палить что они такие-же только разница в альфе - это легко 
 * а в группировке есть засада, что мы можем не понять что это одно и тоже так как мы с чем-то слепим и будет не круто
 * *)

(* value calc_diff oldchildrens newchildrens =  *)

value rec process_children dirname children = 
  let open Json_type.Browse in
  let lst = 
    list begin fun child ->
      let child = objekt child in
      let name = try Some (string (List.assoc "name" child)) with [ Not_found -> None ] in
      let pos = getpos child in
      let id = 
        match string (List.assoc "type" child) with
        [ "image" -> add_child_image dirname child
        | "clip" | "sprite" -> process_dir (dirname // (string (List.assoc "dir" child)))
        | _ -> assert False
        ]
      in
      (id,name,pos)
    end children
  in
  DynArray.of_list lst
and process_dir dirname = (* найти мету в этой директории и от нее плясать *)
  let () = printf "process directory: %s\n%!" dirname in
  let meta = Json_io.load_json (dirname // "meta.json") in
  let open Json_type.Browse in
  let mobj = objekt meta in
  match string (List.assoc "type" mobj) with
  [ "image" -> add_child_image dirname mobj
  | "sprite" -> 
      let children = process_children dirname (List.assoc "children" mobj) in
      push_item (`sprite children)
  | "clip" ->
      let lframes = 
        list begin fun frame ->
          let frame = objekt frame in 
          let label = try Some (string (List.assoc "label" frame)) with [ Not_found -> None ] in
          let children = process_children dirname (List.assoc "children" frame) in
          {label;children;duration=1}
        end (List.assoc "frames" mobj)
      in
      (* вычислим duration *)
      (* FIXME: придумать сдесь механизм изменений *)
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




value isImagesIntersect (id1,(x1,y1)) (id2,(x2,y2)) =
  match snd (DynArray.get items id1) with
  [ `image texInfo1 -> 
    match snd (DynArray.get items id2) with
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
          [ (id',_,pos) when id' = id -> (i,pos)
          | _ -> findChildren (i+1)
          ]
        else raise Next
      in
      findChildren from
    in
    match addr with
    [ `sprite children cNum -> 
      try 
        let (cNum,pos) = findInChildren children (cNum + 1) in
        ((elid,`sprite children cNum),pos)
      with [ Next -> nextElement elid ]
    | `clip frames fNum cNum ->
        let numFrames = DynArray.length frames in
        let rec findInFrame fi si =
          if numFrames > fi
          then 
            let frame = DynArray.get frames fi in
            try 
              let (cNum,pos) = findInChildren frame.children si in
              ((elid,`clip frames fi cNum),pos)
            with [ Next -> findInFrame (fi + 1) 0 ]
          else nextElement elid
        in
        findInFrame fNum (cNum + 1)
    ] (*}}}*)
  and nextElement (elid:int) = (*{{{*)
    let nid = elid + 1 in
    if nid >= DynArray.length items
    then raise Enum.No_more_elements
    else 
      let nel = DynArray.get items nid in
      try
        let addr = 
          match snd nel with
          [ `sprite children -> `sprite children 0
          | `clip frames -> `clip frames 0 0 
          | `image _ -> raise Next
          ]
        in
        findElement (nid,addr)
      with [ Next -> nextElement nid ]
    in
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
      let (id,_,pos) = DynArray.get frame.children (cNum + offset) in
      Some (id,pos)
    else None
  | `sprite children cNum when DynArray.length children > cNum + offset -> 
      let (id,_,pos) = DynArray.get children (cNum + offset) in
      Some (id,pos)
  | _ -> None
  ];

value string_of_address (id,el) =
  match el with
  [ `sprite _ cNum -> Printf.sprintf "sprite: %d:%d" id cNum
  | `clip _ fNum cNum -> Printf.sprintf "clip: %d:%d:%d" id fNum cNum
  ];

value merge_images () = 
  let alredySeen = HSet.create 1 in
  (* проще выписать как-то все пересекающиеся области нахуй *)
  let removed_img = Hashtbl.create 0 in
  let rec mergeChildren makeAddr (children:children)  = 
    let i = ref 0 in
    while !i < DynArray.length children - 1 do
      let (id1,label,pos1) = DynArray.get children !i in
      match DynArray.get items id1 with
      [ (_,`image texInfo1) when not (HSet.mem alredySeen id1) ->
        let () = HSet.add alredySeen id1 in
        let (id2,_,pos2) = DynArray.get children (!i + 1) in
        match DynArray.get items id2 with
        [ (_,`image texInfo2) ->
          let rect1 = Rectangle.create pos1.x pos1.y (float texInfo1.width) (float texInfo1.height)
          and rect2 = Rectangle.create pos2.x pos2.y (float texInfo2.width) (float texInfo2.height) in
          if not (Rectangle.isIntersect rect1 rect2)
          then ()
          else
            let () = Printf.printf "fineded intersect images: [%s] and [%s] \n" (string_of_address (makeAddr !i)) (string_of_address (makeAddr (!i+1))) in
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
                Printf.printf "merge %d and %d for (%s)\n%!" id1 id2 (String.concat ";" (List.map (fun (addr,pos) -> Printf.sprintf "[%s]" (string_of_address addr)) places));
                (* надо найти самое длинное *)
                let cNum = DynArray.length children in
                let rec findMaxOffset rect offset = (*{{{*)
                  if !i + offset + 1 < cNum 
                  then
                    let (id,_,pos) = DynArray.get children (!i + offset + 1) in
                    match snd (DynArray.get items id) with
                    [ `image texInfo ->
                      let rect' = Rectangle.create pos.x pos.y (float texInfo.width) (float texInfo.height) in
                      if not (Rectangle.isIntersect rect rect')
                      then 
                        let () = print_endline "does not intersect, stop find offset" in
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
                          let () = print_endline "not all distances are same, stop find offset" in
                          offset
                    | _ -> 
                        let () = print_endline "does not image, stop find offset" in
                        offset 
                    ]
                  else 
                    let () = print_endline "end of childrens, stop find offset" in
                    offset  (*}}}*)
                in
                let maxOffset = findMaxOffset (Rectangle.join rect1 rect2) 1 in
                (
                  Printf.printf "maxOffset %d\n%!" maxOffset;
                  (* здесь схлопываем нахуй *)
                  let imgs = 
                    Array.init (maxOffset + 1) begin fun offset -> 
                      let (id,_,pos) = DynArray.get children (!i + offset) in
                      let () = Printf.printf "get image: %d\n%!" id in
                      let img =
                        try
                          Hashtbl.find images id 
                        with
                          [ Not_found -> Hashtbl.find removed_img id ]
                      in
                      (
                        Hashtbl.add removed_img id img;
                        Hashtbl.remove images id;
                        (id,img,pos)
                      )
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
                      DynArray.set items id1 (id1,`image {(texInfo1) with width = gwidth; height = gheight});
                      DynArray.delete_range children !i (maxOffset+1);
                      DynArray.insert children !i (id1,label,{x=rect.(0);y=rect.(1)}); (* FIXME: label skipped *)
                      let dx = pos1.x -. rect.(0)
                      and dy = pos1.y -. rect.(1) in
                      (* А теперь все вхождения пореплейсить нахуй *)
                      List.iter begin fun ((_,el),pos) ->
                        let gpos = {x= pos.x -. dx; y = pos.y -. dy} in
                        match el with
                        [ `sprite children cNum ->
                          (
                            DynArray.delete_range children cNum (maxOffset + 1);
                            DynArray.insert children cNum (id1,Some "pizda",gpos); (* FIXME: fix label *)
                          )
                        | `clip frames fNum cNum ->
                            let frame = DynArray.get frames fNum in
                            (
                              DynArray.delete_range frame.children cNum (maxOffset + 1);
                              DynArray.insert frame.children cNum (id1,Some "pizda",gpos);
                            )
                        ]
                      end places;
                    )
                  );
                  (* вычислить смещения ебучие *)
                )
              )
            | None -> ()
            ] (*}}}*)
        | _ -> ()
        ]
      | _ -> ()
      ];
      incr i;
    done
  in
  for i = 0 to (DynArray.length items - 1) do
    let (elid,el) = DynArray.get items i in
    match el with
    [ `sprite children -> mergeChildren (fun cNum -> (elid,`sprite children cNum)) children
    | `clip frames ->
        let makeAddr fNum cNum = (elid,`clip frames fNum cNum) in
        for fi = 0 to DynArray.length frames - 1 do
          let frame = DynArray.get frames fi in
          mergeChildren (makeAddr fi) frame.children
        done
    | `image _ -> ()
    ]
  done;

value outdir = ref "output";

value do_work indir =
  let exports = RefList.empty () in
  (
    Array.iter begin fun fl ->
      let dirname = indir // fl in
      let (name,item_id) = 
        if Sys.is_directory dirname
        then (fl,process_dir dirname)
        else 
          let item_id = add_image dirname in
          (Filename.chop_extension fl,item_id)
      in
      RefList.push exports (name,item_id)
    end (Sys.readdir indir);
    merge_images();
    let outdir = !outdir // (Filename.basename indir) in
    let () = printf "output to %s\n%!" outdir in
    (
      if Sys.file_exists outdir 
      then 
        match Sys.command (Printf.sprintf "rm -rf %s" outdir) with
        [ 0 ->  ()
        | n -> exit n
        ]
      else ();
      Unix.mkdir outdir 0o755;
      (* Теперича сохранить xml и усе *)
      let out = open_out (outdir // "lib.xml") in
      let xmlout = Xmlm.make_output ~indent:(Some 2) (`Channel out) in
      (
        Xmlm.output xmlout (`Dtd None);
        Xmlm.output xmlout (`El_start (("","lib"),[]));
        Xmlm.output xmlout (`El_start (("","textures"),[])); (* write textures {{{*)
        let images = Hashtbl.fold (fun id img res -> [ (id,img) :: res ]) images [] in
        let pages = TextureLayout.layout ~type_rects:`rand images in
        List.iteri begin fun i (w,h,imgs) ->
          let texture = Rgba32.make w h bgcolor in
          (
            List.iter begin fun (key,(x,y,img)) ->
            (
              let img = match img with [ Images.Rgba32 img -> img | _ -> assert False ] in
              Rgba32.blit img 0 0 texture x y img.Rgba32.width img.Rgba32.height;
              match DynArray.get items key with
              [ (_,`image inf) -> ( inf.tx := x; inf.ty := y; inf.page := i;)
              | _ -> assert False
              ]
            )
            end imgs;
            let imgname = Printf.sprintf "%d.png" i in
            (
              Images.save (outdir // imgname) (Some Images.Png) [] (Images.Rgba32 texture);
              Xmlm.output xmlout (`El_start (("","texture"),["file" =|= imgname]));
              Xmlm.output xmlout `El_end;
            )
          )
        end pages;
        Xmlm.output xmlout `El_end;(*}}}*)
        Xmlm.output xmlout (`El_start (("","items"),[]));(* write items {{{ *)
        let write_children : children -> unit = 
          DynArray.iter begin fun (id,name,pos) ->
            (
              let attrs = [ "id" =*= id; "posX" =.= pos.x; "posY" =.= pos.y ] in
              let attrs = match name with [ Some n -> [ "name" =|= n :: attrs ] | None -> attrs ] in
              Xmlm.output xmlout (`El_start (("","child"),attrs));
              Xmlm.output xmlout `El_end;
            )
          end 
        in
        DynArray.iter begin fun (id,item) -> 
          (
            match item with
            [ `image info -> 
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
              Xmlm.output xmlout (`El_start (("","item"),[ "id" =*= id :: attributes ]))
            | `sprite children ->
              (
                Xmlm.output xmlout (`El_start (("","item"),[ "id" =*= id ; "type" =|= "sprite" ]));
                write_children children;
              )
            | `clip frames ->
              (
                Xmlm.output xmlout (`El_start (("","item"),[ "id" =*= id ; "type" =|= "clip" ]));
                DynArray.iter begin fun frame ->
                  (
                    let attrs = [ "duration" =*= frame.duration ] in 
                    let attrs = match frame.label with [ Some l -> [ "label" =|= l :: attrs ] | None -> attrs ] in
                    Xmlm.output xmlout (`El_start (("","frame"),attrs));
                    write_children frame.children;
                    Xmlm.output xmlout `El_end;
                  )
                end frames;
              )
            ];
            Xmlm.output xmlout `El_end;
          )
        end items;
        Xmlm.output xmlout `El_end;(*}}}*)
        Xmlm.output xmlout (`El_start (("","symbols"),[])); (* write symbols {{{*)
        RefList.iter begin fun (cls,id) ->
          (
            Xmlm.output xmlout (`El_start (("","symbol"),[ "class" =|= cls; "id" =*= id ]));
            Xmlm.output xmlout `El_end;
          )
        end exports;
        Xmlm.output xmlout `El_end;(*}}}*)
        Xmlm.output xmlout `El_end;
        close_out out;
      )
    );
  );


value () = 
  let indir = ref None in
  (
    Arg.parse [ ("-o",Arg.Set_string outdir,"outpud directory") ] (fun id -> indir.val := Some id) "usage msg";
    match !indir with
    [ None -> failwith "You must spec input dir"
    | Some indir -> 
        let indir = if indir.[String.length indir - 1] = '/' then String.rchop indir else indir in
        do_work indir
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
