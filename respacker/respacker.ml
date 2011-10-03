(* Скрипт пакует данные swf потрошителя *)
open ExtList;
open ExtString;
open Printf;

value (//) = Filename.concat;
value (=|=) k v = (("",k),v);
value (=.=) k v = k =|= string_of_float v;
value (=*=) k v = k =|= string_of_int v;

value bgcolor = {Color.color = {Color.r = 0; g = 0; b = 0}; alpha = 0};

(*
*)

(*
type element = 
  [= `image of Texture.c
  | `sprite of list sprite_element
  | `clip of array frame
  ]
and sprite_element = (element * Point.t)
and frame =
{ 
  hotpos: Point.t;
  content: element;
  label: string; (* ну тут еще duration нужон но это после нах. *)
};

type lib = Hashtbl.t string element;
*)

type pos = (float*float);
type texinfo = {page:mutable int; x:mutable int;y:mutable int; width: int;height:int};
type children = list (int * option string * pos);
type frame = {children:children; label: option string; duration: mutable int};
type iteminfo = [= `image of texinfo | `sprite of children | `clip of list frame ];

value items : DynArray.t iteminfo = DynArray.create ();

(* value compare_img img1 img2 =  *)
  (* возвращает либо что полностью идентичны, либо что отличаюца только по альфе *)

value push_item item =
  try
    match item with
    [ `sprite _ | `clip _ -> DynArray.index_of (fun i -> i = item) items
    | `image _ -> raise Not_found
    ]
  with 
  [ Not_found ->
    (
      DynArray.add items item;
      (DynArray.length items) - 1;
    )
  ];

value images = RefList.empty ();


value add_image dirname mobj = 
  let img = Images.load (dirname // (Json_type.Browse.string (List.assoc "file" mobj))) [] in
  try
    let (id,_) = RefList.find (fun (id,img') -> img = img') images in
    id
  with 
  [ Not_found ->
      let id = 
        let (width,height) = Images.size img in
        push_item (`image {page=0;x=0;y=0;width;height}) 
      in
      (
        RefList.push images (id,img);
        id
      )
  ];

value getpos jsinfo = let open Json_type.Browse in (number (List.assoc "x" jsinfo),number (List.assoc "y" jsinfo));

(* можно при добавлении картинок палить что они такие-же только разница в альфе - это легко 
 * а в группировке есть засада, что мы можем не понять что это одно и тоже так как мы с чем-то слепим и будет не круто
 * *)

(* value calc_diff oldchildrens newchildrens =  *)

value rec process_children dirname children = 
  let open Json_type.Browse in
  list begin fun child ->
    let child = objekt child in
    let name = try Some (string (List.assoc "name" child)) with [ Not_found -> None ] in
    let pos = getpos child in
    let id = 
      match string (List.assoc "type" child) with
      [ "image" -> add_image dirname child
      | "clip" -> process_dir (dirname // (string (List.assoc "dir" child)))
      | _ -> assert False
      ]
    in
    (id,name,pos)
  end children
and process_dir dirname = (* найти мету в этой директории и от нее плясать *)
  let () = printf "process directory: %s\n%!" dirname in
  let meta = Json_io.load_json (dirname // "meta.json") in
  let open Json_type.Browse in
  let mobj = objekt meta in
  match string (List.assoc "type" mobj) with
  [ "image" -> add_image dirname mobj
  | "sprite" -> 
      let children = process_children dirname (List.assoc "children" mobj) in
      push_item (`sprite children)
  | "clip" ->
      let frames = 
        list begin fun frame ->
          let frame = objekt frame in 
          let label = try Some (string (List.assoc "label" frame)) with [ Not_found -> None ] in
          let children = process_children dirname (List.assoc "children" frame) in
          {label;children;duration=1}
        end (List.assoc "frames" mobj)
      in
      (* вычислим duration *)
      (* FIXME: придумать сдесь механизм изменений *)
      let frames = 
        List.fold_left begin fun frames frame -> 
          match frames with
          [ [ pframe :: _ ] when pframe = frame -> 
            (
              pframe.duration := pframe.duration + 1;
              frames
            )
          | _ -> [ frame :: frames ]
          ]
        end [] frames
      in
      push_item (`clip (List.rev frames))
  | _ -> assert False
  ];

value outdir = ref "output";

value do_work indir =
  let exports = RefList.empty () in
  (
    Array.iter begin fun fl ->
      let dirname = indir // fl in
      if Sys.is_directory dirname
      then
        let item_id = process_dir dirname in
        RefList.push exports (fl,item_id)
      else ()
    end (Sys.readdir indir);
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
        let pages = TextureLayout.layout (RefList.to_list images) in
        List.iteri begin fun i (w,h,imgs) ->
          let texture = Rgba32.make w h bgcolor in
          (
            List.iter begin fun (key,(x,y,img)) ->
            (
              let img = match img with [ Images.Rgba32 img -> img | _ -> assert False ] in
              Rgba32.blit img 0 0 texture x y img.Rgba32.width img.Rgba32.height;
              match DynArray.get items key with
              [ `image inf -> ( inf.x := x; inf.y := y; inf.page := i;)
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
        let write_children = 
          List.iter begin fun (id,name,(posX,posY)) ->
            (
              let attrs = [ "id" =*= id; "posX" =.= posX; "posY" =.= posY ] in
              let attrs = match name with [ Some n -> [ "name" =|= n :: attrs ] | None -> attrs ] in
              Xmlm.output xmlout (`El_start (("","child"),attrs));
              Xmlm.output xmlout `El_end;
            )
          end 
        in
        DynArray.iteri begin fun id item -> 
          (
            match item with
            [ `image info -> 
              let attributes = 
                [
                  "type" =|= "image";
                  "texture" =*= info.page;
                  "x" =*= info.x;
                  "y" =*= info.y;
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
                List.iter begin fun frame ->
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
