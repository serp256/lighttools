open ExtList;

value bgcolor = {Color.color = {Color.r = 0; g = 0; b = 0}; alpha = 0}; 
(*
module MakeParser (P: sig 
  value open_resource: string -> in_channel; 
  type cFrame 'keyframe = 
    [ KeyFrame of (option string * 'keyframe)
    | Frame of int
    ];
end) = struct
open P;
*)

type cFrame 'keyframe = 
  [ KeyFrame of (option string * 'keyframe)
  | Frame of int
  ];

value open_resource = open_in;


type img = (int * Rectangle.t);
type iframe = 
  {
    hotpos: Point.t;
    image: (int * Rectangle.t);
  };

type child = (Rectangle.t * option string * Point.t); 
type bchildren = [ CBox of (string * Point.t) | CImage of (img * option string * Point.t) | CAtlas of (int * list child) ];
type children = list child;
type clipcmd = 
  [ ClpPlace of (int * Rectangle.t * option string * Point.t) 
  | ClpClear of (int * int) 
  | ClpChange of (int * list [= `posX of float | `posY of float | `move of int]) 
  ];

type frame = (children * option (list clipcmd)); 

type labels = Hashtbl.t string int;

type element = 
  [ Image of img
  | Sprite of list bchildren
  | Atlas of (int * list child)
  | Clip of (int * (array (cFrame frame)) * labels)
  | ImageClip of ((array (cFrame iframe)) * labels)
  ];

value load libpath suffix = 
  let () = debug "bin load %s" libpath in 
  let path = Filename.concat libpath ("lib"^suffix^".bin") in
  let inp = open_resource path in
  let bininp = IO.input_channel inp in
  (
    let read_option_string () =
      let len = IO.read_byte bininp in
      match len with
      [ 0 -> None
      | _ -> Some (IO.nread bininp len)
      ]
    in
    let n_textures = IO.read_ui16 bininp in
    let textures = Array.init n_textures (fun _ -> IO.read_string bininp) in
    let n_items = IO.read_ui16 bininp in
    let items = Hashtbl.create n_items in
    (
      let read_children () = (*{{{*)
        let n_children = IO.read_byte bininp in
        let tid = ref 0 in
        let children = 
          List.init n_children begin fun _ ->
            let id = IO.read_ui16 bininp in
            let posx = IO.read_double bininp in
            let posy = IO.read_double bininp in
            let name = read_option_string () in
            match Hashtbl.find items id with
            [ Image (tid',rect) -> 
              (
                tid.val := tid';
                (rect,name,{Point.x = posx; y = posy})
              )
            | _ -> failwith "sprite children not an image"
            ]
          end 
        in
        (!tid,children) (*}}}*)
      and read_sprite_children () = (*{{{*)
        let n_children = IO.read_byte bininp in
        List.init n_children begin fun _ ->
          match IO.read_byte bininp with
          [ 0 ->
            let id = IO.read_ui16 bininp in
            let posx = IO.read_double bininp in
            let posy = IO.read_double bininp in
            let name = read_option_string () in
            match Hashtbl.find items id with
            [ Image img -> CImage (img,name,{Point.x = posx; y = posy})
            | _ -> failwith "sprite children not an image"
            ]
          | 1 -> (* atlas *)
            let cnt = IO.read_byte bininp in
            let tid = ref 0 in
            let children = 
              List.init cnt begin fun _ ->
                let id = IO.read_ui16 bininp in
                let posx = IO.read_double bininp in
                let posy = IO.read_double bininp in
                let name = read_option_string () in
                match Hashtbl.find items id with
                [ Image (tid',rect) -> 
                  (
                    tid.val := tid';
                    (rect,name,{Point.x = posx; y = posy})
                  )
                | _ -> failwith "sprite children not an image"
                ]
              end 
            in
            (CAtlas !tid children)
          | 2 -> (* box *)
            let posx = IO.read_double bininp in
            let posy = IO.read_double bininp in
            let name = IO.read_string bininp in
            CBox (name,{Point.x=posx;y=posy})
          | _ -> assert False
          ]
        end (*}}}*)
      in
      for i = 0 to n_items - 1 do (*{{{*)
        let id = IO.read_ui16 bininp in
        let kind = IO.read_byte bininp in
(*         let () = debug "bin read %d:%d" id kind in *)
        match kind with
        [ 0 -> (* image *)
            let page = IO.read_ui16 bininp in
            let x = IO.read_ui16 bininp in
            let y = IO.read_ui16 bininp in
            let width = IO.read_ui16 bininp in
            let height = IO.read_ui16 bininp in
            Hashtbl.add items id (Image (page,Rectangle.create (float x) (float y) (float width) (float height)))
        | 1 -> (* sprite *)
            let children = read_sprite_children () in
            let el = 
              match children with
              [ [ CAtlas tid children ] -> Atlas tid children
              | _ -> Sprite children
              ]
            in
            Hashtbl.add items id el
        | 2 -> (* image clip *)
            let n_frames = IO.read_ui16 bininp in
            let labels = Hashtbl.create 0 in
            let frames = DynArray.create () in
            (
              for i = 0 to n_frames - 1 do
                let duration = IO.read_byte bininp in
                let label = read_option_string () in
                let imgid = IO.read_ui16 bininp in
                let x = IO.read_double bininp in
                let y = IO.read_double bininp in
                match Hashtbl.find items imgid with
                [ Image image -> 
                  (
                    DynArray.add frames (KeyFrame (label,{image;hotpos={Point.x;y}}));
                    let i = DynArray.length frames - 1 in
                    (
                      match label with
                      [ Some l -> Hashtbl.add labels l i
                      | None -> ()
                      ];
                      for j = 1 to duration - 1 do
                        DynArray.add frames (Frame i);
                      done;
                    )
                  )
                | _ -> failwith "clip children not an image"
                ]
              done;
              Hashtbl.add items id (ImageClip ((DynArray.to_array frames),labels));
            )
        | 3 -> (* clip *)
            let n_frames = IO.read_ui16 bininp in
            let labels = Hashtbl.create 0 in
            let frames = DynArray.create () in
            let tid = ref 0 in
            (
              for i = 0 to n_frames - 1 do
                let duration = IO.read_byte bininp in
                let label = read_option_string () in
                let (tid',children) = read_children () in
                let () = tid.val := tid' in
                let commands = 
                  match IO.read_byte bininp with
                  [ 0 -> None
                  | _ -> 
                      let n_commands = IO.read_ui16 bininp in
                      let commands = 
                        List.init n_commands begin fun _ ->
                          match IO.read_byte bininp with
                          [ 0 -> (* place *)
                            let idx = IO.read_ui16 bininp in
                            let id = IO.read_ui16 bininp in
                            let name = read_option_string () in
                            let posx = IO.read_double bininp in
                            let posy = IO.read_double bininp in
                            match Hashtbl.find items id with
                            [ Image (_,rect) -> ClpPlace (idx,rect,name,{Point.x = posx; y = posy})
                            | _ -> failwith "frame element not an image"
                            ]
                          | 1 -> (* clear *)
                              let from = IO.read_ui16 bininp in
                              let count = IO.read_ui16 bininp in
                              ClpClear from count
                          | 2 ->  (* change *)
                              let idx = IO.read_ui16 bininp in
                              let n_changes = IO.read_byte bininp in
                              let changes = 
                                List.init n_changes begin fun _ ->
                                  match IO.read_byte bininp with
                                  [ 0 -> (* move *) `move (IO.read_ui16 bininp)
                                  | 1 -> (* posx *) `posX (IO.read_double bininp)
                                  | 2 -> (* posy *) `posY (IO.read_double bininp)
                                  | _ -> failwith "unknown clip change command"
                                  ]
                                end
                              in
                              ClpChange idx changes
                          | _ -> failwith "unknown clip command"
                          ]
                        end
                      in
                      Some commands
                  ]
                in
                (
                  DynArray.add frames (KeyFrame (label,(children,commands)));
                  let i = DynArray.length frames - 1 in
                  (
                    match label with
                    [ Some l -> Hashtbl.add labels l i
                    | None -> ()
                    ];
                    for j = 1 to duration - 1 do
                      DynArray.add frames (Frame i);
                    done;
                  )
                )
              done;
              Hashtbl.add items id (Clip !tid (DynArray.to_array frames) labels);
            )
        | n -> failwith (Printf.sprintf "unkonwn el type %d" n)
        ]
      done; (*}}}*)
      let n_symbols = IO.read_ui16 bininp in
      let symbols = Hashtbl.create n_symbols in
      (
        for i = 0 to n_symbols - 1 do
          let cls = IO.read_string bininp in
          let id = IO.read_ui16 bininp in
(*           let () = debug "%s" cls in *)
          Hashtbl.add symbols cls (Hashtbl.find items id);
        done;
        IO.close_in bininp;
        (textures,symbols);
      );
    );
  );


