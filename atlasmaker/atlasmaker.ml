open ExtString;

type rect = {
  x : int;
  y : int;
  w : int;
  h : int
};

value maxTextureSize = ref 2048;
value out_file = ref "";
value gen_pvr = ref False;
value is_xml = ref False;
value dirname = ref None;
value fp = ref False;
value npot = ref False;

value nocrop = ref "";
value nocropHash:Hashtbl.t string unit = Hashtbl.create 3;
value type_rect = ref `maxrect;

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
value readImageRect path fname = 
  let () = Printf.eprintf "Loading %s\n%!" path in
  try 
    let image = Images.load path [] in
    let rect = 
      try 
        let () = Hashtbl.find nocropHash fname in
        let () = Printf.eprintf "Won't crop %s\n%!" fname 
        in image
      with [ Not_found -> croppedImageRect image ] 
    in
		let name = 
				match !fp with
				[ True -> 
						let dirname = Option.get !dirname in
						snd (ExtString.String.replace ~str:path ~sub:dirname  ~by:"")
				| _ -> fname
				]
		in
		Hashtbl.add imageRects name rect
  with [Images.Wrong_file_type -> Printf.eprintf "Wrong file type: %s\n%!" path ];
  


value (//) = Filename.concat;

(* загружаем все файлы, влючая поддиректории *)
value loadFiles gdir =
  let rec _readdir dir = 
    Array.iter begin fun f -> 
      try 
        let fpath = gdir // dir // f in
        match Sys.is_directory fpath with
        [ True  ->  _readdir (dir // f)
        | False when Filename.check_suffix f ".png" -> readImageRect fpath f
        | _ -> ()
        ]
      with [Sys_error _ -> ()]
    end (Sys.readdir (gdir // dir))   
  in 
  _readdir "";




type atlas_item = 
  {
    name:string;
    x:int;
    y:int;
    width:int;
    height:int;
    isRotate:bool;
  };

type atlas = 
  {
    path:string;
    items: list atlas_item;
  };

value (=|=) k v = (("",k),v);
value (=.=) k v = k =|= string_of_float v;
value (=*=) k v = k =|= string_of_int v;
value (=&=) k v = k =|= string_of_bool v;

(* *)
value createAtlas () = 
  let () = TextureLayout.rotate.val := False in
  let pages = TextureLayout.layout ~type_rects:!type_rect ~sqr:!gen_pvr ~npot:!npot (Hashtbl.fold (fun k v acc -> [(k,v) :: acc]) imageRects []) in
  let i = ref 0 in
  let meta = 
    List.map begin fun (w,h,rects) -> 
    (
      let fname = 
        match List.length pages with 
        [ 1 -> (!out_file ^ ".png")
        | _ -> 
          (
            incr i;
            Printf.sprintf "%s_%d.png" !out_file !i;
          )
        ] 
      in
      let rgba = Rgba32.make w h {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
      let () = Printf.eprintf "!!Canvas: %dx%d\n%!" w h in
      let canvas  = Images.Rgba32 rgba in 
      let items = 
        List.map begin fun (id, (x,y,isRotate,img)) -> 
          let () = print_endline "HERE" in
          let img = 
            match img with 
            [ Images.Rgba32 _ -> img
            | Images.Rgb24 i -> 
                let () = print_endline "convert 23 -> 32" in
                Images.Rgba32 (Rgb24.to_rgba32 i)
            | _ -> assert False
            ]
          in
          let (w, h) = Images.size img in
          let () = Printf.printf "Images.blit x=%d; y=%d; w=%d; h=%d; isRotate=%b \n%!" x y w h isRotate in
          (
            Images.blit img 0 0 canvas x y w h;
            {name=id;x;y;width = w;height = h;isRotate};
          )
        end rects
      in
      (
        Images.save fname (Some Images.Png) [] canvas;
        {path=fname;items}
      )
    )
    end pages
  in
  match !is_xml with
  [ True ->
    let out = open_out (!out_file ^ ".xml") in
    let xmlout = Xmlm.make_output ~indent:(Some 2) (`Channel out) in
    (
      Xmlm.output xmlout (`Dtd None);
      Xmlm.output xmlout (`El_start (("","TexuteAtlases"),[]));
      List.iter begin fun atlas ->
      (
        Xmlm.output xmlout (`El_start (("","TextureAtlas"),[ "path" =|= atlas.path ]));
        List.iter begin fun item ->
        (
          Xmlm.output xmlout (`El_start 
          (
            ("","TextureAtlas"),
            [ "id" =|= item.name
            ; "x" =*= item.x
            ; "y" =*= item.y
            ; "w" =*= item.width
            ; "h" =*= item.height
            ; "rotate" =&= item.isRotate
            ]
          ));
          Xmlm.output xmlout `El_end;
        )
        end atlas.items;
        Xmlm.output xmlout `El_end;
      )
      end meta;
      Xmlm.output xmlout `El_end;
      close_out out;
    )
  | False -> 
      let out = open_out (!out_file ^ ".bin") in
      let binout = IO.output_channel out in
      (
        IO.write_byte binout (List.length meta);
        List.iter begin fun atlas ->
        (
          IO.write_string binout atlas.path;
          IO.write_ui16 binout (List.length atlas.items);
          List.iter begin fun item ->
          (
            IO.write_string binout item.name;
            IO.write_ui16 binout item.x;
            IO.write_ui16 binout item.y;
            IO.write_ui16 binout item.width;
            IO.write_ui16 binout item.height;
            IO.write_byte binout (if item.isRotate then 1 else 0);
          )
          end atlas.items
        )
        end meta;
        close_out out;
    )
  ];
  (*
  let oc = open_out (!out_file ^ ".xml") in (
    output_string oc !xml;
    output_string oc "</TextureAtlases>";
    close_out oc;
  );
  *)
    

      
      



(* *)
value () = 
  (
    Arg.parse
      [
        ("-fp", Arg.Set fp, "Full path name for item atlase");
        ("-max", Arg.Set_int TextureLayout.max_size, "Max texture size");
        ("-min", Arg.Set_int TextureLayout.min_size, "Max texture size");
        ("-o",Arg.Set_string out_file,"output file");
        ("-nc", Arg.Set_string nocrop, "files that are not supposed to be cropped");
        ("-t",Arg.String (fun s -> let t = match s with [ "vert" -> `vert | "hor" -> `hor | "rand" -> `rand | "maxrect" -> `maxrect |  _ -> failwith "unknown type rect" ] in type_rect.val := t),"type rect for insert images");
        ("-p",Arg.Set gen_pvr,"generate pvr file");
        ("-xml",Arg.Set is_xml,"meta in xml format");
        ("-npot", Arg.Set npot, "Not power of 2");
      ]
      (fun dn -> match !dirname with [ None -> dirname.val := Some dn | Some _ -> failwith "You must specify only one directory" ])
      "---"
    ;
    
    match !nocrop with
    [ "" -> ()
    | str -> List.iter begin fun s -> Hashtbl.add nocropHash s () end (String.nsplit str ",")
    ];
    
    let dirname =
      match !dirname with
      [ None -> failwith "You must specify directory for process"
      | Some d -> d
      ]
    in 
    (
      let dirname = if dirname.[String.length dirname - 1] = '/' then String.rchop dirname else dirname in
      match !out_file with
      [ "" -> out_file.val := Filename.basename dirname
      | _ -> ()
      ];
      loadFiles dirname;
      if Hashtbl.length imageRects > 0
      then
        createAtlas ()
      else failwith "no input files"
    )
  );

(* 
TODO: Попробовать поворачивать картинки на 90 градусов.
*)
