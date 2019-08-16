
value (//) = Filename.concat;
value bgcolor = {Color.color = {Color.r = 0; g = 0; b = 0}; alpha = 0};

value jfloat = fun [ `Float s -> s | _ -> failwith "not a float" ];
value jint = fun [ `Int s -> s | _ -> failwith "not a float" ];
value jnumber = fun [ `Int s -> float s | `Float f -> Utils.round f | _ -> failwith "not a float" ];
value jobject = fun [ `Assoc s -> s | _ -> failwith "not an object" ];
value jstring = fun [ `String s -> s | _ -> failwith "not a string" ];
value jlist = fun [ `List s -> s | _ -> failwith "not a list" ];

type pack_mode = [ PackGroup | PackSep | PackFSep ];

module Rectangle = struct (*{{{*)

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

end;(*}}}*)


type pos = {x:float;y:float};

type mask = option string;

type texinfo = {page:mutable int; tx:mutable int;ty:mutable int; width: int;height:int};

type img = (int * option string * pos * mask);

type child = [= `chld of img | `box of (pos * string) ];

type children = DynArray.t child;

type clipcmd = [ ClpPlace of (int * (int * option string * pos * mask)) | ClpClear of (int*int) | ClpChange of (int * list [= `posX of float | `posY of float | `move of int]) ];

type frame = {children:children; commands: mutable option (DynArray.t clipcmd); label: option string; duration: mutable int};

type item = [= `image of texinfo | `sprite of children | `clip of DynArray.t frame ];

type iteminfo = {item_id:int; item:item; deleted: mutable bool};

value images = Hashtbl.create 11;

value items : DynArray.t iteminfo = DynArray.create ();

(* name -> id, для того, чтобы разрезолвить маски *)
value names = Hashtbl.create 50;

value exports: DynArray.t (string*int) = DynArray.create ();




exception Not_equal;



value dump_items () = 
(
  Printf.printf "TOTAL ITEMS %d\n" (DynArray.length items);

  let dump_child child = 
    match child with
    [ `chld (id, _, pos, _)   ->    Printf.printf "\t\tChild type: image [id : %d]\n" id
    | `box _ ->  Printf.printf "\t\tChild type: box\n"
    ]
  in 

  let dump_item item =
  (  
    Printf.printf "Item id %d [Deleted : %B]\n" item.item_id item.deleted;
    match item.item with
    [ `image texinfo ->
        Printf.printf "\tType: image\n"

    | `sprite children  -> 
        (
          Printf.printf "\tType: sprite\n";
          DynArray.iter dump_child children;
        )
        
    | `clip _   ->
        Printf.printf "\tType: clip\n"
    ]
    
  )  
  in DynArray.iter dump_item items;  
  
);




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


value push_new_item item =
(
  DynArray.add items {item_id=(DynArray.length items);item=(item :> item);deleted=False};
  (DynArray.length items) - 1;
);

value push_item item =
  try
    DynArray.index_of 
      (fun {item=i} -> 
        match i with 
        [ `image _ -> False 
        | (`sprite _ | `clip _ ) as el -> compare_item el item
        ]
      )
      items
  with [ Not_found -> push_new_item item ];


exception Found of int;


value push_new_image img = 
  let id = DynArray.length items 
  in
  (
    let (width,height) = Images.size img in
    DynArray.add items {item_id=id;item=(`image {page=0;tx=0;ty=0;width;height});deleted=False};
    Hashtbl.add images id img;
    id
  );

value load_image path =
  let img = Images.load path [] in
  let (w,h) = Images.size img in
  if w > !TextureLayout.max_size || h > !TextureLayout.max_size
  then failwith (Printf.sprintf "IMAGE <%s:[%d:%d]> too large" path w h)
  else img;


value push_image (img: [= `image of Images.t | `path of string])  = 
  let img = match img with [ `image img -> img | `path path -> load_image path ] in
  try
    Hashtbl.iter begin fun id img' ->
      if compare_images img img'
      then raise (Found id)
      else ()
    end images;
    push_new_image img;
  with [ Found id -> id ];


value push_child_image dirname mobj allowEmpty = 
  (* нельзя скипать пустые картинки, если у них есть имя! *) 
  let path = dirname // (jstring (List.assoc "file" mobj)) in
  let img  = load_image path in
  let name = jstring (List.assoc "name" mobj) in
  try
    if (allowEmpty) then
      raise Exit
    else (    
      Utils.image_iter begin fun _ _ {Color.alpha=alpha;_}  ->
        if alpha > 1 then raise Exit else ()
      end img;
      None
    )
  with 
  [ Exit -> 
    let id = push_image (`image img) in 
    (
      Hashtbl.add names name id;
      Some (id)
    )
  ];

value getpos jsinfo = {x= jnumber (List.assoc "x" jsinfo);y=jnumber (List.assoc "y" jsinfo)};





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
