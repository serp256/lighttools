(* Скрипт пакует данные swf потрошителя *)
(* TODO:
  * clip_commands - может быть некорректный после dublicate (fsep mode)
  * можно еще пооптимайзить символы если sep - возможно что-то врисуется как надо
  * сохранить боксы везде, если их выкидываешь а потом вдруг клип становится спрайтом
*)

open ExtList;
open ExtString;
open Printf;

value (=|=) k v = (("",k),v);
value (=.=) k v = k =|= string_of_float v;
value (=*=) k v = k =|= string_of_int v;



value npot = ref False;
value alpha = ref False;
value use_atlases = ref True;


open RBase;
open ImageOptimize;
open RClips;

value nreg = Str.regexp "^instance[0-9]+$";

value rec process_children dirname children = 
  let lst = 
    List.filter_map begin fun child ->
      let child = jobject child in
      let ctype =  jstring (List.assoc "type" child) in
      let pos = getpos child in
      match ctype with
      [ "box" -> Some (`box (pos,jstring (List.assoc "name" child)))
      | _ ->
        let name = 
          try 
              let name = jstring (List.assoc "name" child) in
              match Str.string_match nreg name 0 with
              [ True -> None
              | False -> Some name 
              ]
          with [ Not_found -> None ] in
        let id = 
          match ctype with
          [ "image" -> (push_child_image dirname child)
          | "clip" | "sprite" -> process_dir (dirname // (jstring (List.assoc "dir" child)))
          | _ -> assert False
          ]
        in
        match id with
        [ Some id -> Some (`chld (id,name,pos))
        | None  -> None
        ]
      ]
    end (jlist children)
  in
  match lst with
  [ [] -> None
  | _ ->  Some (DynArray.of_list lst)
  ]
