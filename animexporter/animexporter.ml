module PNG = Png;
module BITMAP = Bitmap;
module GENIMAGE = Genimage;

value (///) = Filename.concat;

(* FIXME: make it configurable *)
value dataDir = ref "/Volumes/newdata/data";
value img_dir = ref "/Volumes/newdata/img";
value outputDir = ref "output";

value file_frames () = !dataDir /// "frames1L.swf";
value (!!) l = Lazy.force l; 

value _libsettings = 
  lazy (
    match Json_io.load_json (!dataDir /// "libsettings.json") with
    [ Json_type.Object lst -> 
      fun key ->
        match List.assoc key lst with
        [ Json_type.String s -> s
        | _ -> failwith (Printf.sprintf "bad setting: %s" key)
        ]
    | _ -> assert False
    ]
  );

value libsettings param = (Lazy.force _libsettings) param;


value info_obj = lazy (JSObjAnim.init_obj_info (!dataDir /// (libsettings  "info")));
value animations = lazy (JSObjAnim.init_animations (!dataDir /// (libsettings  "animations")));
value frames_dir = lazy (JSObjAnim.init_frames_dir (!dataDir /// "frames_dir.json"));

(*
type new_frame_desc_item = {
  texId:int;
  recId:int;
  nxi:int;
  nyi:int;
  nflip:bool;
  nalpha:int;
};

type new_frame_desc = {
 nw:int;
 nh:int;
 nx:int;
 ny:int;
 nitems: list new_frame_desc_item;
};
*)

type frame_desc_item = {
 libId:int;
 pngId:int;
 xi:int;
 yi:int;
 flip:bool;
 alpha:int;
 urlId:int;
};

type frame_desc = {
 w:int;
 h:int;
 x:int;
 y:int;
 icon_x: int;
 icon_y: int;
 items: list frame_desc_item;
};


value read_boolean input =
  let i = BatIO.read_byte input in
  if i <> 0
  then True
  else False;

value read_frames () =
  let input = BatFile.open_in (file_frames()) in
  let rec loop index res =
     try
      let w = BatIO.read_ui16 input in
      let h = BatIO.read_ui16 input in
      let x = BatIO.read_i16 input in
      let y = BatIO.read_i16 input in
      let icon_x = BatIO.read_i16 input in
      let icon_y = BatIO.read_i16 input in
(*       let _ = print_endline (Printf.sprintf "fields: %d, %d, %d, %d" w h x y) in *)
      let count = BatIO.read_byte input in
(*       let _ = print_endline ("count: " ^ (string_of_int count)) in *)
      let rec loop1 i items =
          if i <= count
          then
(*             let _ = print_endline ("i: " ^ (string_of_int i)) in *)
            let libId = BatIO.read_byte input in
            let pngId = BatIO.read_i32 input in
            let xi = BatIO.read_i16 input in
            let yi = BatIO.read_i16 input in
            let flags = BatIO.read_byte input in
            let flip = if flags <> 0 then True else False in
            let alpha = if (flags land 2) = 2 then BatIO.read_byte input else 0 in
            let urlId = BatIO.read_i32 input in
(*             let _ = print_endline (Printf.sprintf "ifields: %d, %d, %d, %d, %d, %d" ifield1 ifield2 ifield3 ifield4 ifield6 ifield7) in  *)
            let item = {libId;pngId;xi;yi;flip;alpha;urlId} in
            loop1 (i+1) [item::items]
          else List.rev items
      in
      let items = loop1 1 [] in
      let frame = {w;h;x;y;icon_x;icon_y;items} in
      (
        loop (index+1) [ frame :: res ]
      )
     with [BatInnerIO.No_more_input -> res]
  in
  let res = loop 0 [] in
  let res = Array.of_list (List.rev res) in
  let _ = print_endline (Printf.sprintf "length res: %d" (Array.length res)) in
  res;

value (=|=) k v = (("",k),v);
value (=.=) k v = k =|= string_of_float v;
value (=*=) k v = k =|= string_of_int v;


(*
value hold_in_size (w,h) imgs = 
(*   let () = Printf.eprintf "hold to [%d:%d]\n" w h in *)
  let rec loop sx sy mh input =
    match input with
    [ [] -> ([],[])
    | [ (p1,img) :: tl ] -> 
        let (iw,ih) = Images.size img in
(*         let () = Printf.eprintf "hold to [%d:%d - %d [%d:%d]]\n" sx sy mh iw ih in *)
        if iw > w || ih > h
        then ([],input)
        else 
          let (sx,sy,mh) = if sx + iw >= w then (0,sy + mh,ih) else (sx,sy,max ih mh) in
          if sy + ih >= h
          then ([],input )
          else 
            let (holded,notholded) = loop (sx + iw) sy mh tl in
            ( [ (p1,(sx,sy,img)) :: holded ] , notholded )
    ]
  in
  loop 0 0 0 imgs;

value rec blit_by_textures imgs = 
(*   let () = Printf.eprintf "blit %d images\n" (List.length imgs) in *)
  try
    let res = 
      BatList.find_map begin fun size ->
        let (holded,notholded) = hold_in_size size imgs in
        match notholded with
        [ [] -> Some (size,holded)
        | _ -> None
        ]
      end [(64,64);(128,128);(256,256);(512,512)]
    in
    [ res ]
  with [ Not_found ->
    let maxsize = (1024,1024) in
    let (holded,notholded) = hold_in_size maxsize imgs in
    let hd = 
      match holded with
      [ [] -> failwith "Can't hold it in max texture"
      | _ -> (maxsize,holded)
      ]
    in
    let tl = 
      match notholded with
      [ [] -> []
      | _ -> blit_by_textures notholded
      ]
    in
    [ hd :: tl ]
  ];
*)

 

value get_objects_for_lib lib =
   List.filter begin fun (oname,info) ->
     match info.JSObjAnim.lib with
     [ Some l when lib = l-> True
     | _ -> False
     ]
   end !!info_obj;

value make_frames framesMap frames libobjects = 
  let framesIds = HSet.create 0 in
  (
    List.iter begin fun (objname,animname) ->
      let animinfo = List.assoc animname (List.assoc objname !!animations) in
      Array.iter (fun i -> HSet.add framesIds i) animinfo.JSObjAnim.frames
    end libobjects;
    (* Сформировали массив фреймов нах *)
    let framesIds = HSet.to_list framesIds in
    BatList.mapi begin fun i fid ->
      let frame = frames.(fid) in
      (
        Hashtbl.add framesMap fid i;
        frame
      )
    end framesIds 
  );

value write_textures imagesMap frames outdir = 
  let images = 
    let imageUrls = HSet.create 0 in
    (
      List.iter (fun frame -> List.iter (fun item -> HSet.add imageUrls item.urlId) frame.items) frames;
      let imgs = 
        HSet.fold begin fun urlId res ->
          let png_path = !!frames_dir.JSObjAnim.paths.(urlId) in
          let img = Images.load (!img_dir /// png_path) [] in
          [ (urlId,img) :: res ]
        end imageUrls []
      in
      List.sort (fun (_,img1) (_,img2) ->
        let (_,ih1) = Images.size img1 in
        let (_,ih2) = Images.size img2 in
        compare ih1 ih2
      ) imgs
    )
  in
  let texInfo = BatFile.open_out (outdir /// "texInfo.dat") in
  (
(*     let textures = blit_by_textures images in *)
    let textures = TextureLayout.layout images in
    let () = BatIO.write_ui16 texInfo (List.length textures) in
    BatList.iteri begin fun cnt (w,h,imgs) ->
(*       let () = Printf.eprintf "texture [%d:%d]\n%!" w h in *)
      let () = BatIO.write_string texInfo ((string_of_int cnt) ^ ".png") in
      let () = BatIO.write_ui16 texInfo (List.length imgs) in
      let rgb = Rgba32.make w h {Color.color={Color.r=0;g=0;b=0}; alpha=0;} in
      let new_img = Images.Rgba32 rgb in
      (
        BatList.iteri begin fun i (urlId,(sx,sy,img)) ->
        (
          let (iw,ih) = Images.size img in
          (
            try
              Images.blit img 0 0 new_img sx sy iw ih;
            with [ Invalid_argument _ -> 
              (
                match img with
                [ Images.Index8 _ -> prerr_endline "index8"
                | Images.Rgb24 _ -> prerr_endline "rgb24"
                | Images.Rgba32 _ -> prerr_endline "rgba32"
                | _ -> prerr_endline "other"
                ];
                raise Exit;
              )
            ];
            BatIO.write_ui16 texInfo sx;
            BatIO.write_ui16 texInfo sy;
            BatIO.write_ui16 texInfo iw;
            BatIO.write_ui16 texInfo ih;
          );
          Hashtbl.add imagesMap urlId (cnt,i);
        )
        end imgs;
        Images.save (outdir /// ((string_of_int cnt) ^ ".png")) (Some Images.Png) [] new_img;
      )
    end textures;
    BatIO.close_out texInfo;
  );


value write_frames imagesMap frames outdir = 
  let out = BatFile.open_out (outdir /// "frames.dat") in
  (
    let () = BatIO.write_i32 out (List.length frames) in
    List.iter begin fun frame ->
      (
(*         BatIO.write_i16 out frame.w; *)
(*         BatIO.write_i16 out frame.h; *)
        BatIO.write_i16 out frame.x;
        BatIO.write_i16 out frame.y;
        BatIO.write_i16 out frame.icon_x;
        BatIO.write_i16 out frame.icon_y;
        BatIO.write_byte out (List.length frame.items);
        List.iter begin fun item ->
          (
            let (texId,recId) = Hashtbl.find imagesMap item.urlId in
            (
              BatIO.write_byte out texId;
              BatIO.write_i32 out recId;
            );
            BatIO.write_i16 out item.xi;
            BatIO.write_i16 out item.yi;
            BatIO.write_byte out (if item.flip then 1 else 0);
            BatIO.write_byte out item.alpha;
          )
        end frame.items
      )
    end frames;
    BatIO.close_out out;
  );

value write_lib libname libobjects frames = 
  let () = Printf.eprintf "make lib: %s\n%!" libname in
  let framesMap = Hashtbl.create 0 in
  let frames = make_frames framesMap frames libobjects in
  (* анимации составить с учетом новых фреймов *)
  let animations = 
    List.fold_left begin fun res (objname,animname) ->
      let animinfo = List.assoc animname (List.assoc objname !!animations) in
      let frms = Array.map (fun i -> Hashtbl.find framesMap i) animinfo.JSObjAnim.frames in
      let anims = 
        try
          List.assoc objname res
        with [ Not_found -> [ ] ]
      in
      let res = List.remove_assoc objname res in
      [ (objname,[(animname,frms) :: anims]) :: res]
    end [] libobjects
  in
  let outdir = !outputDir /// libname in
  (* теперь зачитать картинки *)
  let () = Unix.mkdir outdir 0o755  in
  let imagesMap = Hashtbl.create 0 in
  let () = write_textures imagesMap frames outdir in
  let () = write_frames imagesMap frames outdir in
  let anim_out = BatFile.open_out (outdir /// "animations.dat") in
  (
    BatIO.write_ui16 anim_out (List.length animations);
    List.iter begin fun (objname,animation) ->
    (
      BatIO.write_string anim_out objname;
      BatIO.write_ui16 anim_out (List.length animation);
      List.iter begin fun (anim_name,frames) ->
      (
        BatIO.write_string anim_out anim_name;
        BatIO.write_ui16 anim_out (Array.length frames);
        Array.iter (fun frame -> BatIO.write_i32 anim_out frame) frames;
      )
      end animation;
    )
    end animations;
    BatIO.close_out anim_out;
  );

value group_by_objects (oname,info) res =
  (* Взять все анимации для объекта и это будет отдельная либа *)
  try
    let anims = List.assoc oname !!animations in
    let items = List.map (fun (animname,_) -> (oname,animname)) anims in
    Hashtbl.add res oname items;
    Some oname
  with [ Not_found -> None ];


value objects_by_levels = 
  lazy(
    let lvls = Hashtbl.create 0 in
    (
      match Json_io.load_json (!dataDir /// "levels.json") with
      [ Json_type.Object lst -> 
        List.iter begin fun (objname,level) ->
          let level = Json_type.Browse.int level in
          Hashtbl.add lvls objname level
        end lst
      | _ -> assert False
      ];
      lvls
    )
  );

value group_by_levels (oname,info) res = 
  try
    let level = Hashtbl.find !!objects_by_levels oname in
    let libname = "level_" ^ (string_of_int level) in
    (
      let anims = List.assoc oname !!animations in
      let items = List.map (fun (animname,_) -> (oname,animname)) anims in
      try
        let pitems = Hashtbl.find res libname in 
        Hashtbl.replace res libname (pitems @ items)
      with [ Not_found -> Hashtbl.add res libname items ];
      Some libname
    )
  with [ Not_found -> None ];

value group_libs = ref group_by_objects;


value set_group_libs s = 
  group_libs.val :=
    match s with
    [ "obj" -> group_by_objects
    | "levels" -> group_by_levels
    | _ -> failwith "unknown group method"
    ];

value () =
(
  let force = ref False in
  (
    Arg.parse 
      [ 
        ("-f", Arg.Set force, "force delete exists output"); 
        ("-data",Arg.Set_string dataDir,"data dir"); 
        ("-img",Arg.Set_string img_dir, "img dir"); 
        ("-o",Arg.Set_string outputDir,"output dir");
        ("-g",Arg.String set_group_libs,"group fun")
     ] (fun _ -> ()) "";
    match Sys.file_exists !outputDir with
    [ True -> 
      match !force with
      [ True -> 
          match Sys.command (Printf.sprintf "rm -rf %s" !outputDir) with
          [ 0 -> Unix.mkdir !outputDir 0o755
          | n -> exit n
          ]
      | False -> (Printf.eprintf "Directory '%s' alredy exists\n" !outputDir; exit 1)
      ]
    | False -> Unix.mkdir !outputDir 0o755
    ];
  );
  (* convert info objects to xml *)
  let out = open_out (!outputDir /// "info_objects.xml") in
  let xml = Xmlm.make_output (`Channel out) in
  (
    let () = Xmlm.output xml (`Dtd None) in
    let () = Xmlm.output xml (`El_start (("","Objects"),[])) in
    let libs = Hashtbl.create 1 in
    (
      List.iter begin fun ((oname,info) as infobj) ->
        let () = print_endline (Printf.sprintf "oname: %s" oname) in
        match !group_libs infobj libs with
        [ None -> ()
        | Some lib ->
          let attribs = [ "name" =|= oname; "sizex" =*= info.JSObjAnim.sizex; "sizey" =*= info.JSObjAnim.sizey ; "lib" =|= lib ] in
          let () = Xmlm.output xml (`El_start (("","Object"),attribs)) in
          Xmlm.output xml `El_end
        ]
     end !!info_obj;
     (* Начинаем хуячить нахуй *)
     let () = print_endline "read frames" in
     let frames = read_frames () in
     let () = print_endline "frames readed" in
     Hashtbl.iter begin fun libname elements -> 
       try
         write_lib libname elements frames
       with [ Exit -> Printf.eprintf "failed to make lib: %s\n%!" libname ]
      end libs
    );
    Xmlm.output xml `El_end;
    close_out out;
  );
);
