
type rect = {
  x : int;
  y : int;
  w : int;
  h : int
};

value out_file = ref "tx_texture";
value gen_pvr = ref False;
value sqr = ref False;
value type_rect = ref `vert;
value xmls = ref [];

value emptyPx = 2;

value imageRects : (Hashtbl.t string Images.t) = Hashtbl.create 55;

exception Break_loop;

(* получаем кропленый прямоугольник *)
value croppedImageRect img = 

  let vlineEmpty img num f t = 
    let y = ref f in
    try 
    (
      while !y <= t do 
      (
        let elt = Rgba32.get img num !y in  
        match elt.Color.Rgba.alpha with
        [0 -> incr y
        |_ -> raise Break_loop
        ]
      )  
      done;
      True
    )  
    with [ Break_loop -> False]
  
  and hlineEmpty img num f t = 
    let x = ref f in
    try 
    (
      while !x <= t do 
      (
        let elt = Rgba32.get img !x num in  
        match elt.Color.Rgba.alpha with
        [0 -> incr x
        |_ -> raise Break_loop
        ]
      )  
      done;
      True
    )
    with [Break_loop -> False]
  in
  match img with
  [ Images.Rgba32 i -> 
    let x = ref 0
    and y = ref 0 
    and w = ref i.Rgba32.width
    and h = ref i.Rgba32.height in 
    (
      
      (* сканируем сверху *)
      try 
        while !y < i.Rgba32.height do 
          match hlineEmpty i !y !x (!x + !w - 1) with
          [ True    -> incr y
          | False   -> raise Break_loop
          ]
        done
      with [Break_loop -> ()];
      
      (* сканируем снизу *)
      try 
        while !h > 0 do 
          match hlineEmpty i (!h - 1) !x (!x + !w - 1) with
          [ True    -> decr h
          | False   -> raise Break_loop
          ]
        done        
      with [Break_loop -> ()];
      
      (* слева *)
      try 
        while !x < i.Rgba32.width do 
          match vlineEmpty i !x !y (!y + !h - 1) with
          [ True    -> incr x
          | False   -> raise Break_loop
          ]
        done        
      with [Break_loop -> ()];      
      
      (* справа *)
      try 
        while !w > 0 do 
          match vlineEmpty i (!w - 1) !y (!y + !h - 1) with
          [ True    -> decr w
          | False   -> raise Break_loop
          ]
        done        
      with [Break_loop -> ()];      
      match !w with
      [ 0 -> (0,0,Images.sub img 0 0 1 1)
      | _ -> (!x, !y, Images.sub img !x !y (!w - !x) (!h - !y))
      ]
    )
  | Images.Rgb24 i -> 
      (0, 0, Images.sub img 0 0 i.Rgb24.width i.Rgb24.height)
  | _ -> assert False
  ];



type frame = 
  {
    id : int;
    posX : float;
    posY : float;
    label : option string;
    duration : option string;
  };

value images = ref [];

(* загружаем все файлы, влючая поддиректории *)
value loadFiles () =
  let id = ref 0 in
  (
    List.iter begin fun xml -> 
      let input =
        match Sys.file_exists xml with
        [ True -> open_in xml
        | _ -> failwith "Not_found xml"
        ]
      in
      let name = Filename.chop_extension (Filename.basename xml)  
      and firstFrame = ref True in
      let xmlinput = Xmlm.make_input ~strip:True (`Channel  input) in
      let  get_attribute name attributes = 
        try
          let (_,v) = List.find (fun ((_,ln),v) -> ln = name) attributes in
          Some v
        with [ Not_found -> None ]
      in
      let get_attributes tag_name names attributes : list string =
        List.map begin fun name ->
          try
            let (_,v) = List.find (fun ((_,ln),v) -> ln = name) attributes in v
          with [ Not_found -> failwith (Printf.sprintf "attribute %s not found in element %s" name tag_name) ]
        end names
      in
      let  parse_element tag_name attr_names =
        match Xmlm.input xmlinput with
        [ `El_start ((_,tname),attributes) when tname = tag_name ->
          let res = get_attributes tname attr_names attributes in
          match Xmlm.input xmlinput with
          [ `El_end -> Some (res,attributes)
          | _ -> failwith (Printf.sprintf "Unspecified element in %s" tag_name)
          ]
        | `El_end -> None
        | _ -> failwith (Printf.sprintf "Not an element %s" tag_name)
        ]
      in
        (
          match Xmlm.input xmlinput with
          [ `Dtd None ->
              let rec parse_textures result =
                match parse_element "Texture" [ "path" ] with
                [ Some [ path ] _ -> 
                    let s = Filename.concat (Filename.dirname xml) path in
                    parse_textures [Images.load s [] :: result ]
                | None -> result
                | _ -> assert False
                ]
              in
              let rec parse_frames textures  =
                match parse_element "Frame" [ "textureID"; "x"; "y"; "width"; "height"; "posX"; "posY" ] with
                [ Some [textureId; x; y; width; height; posX; posY] attributes -> 
                    let label = 
                      match get_attribute "label" attributes with
                      [ Some label -> 
                          (
                            match !firstFrame with
                            [ True -> firstFrame.val := False
                            | _ -> ()
                            ];
                            Some (label ^ "_" ^ name);
                          )
                      | None -> 
                          match !firstFrame with
                          [ True -> 
                              (
                                firstFrame.val := False;
                                Some ("_start_" ^ name)
                              )
                          | _ -> None
                          ]
                      ]   
                    in 
                    let duration = get_attribute "duration" attributes in 
                    let image = Images.sub textures.(int_of_string textureId) (int_of_string x) (int_of_string y) (int_of_float (float_of_string width)) (int_of_float (float_of_string height)) in
                    let (diffX,diffY,new_image) = (*(0,0,image)*) croppedImageRect  image in
                      (
                        images.val := [({id = !id; posX = (float_of_string posX) +. (float_of_int  diffX); posY = (float_of_string posY) +. (float_of_int diffY); label; duration}, new_image) :: !images];
                        id.val := !id + 1;
                        parse_frames textures;
                      )
                | None -> ()
                | _ -> assert False
                ]
              in
              match Xmlm.input xmlinput with
              [ `El_start ((_,"MovieClip"),_) ->
                  match Xmlm.input xmlinput with
                  [ `El_start ((_,"Textures"),_) -> 
                      let textures = Array.of_list (List.rev (parse_textures [])) in
                      match Xmlm.input xmlinput with
                      [ `El_start ((_,"Frames"),_) -> 
                          (
                            parse_frames textures;
                            images.val := 
                              match !images with
                              [ [ (frame, img ) :: tail ] ->
                                  let label =
                                    match frame.label with
                                    [ Some label -> Some label
                                    | None -> Some ("_end_" ^ name)
                                    ]
                                  in
                                  [ ({(frame) with label = label},img) :: tail ]
                              | _ -> !images
                              ];
                            close_in input;
                          )
                      | _ -> failwith "Not found tag Frames" 
                      ]
                  | _ -> failwith "Not found tag Textures"
                  ]
              | _ -> failwith "Not found tag MovieClip"
              ]
          | _ -> ()
          ]
        )
    end !xmls;
  );

value createAtlas () = 
    let i = ref 0 
    and pages = TextureLayout.layout ~type_rects:!type_rect ~sqr:!sqr !images in
    let xml_textures = ref "\t<Textures>\n" 
    and frames_info = ref []
    in
    (
      List.iter begin fun (w,h,rects) -> 
      (
        let fname = match List.length pages with 
          [ 1 -> (!out_file ^ ".png")
          | _ -> 
            (
              incr i;
              Printf.sprintf "%s_%d.png" !out_file !i;
            )
          ] in
        let () = xml_textures.val := !xml_textures ^ (Printf.sprintf "\t\t<Texture path='%s'/>\n" fname) in
        let rgba = Rgba32.make w h {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
        let () = Printf.eprintf "Canvas %d: %dx%d\n%!" !i w h in
        let canvas  = Images.Rgba32 rgba in 
        (
          List.iter begin fun (frame, (x,y,img)) -> 
            let img = match img with 
            [ Images.Rgba32 i -> img
            | Images.Rgb24 i -> Images.Rgba32 (Rgb24.to_rgba32 i)
            | _ -> assert False
            ] in
            let (w, h) = Images.size img in
            let frame_str = Printf.sprintf "\t\t<Frame textureID = '%d' x='%d' y='%d' width= '%d' height='%d' posX='%f' posY='%f' %s  %s />\n" (!i-1) x y w h frame.posX frame.posY (match frame.duration with [ Some duration -> "duration='" ^ duration ^ "'" | _ -> ""]) (match frame.label with [ Some label -> "label='" ^ label ^ "'" | _ -> ""])in
              (
                frames_info.val := [(frame.id, frame_str) :: !frames_info];
                Images.blit img 0 0 canvas x y w h  
              )
          end rects;
          Images.save fname (Some Images.Png) [] canvas;
        );
      )
      end pages;
      frames_info.val := List.fast_sort (fun (id1,_) (id2,_) -> compare id1 id2) !frames_info;
      xml_textures.val := !xml_textures ^ "\t</Textures>";
      let oc = open_out (!out_file ^ ".xml") in (
        output_string oc "<MovieClip>\n";
        output_string oc !xml_textures;
        output_string oc "\n\t<Frames>\n";
        List.iter (fun (_,s) ->  output_string oc s) !frames_info;
        output_string oc "\t</Frames>";
        output_string oc "\n</MovieClip>";
        close_out oc;
      )
      
    );      



(* *)
value () = 
  (
    Arg.parse
      [
        ("-m", Arg.Set_int TextureLayout.max_size, "Max texture size");
        ("-o",Arg.Set_string out_file,"output file");
        ("-sqr",Arg.Unit (fun sq -> sqr.val := True )  ,"square texture");
        ("-p",Arg.Set gen_pvr,"generate pvr file");
        ("-t",Arg.String (fun s -> let t = match s with [ "vert" -> `vert | "hor" -> `hor | "rand" -> `rand | _ -> failwith "unknown type rect" ] in type_rect.val := t),"type rect for insert images")
      ]
      (fun xml -> xmls.val := [ xml :: !xmls ] )
      "---"
    ;
    match !xmls with
    [ [] -> failwith "Tou must specify xml for process"
    | _ ->  
        (
          loadFiles ();
          createAtlas ();
        )
    ]
  );

(* 
TODO: Попробовать поворачивать картинки на 90 градусов.
*)