value load libpath suffix = 
  let (textures,symbols) = load libpath suffix in
  (libpath,textures,symbols);

value round x = 
  let (r,_) = modf x in
  let r = abs_float r in
  truncate begin
    if x > 0.
    then (if r < 0.5 then floor x else ceil x)
    else (if r < 0.5 then ceil x else floor x)
  end;

value ints_of_rect r = Rectangle.((round r.x, round r.y, round r.width, round r.height));


value calc_size children =  
  let open Rectangle in
  let open Point in
  List.fold_left begin fun (minx,miny,maxx,maxy) (rect,_,pos) ->
    let minx = if minx > pos.x then pos.x else minx
    and miny = if miny > pos.y then pos.y else miny
    in
    let mx = rect.width +. pos.x 
    and my = rect.height +. pos.y in
    let maxx = if maxx < mx then mx else maxx
    and maxy = if maxy < my then my else maxy
    in
    (minx,miny,maxx,maxy)
  end (max_float,max_float,~-. max_float,~-. max_float) children;

value create_draw_children minx miny res = 
  fun img children ->
    let open Point in
    List.iter begin fun (rect,_,pos) ->
      let (rx,ry,rw,rh) = ints_of_rect rect in
      let x = round (pos.x -. minx)
      and y = round (pos.y -. miny)
      in
      Images.blit img rx ry res x y rw rh 
    end  children;