and process_dir dirname = (* найти мету в этой директории и от нее плясать *)
  let () = printf "process directory: %s\n%!" dirname in
  let mobj = jobject (Ojson.from_file (dirname // "meta.json") ) in
  match jstring (List.assoc "type" mobj) with
  [ "image" -> push_child_image dirname mobj
  | "sprite" -> 
      let children = process_children dirname (List.assoc "children" mobj) in
      match children with
      [ Some children -> Some (push_item (`sprite children))
      | None -> None
      ]
  | "clip" ->
      let lframes = 
        List.filter_map begin fun frame ->
          let frame = jobject frame in 
          let label = try Some (jstring (List.assoc "label" frame)) with [ Not_found -> None ] in
          let children = process_children dirname (List.assoc "children" frame) in
          match children with
          [ Some children ->
            let () = DynArray.filter (fun [ `chld _ -> True | _ -> False ]) children in
            Some {label;commands=None;children;duration=1}
          | None -> None
          ]
        end (jlist (List.assoc "frames" mobj))
      in
      (* вычислим duration *)
      match lframes with
      [ [] -> None
      | _ -> 
        let frames = DynArray.create () in
        (
          List.iter begin fun frame -> 
            match (DynArray.length frames > 0, lazy (DynArray.last frames)) with
            [ (True, lazy lframe ) when compare_frame lframe frame -> lframe.duration := lframe.duration + 1
            | _ -> DynArray.add frames frame 
            ]
          end lframes;
          Some (push_item (`clip frames))
        )
      ]
  | _ -> assert False
  ];



value optimize_sprites () = 
  DEFINE optimize =
    match DynArray.get children 0 with
    [ `chld (id,_,pos) when pos.x = 0. && pos.y = 0. -> 
      (
        DynArray.set exports i (name,id);
        item.deleted := True;
        True
      )
    | `chld _ -> False
    | _ -> assert False 
    ]
  IN
  for i = 0 to DynArray.length exports - 1 do
    let (name,id) = DynArray.get exports i in
    let item = DynArray.get items id in
    match item.item with
    [ `sprite children when DynArray.length children = 1 -> ignore(optimize)
    | `clip frames when DynArray.length frames = 1 -> 
        let children = (DynArray.get frames 0).children in
        if (DynArray.length children = 1 && not optimize) || (DynArray.length children > 1)
        then DynArray.set items id {(item) with item = (`sprite children)}
        else ()
    | _ -> ()
    ]
  done;




value indir = ref "input";
value outdir = ref "output";



(* сделать список списков картинок - сгрупирровав их по символам экспорта *)
value group_images_by_symbols () =
  DynArray.fold_left begin fun res (_,id) ->
    let item = DynArray.get items id in
    match item.item with
    [ `image _ -> [ (item.item_id,(True, [ (item.item_id,(Hashtbl.find images item.item_id)) ])) :: res ]
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
        let imgs = List.unique ~cmp:(fun (id1,_) (id2,_) -> id1 = id2) imgs in
        [ (item.item_id,(True,imgs)) :: res ] (* Тру здесь не всегда может быть тру, из-за боксов *)
    | `clip frames ->
        let (wholly,imgs) = 
          DynArray.fold_left begin fun (wholly,res) frame ->
            let res = 
              DynArray.fold_left begin fun res -> fun
                [ `chld (id,_,_) ->
                  match (DynArray.get items id).item with
                  [ `image _ -> [ (id,Hashtbl.find images id) :: res ]
                  | _ -> assert False
                  ]
                | _ -> res
                ]
              end res frame.children
            in
            (wholly && DynArray.length frame.children > 1, res)
          end (True,[]) frames
        in
        let imgs = List.unique ~cmp:(fun (id1,_) (id2,_) -> id1 = id2) imgs in
        [ (item.item_id,(True,imgs)) :: res ]
    ]
  end [] exports;

(* если группы имеют общие картинки то нужно объеденить эти группы *)
value merge_symbol_images imgs = 
  let imgs = List.map snd imgs in
  let (wholly_groups,unwholly_groups) = List.partition (fun (wholly,group) -> wholly) imgs in
  (* теперь объеденить между собой все wholly группы *)
  let wholly_groups = 
    let rec merge_wholly imgs res = 
      match imgs with
      [ [] -> res
      | [ (wholly,imgs) :: rest ] -> (* если эта группа цельная должна быть, тогда нужно найти все картинки которые она шарит *)
          let (commons,others) =
            List.partition begin fun (_,imgs') ->
              List.exists (fun (id,_) -> List.exists (fun (id',_) -> id = id') imgs') imgs
            end rest
          in
          merge_wholly others [ (wholly,List.unique ~cmp:(fun (id1,_) (id2,_) -> id1 = id2) (imgs @ (List.concat (List.map snd commons)))) :: res ]
      ]
    in
    merge_wholly wholly_groups []
  in
  (* а теперь вытащить все картинки из не wholly групп к wholly *)
  let unwholly_groups = 
    List.map begin fun (wholly,imgs) ->
      (wholly,
        List.filter begin fun (id,_) -> 
          not (List.exists (fun (_,imgs') -> List.exists (fun (id',_) -> id' = id) imgs') wholly_groups)
        end imgs
      )
    end unwholly_groups
  in
  let unwholly_groups = List.filter (fun (_,imgs) -> imgs <> []) unwholly_groups in
  (wholly_groups @ unwholly_groups);




value dublicate_symbol_images imgs = 
  (* бля нужно двигать сцанные ID - это пиздец как геморно нахуй, ну просто выебешься *)
  let dublicate symbol_id img_id img =
    let item = DynArray.get items symbol_id in
    let new_img_id = push_new_image img in
    (
      match item.item with
      [ `image _  -> 
        let idx = DynArray.index_of (fun (_,id) -> id = symbol_id) exports in
        DynArray.set exports idx (fst (DynArray.get exports idx),new_img_id)
      | `sprite children -> 
          DynArray.iteri begin fun i child ->
            match child with
            [ `chld (id,pos,label) when id = img_id ->
              match (DynArray.get items id).item with
              [ `image _ -> DynArray.set children i (`chld (new_img_id,pos,label))
              | _ -> assert False
              ]
            | _ -> ()
            ]
          end children
      | `clip frames -> 
          DynArray.iter begin fun frame ->
            DynArray.iteri begin fun i -> fun
              [ `chld (id,pos,label) when id = img_id ->
                match (DynArray.get items id).item with
                [ `image _ -> DynArray.set frame.children i (`chld (new_img_id,pos,label))
                | _ -> assert False
                ]
              | _ -> ()
              ]
            end frame.children
          end frames
      ];
      new_img_id
    )
  in
  let rec find_dublicates imgs res = 
    match imgs with
    [ [] -> res
    | [ (item_id,(wholly,imgs)) :: rest ] ->
        let imgs = 
          List.map begin fun ((img_id,img) as imgp) ->
            match List.exists (fun (_,(_,oimgs)) -> List.exists (fun (img_id',_) -> img_id' = img_id) oimgs) rest with
            [ True -> (* бля, дубликат нужно задублицировать дичайше *)
              (
                let (w,h) = Images.size img in
                Printf.printf "WARN: DUBLICATE image %d [%d:%d]\n%!" img_id w h;
                (dublicate item_id img_id img,img)
              )
            | False -> imgp
            ]
          end imgs
        in
        find_dublicates rest [ (wholly,imgs) :: res ]
    ]
  in
  find_dublicates imgs [];

value sorted_items () =
  let sitems = DynArray.to_array items in
  (
    let modified = ref True in
    let img_idx = ref 0 in
    while !modified do
      let () = modified.val := False in
      let imgs_only = ref True in
      for i = 0 to Array.length sitems - 1 do
        let item = sitems.(i) in
        match item.item with
        [ `image _ when !imgs_only -> img_idx.val := i
        | `image _ ->
          (
            let () = incr img_idx in
            for j = i downto !img_idx + 1 do
              sitems.(j) := sitems.(j - 1);
            done;
            sitems.(!img_idx) := item;
            modified.val := True;
          )
        | _ -> imgs_only.val := False
        ]
      done;
    done;
    sitems;
  );

type fmt = [ FPng | FPvr | FPlx of string ];

value do_work isXml pack_mode fmt indir suffix outdir =
(
  Printf.printf "DOWORK: %s -> %s[%s]\n%!" indir outdir suffix;
  Array.iter begin fun fl ->
    let dirname = indir // fl in
    let (name,item_id) = 
      if Sys.is_directory dirname
      then 
        match process_dir dirname with
        [ Some res -> (fl,res)
        | None -> failwith (Printf.sprintf "Empty symbol %s" fl)
        ]
      else 
        let item_id = push_image (`path dirname) in
        (Filename.chop_extension fl,item_id)
    in
    DynArray.add exports (name,item_id)
  end (Sys.readdir indir);
  merge_images();
(*   print_endline "images merged"; *)
  optimize_sprites();
(*   print_endline "sprites and clips optmized"; *)
  make_clip_commands ();
(*   print_endline "clip commands done"; *)
  let pack_textures pages = 
    List.mapi begin fun idx {TextureLayout.width=w;height=h;placed_images=imgs;_} ->
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
        let extension = if !alpha then ".alpha" else ".png" in
        let imgname = imgbasename ^ extension  in
        (
          if !alpha then (
            Utils.save_alpha (Images.Rgba32 texture) (outdir // imgname) 
          )
          else
          Images.save (outdir // imgname) (Some Images.Png) [] (Images.Rgba32 texture);
          match fmt with
          [ FPvr ->
            (
              Utils.dxt_png (outdir // imgbasename);
              Utils.pvr_png (outdir // imgbasename);
            )
          | FPlx plt -> Utils.plx_png plt (outdir // imgbasename)
          | FPng -> ()
          ];
          imgname;
        )
      )
    end pages
  in
  let gimages = group_images_by_symbols () in
(*   let () = print_endline "images grouped" in *)
  let tsize = TextureLayout.(if fmt = FPvr then Sqr else match !npot with [ True -> Npot | _ -> Pot ]) in
  let textures = 
    match pack_mode with
    [ PackFSep | PackSep -> 
      let gimages = 
        match pack_mode with
        [ PackFSep -> dublicate_symbol_images gimages
        | _ -> merge_symbol_images gimages
        ]
      in
      let pages = 
        List.fold_left begin fun res (wholly,images) ->
          match wholly with
          [ True -> 
            let (page,rest) = TextureLayout.layout_page ~tsize images in
            let () = assert (rest = []) in
            [ page :: res ]
          | False ->
              let pages = TextureLayout.layout ~tsize images in
              pages @ res
          ]
        end [] gimages
      in
      pack_textures pages
    | PackGroup ->
       let () = Printf.printf "group packing: %d %B %d\n%!" (List.length gimages) (fst (snd (List.hd gimages))) (List.length (snd (snd (List.hd gimages)))) in
       let gimages =  merge_symbol_images gimages in
       let () = Printf.printf "images merged" in
       let pages = TextureLayout.layout_max ~tsize gimages in
       let () = print_endline "textures pages created" in
       pack_textures pages
    ]
  in
(*   let () = print_endline "textures created" in *)
  let group_children = 
    if not !use_atlases 
    then fun children ->  ((DynArray.to_list children) :> (list [= child | `atlas of list img ]))
    else
    fun children ->
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
  (* отсортировать items чтобы все картинки были в начале *)
  let sitems = sorted_items () in
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
      Array.iter begin fun 
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
      end sitems;(*}}}*)
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
		let write_un_byte binout n = 
			if n < (1 lsl 7) then
				IO.write_byte binout n
			else
			(
				IO.write_byte binout ((n lsr 8) lor (1 lsl 7));
				IO.write_byte binout (n mod (1 lsl 8));
			)
		in
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
(*     let nreg = Str.regexp "^instance[0-9]+$" in *)
    let write_name = fun
(*       [ Some name when Str.string_match nreg name 0 -> IO.write_byte binout 0 *)
      [ Some name ->
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
        let () = write_un_byte binout (List.length children) in
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
							write_un_byte binout (List.length els);
              List.iter write_child els;
            )
          ]
        end children
      in
      let write_children children = 
        let () = write_un_byte binout (DynArray.length children) in
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
      Array.iter begin fun 
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
      end sitems;
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
  let pack_mode = ref PackGroup in
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
        ("-pack",Arg.String begin fun p ->
          pack_mode.val := 
            match p with
            [ "sep" -> PackSep 
            | "fsep" -> PackFSep 
            | "group" -> PackGroup
            | _ -> failwith "incorrect pack mode"
            ]
          end,
          "packing mode [ sep - try to separate | group (default) - all in one | fsep - force sep may cause dublicates ]"
        );
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
        );
        ("-npot",Arg.Set npot, "Not power of 2");
        ("-alpha",Arg.Set alpha, "Save as alpha");
        ("-skip-atlases",Arg.Clear use_atlases, "Dont use atlases")
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
                do_work !xml !pack_mode fmt indir suffix outdir;
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
