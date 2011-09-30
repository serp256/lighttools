type rect = {
  x : int;
  y : int;
  w : int;
  h : int
};

value maxTextureSize = ref 2048;
value out_file = ref "tx_texture";
value gen_pvr = ref False;
value sqr = ref False;

value nocrop = ref "";
value nocropHash:Hashtbl.t string unit = Hashtbl.create 3;
value type_rect = ref `vert;

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
          match hlineEmpty i !y !x (!w - 1) with
          [ True    -> incr y
          | False   -> raise Break_loop
          ]
        done
      with [Break_loop -> ()];
      
      (* сканируем снизу *)
      try 
        while !h > 0 do 
          match hlineEmpty i (!h - 1) !x (!w - 1) with
          [ True    -> decr h
          | False   -> raise Break_loop
          ]
        done        
      with [Break_loop -> ()];
      
      (* слева *)
      try 
        while !x < i.Rgba32.width do 
          match vlineEmpty i !x !y (!h - 1) with
          [ True    -> incr x
          | False   -> raise Break_loop
          ]
        done        
      with [Break_loop -> ()];      
      
      (* справа *)
      try 
        while !w > 0 do 
          match vlineEmpty i (!w - 1) !y (!h - 1) with
          [ True    -> decr w
          | False   -> raise Break_loop
          ]
        done        
      with [Break_loop -> ()];      
      Images.sub img !x !y (!w - !x) (!h - !y)
    )
    
  | Images.Rgb24 i -> 
      let () = Printf.eprintf "Rgba24\n" in
      Images.sub img 0 0 i.Rgb24.width i.Rgb24.height
  | _ -> assert False
  ];



(* зачитываем картинку, получаем кроп-прямоугольник и сохраняем его*)
value readImageRect fname = 
  let () = Printf.eprintf "Loading %s\n%!" fname in
  try 
    let image = Images.load fname [] in
    let rect = 
      try 
        let () = Hashtbl.find nocropHash fname in
        let () = Printf.eprintf "Won't crop %s\n%!" fname 
        in image
      with [ Not_found -> croppedImageRect image ] 
    in  Hashtbl.add imageRects fname rect
  with [Images.Wrong_file_type -> ()];
  



(* загружаем все файлы, влючая поддиректории *)
value loadFiles d =
  let rec _readdir dir = 
    Array.iter begin fun f -> 
      try 
        let path = dir ^ "/" ^ f in
        match Sys.is_directory path with
        [ True  ->  _readdir path
        | False -> readImageRect path
        ]
      with [Sys_error _ -> ()]
    end (Sys.readdir dir)   
  in _readdir d;



(* *)
value createAtlas () = 
    let i = ref 0 
    and pages = TextureLayout.layout ~type_rects:!type_rect ~sqr:!sqr (Hashtbl.fold (fun k v acc -> [(k,v) :: acc]) imageRects []) in
    let xml  = ref "<TextureAtlases >\n" in
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
        let () = xml.val := !xml ^ (Printf.sprintf "<TextureAtlas imagePath='%s'>\n" fname) in
        let rgba = Rgba32.make w h {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
        let () = Printf.eprintf "Canvas: %dx%d\n%!" w h in
        let canvas  = Images.Rgba32 rgba in 
        (
          List.iter begin fun (id, (x,y,img)) -> 
            let img = match img with 
            [ Images.Rgba32 i -> img
            | Images.Rgb24 i -> Images.Rgba32 (Rgb24.to_rgba32 i)
            | _ -> assert False
            ] in
            let (w, h) = Images.size img in
            let subTextureElt = Printf.sprintf "\t<SubTexture name='%s' x='%d' y='%d' height='%f' width='%f'/>\n" id x y (float_of_int h) (float_of_int w) in
              (
                xml.val := !xml ^ subTextureElt;
                Images.blit img 0 0 canvas x y w h  
              )
          end rects;
          Images.save fname (Some Images.Png) [] canvas;
        );
        
        xml.val := !xml ^ "</TextureAtlas>\n";
      )
      end pages;
      
      let oc = open_out (!out_file ^ ".xml") in (
        output_string oc !xml;
        output_string oc "</TextureAtlases>";
        close_out oc;
      )
      
    );      

      
      



(* *)
value () = 
  let dirname = ref None in
  (
    Arg.parse
      [
        ("-m", Arg.Set_int TextureLayout.max_size, "Max texture size");
        ("-o",Arg.Set_string out_file,"output file");
        ("-nc", Arg.Set_string nocrop, "files that are not supposed to be cropped");
        ("-sqr",Arg.Unit (fun sq -> sqr.val := True )  ,"square texture");
        ("-t",Arg.String (fun s -> let t = match s with [ "vert" -> `vert | "hor" -> `hor | "rand" -> `rand | _ -> failwith "unknown type rect" ] in type_rect.val := t),"type rect for insert images");
        ("-p",Arg.Set gen_pvr,"generate pvr file")
      ]
      (fun dn -> match !dirname with [ None -> dirname.val := Some dn | Some _ -> failwith "You must specify only one directory" ])
      "---"
    ;
    
    match !nocrop with
    [ "" -> ()
    | str -> List.iter begin fun s -> Hashtbl.add nocropHash s () end (ExtString.String.nsplit str ",")
    ];
    
    let dirname =
      match !dirname with
      [ None -> failwith "You must specify directory for process"
      | Some d -> d
      ]
    in (
      loadFiles dirname;
      createAtlas ();
    )
  );

(* 
TODO: Попробовать поворачивать картинки на 90 градусов.
*)