value symbol (libpath,textures,symbols) cls = 
  match Hashtbl.find symbols cls with
  [ Image (tid,rect) ->
    let img = Png.load (Filename.concat libpath textures.(tid)) [] in
    let (x,y,w,h) = ints_of_rect rect in
    let (iw,ih) = Images.size img in
    let res = 
      if (x = 0 && y = 0 && w = iw && ih = h) then img
      else Images.sub img x y w h 
    in
    ((0,0),res)
  | Atlas tid children ->
      let img = Png.load (Filename.concat libpath textures.(tid)) [] in
      let (minx,miny,maxx,maxy) = calc_size children in
      let width = round (maxx -. minx)
      and height = round (maxy -. miny)
      in
      let res = Images.Rgba32 (Rgba32.make width height bgcolor) in
      let draw_children = create_draw_children minx miny res in
      (
        draw_children img children;
        ((round minx,round miny),res)
      )
  | Sprite bchildren -> 
    let cached_textures = Hashtbl.create 1 in
    let get_texture tid = 
      try
        Hashtbl.find cached_textures tid
      with 
      [ Not_found -> 
        let img = Png.load (Filename.concat libpath textures.(tid)) [] in
        (
          Hashtbl.add cached_textures tid img;
          img;
        )
      ]
    in
    let children = 
      List.fold_left begin fun res -> fun
        [ CBox _ -> res
        | CImage ((_,rect),label,pos) -> [  (rect,label,pos) :: res ]
        | CAtlas (_,child) -> child @ res
        ]
      end [] bchildren 
    in
    let (minx,miny,maxx,maxy) = calc_size children in
    let width = round (maxx -. minx)
    and height = round (maxy -. miny)
    in
    let res = Images.Rgba32 (Rgba32.make width height bgcolor) in
    let draw_children = create_draw_children minx miny res in
    (
      List.iter begin fun 
        [ CBox _ -> ()
        | CImage ((tid,rect),_,pos) ->
            let img = get_texture tid in
            draw_children img [(rect,None,pos)]
        | CAtlas (tid,children) ->
            let img = get_texture tid in
            draw_children img children
        ]
      end bchildren;
      ((round minx,round miny),res)
    )
  | Clip _ -> failwith "clip does not supported yet"
  | _ -> assert False
  ];
