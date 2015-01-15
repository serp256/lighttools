open Node;
open Ojson;

exception No_lib of string;

(* module ObjsSet = Set.Make(struct type t = Common.t; value compare objA objB = compare (Object.name objA) (Object.name objB); end); *)
module ObjsSet = Set.Make(struct type t = string; value compare = compare; end);
module AnimsSet = Set.Make(struct type t = Common.t; value compare animA animB = compare (Animation.name animA) (Animation.name animB); end);

module Lib =
  struct
    exception No_object of string;

    type t =
      {
        name: string;
        objs: mutable ObjsSet.t;
        anims: Hashtbl.t string AnimsSet.t;
      };

    value create name = { name; objs = ObjsSet.empty; anims = Hashtbl.create 0 };

    value name t = t.name;

    value addObj t obj = t.objs := ObjsSet.add obj t.objs;

    value addAnimOf ~obj t anim =
      (* let obj = Object.name obj in       *)
        try
          let anims = Hashtbl.find t.anims obj in
            Hashtbl.replace t.anims obj (AnimsSet.add anim anims)
        with [ Not_found -> Hashtbl.add t.anims obj (AnimsSet.singleton anim) ];

    value foldObjs f t r = ObjsSet.fold f t.objs r;

    value foldAnimsOf ~obj f t r =
      try AnimsSet.fold f (Hashtbl.find t.anims obj) r
      with [ Not_found -> raise (No_object obj) ];

    value iterObjs f t = ObjsSet.iter f t.objs;

    value iterAnimsOf ~obj f t =
      try AnimsSet.iter f (Hashtbl.find t.anims obj)
      with [ Not_found -> raise (No_object obj) ];

    value images t =
      let imgs = Hashtbl.create 0 in
        (
          Hashtbl.iter (fun _ anims ->
            AnimsSet.iter (fun a ->
              List.iter (fun f ->
                List.iter (fun l ->
                  Hashtbl.replace imgs (Layer.imgPath l) 0
                ) (Common.childs f)
              ) (Common.childs a)
            ) anims
          ) t.anims;

          let retval = ExtList.List.of_enum (ExtHashtbl.Hashtbl.keys imgs) in
            (
              Hashtbl.clear imgs;
              retval;     
            );
        );

    value sortNodesProps t =
      iterObjs (fun o ->
        iterAnimsOf ~obj:o (fun a ->
          Node.Common.sortProps a          
        ) t 
      ) t;

    value checksum t =
      (
        sortNodesProps t;
        Marshal.to_string t [];
      );
  end;

module LibsSet = Set.Make(struct type t = Lib.t; value compare libA libB = compare (Lib.name libA) (Lib.name libB); end);

type t = LibsSet.t;

value ofProject p =
  let h = Hashtbl.create 0 in
    (
      List.iter (fun o ->
        let () = Printf.printf "OBJECT %s \n%!" (Object.toString o) in
        match Object.lib o with
        [ Some l ->
          (
            List.iter (fun a ->
              if Common.childs a <> []
              then
                let l = match Animation.lib a with [ Some l -> l | _ -> l ] in
                let l = try Hashtbl.find h l with [ Not_found -> let l = Lib.create l in ( Hashtbl.add h (Lib.name l) l; l ) ] in
                let o = Object.name o in
                  (
                    Lib.addObj l o;
                    Lib.addAnimOf ~obj:o l a;
                  )
              else ()
            ) (Common.childs o);
          )
        | _ -> failwith (Printf.sprintf "library is not setted for object %s" (Object.name o))
        ]
      ) (Project.objects p);

      let t = Hashtbl.fold (fun _ l t -> LibsSet.add l t) h LibsSet.empty in
        (
          Hashtbl.clear h;
          t;
        );
    );

value iter f t = LibsSet.iter f t;

value trace t = Printf.printf "%s\n%!" (String.concat ", " (LibsSet.fold (fun l lst -> lst @ [ Lib.name l ]) t []));

value exist t name = LibsSet.exists (fun l -> Lib.name l = name) t;

(* module Lib =
  struct
    exception No_object of string;

    type t =
      {
        name: string;
        objs: mutable (list Common.t);
        anims: mutable list (string * list Common.t);
      };

    value create name = { name; objs = []; anims = [] };

    value name t = t.name;

    value checksum t = Marshal.to_string t [];

    value addObj t obj =
      if List.mem obj t.objs
      then ()
      else t.objs := [ obj :: t.objs ];

    value addAnimOf ~obj t anim =
      let obj = Object.name obj in      
        try
          let anims = List.assoc obj t.anims in
          let anims' = List.remove_assoc obj t.anims in
            t.anims := [ (obj, [ anim :: anims ]) :: anims' ]
        with [ Not_found -> t.anims := [ (obj, [anim]) :: t.anims ] ];

    value foldObjs f t r = List.fold_left (fun r o -> f o r) r t.objs;

    value foldAnimsOf ~obj f t r =
      let obj = Object.name obj in
        try List.fold_left (fun r o -> f o r) r (List.assoc obj t.anims)
        with [ Not_found -> raise (No_object obj) ];

    value iterObjs f t = List.iter f t;

    value iterAnimsOf ~obj f t =
      let obj = Object.name obj in
        try List.iter f (List.assoc obj t.anims)
        with [ Not_found -> raise (No_object obj) ];
  end;

type t = list Lib.t;

value ofProject p =
  let h = Hashtbl.create 0 in
    (
      List.iter (fun o ->
        match Object.lib o with
        [ Some l ->
          (
            List.iter (fun a ->
              if Common.childs a <> []
              then
                let l = match Animation.lib a with [ Some l -> l | _ -> l ] in
                let l = try Hashtbl.find h l with [ Not_found -> let l = Lib.create l in ( Hashtbl.add h (Lib.name l) l; l ) ] in
                  (
                    Lib.addObj l o;
                    Lib.addAnimOf ~obj:o l a;
                  )
              else ()
            ) (Common.childs o);
          )
        | _ -> failwith (Printf.sprintf "library is not setted for object %s" (Object.name o))
        ]
      ) (Project.objects p);

      let t = ExtList.List.sort ~cmp:(fun la lb -> Lib.(compare (name la) (name lb))) (Hashtbl.fold (fun _ l t -> [ l :: t ]) h []) in
        (
          Hashtbl.reset h;
          t;
        );
    );

value iter f t = List.iter f t;

(* value trace t = Printf.printf "%s\n%!" (String.concat ", " (LibsSet.fold (fun l lst -> lst @ [ Lib.name l ]) t [])); *)

value exist t name = List.exists (fun l -> Lib.name l = name) t; *)
