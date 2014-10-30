open ExtList;

module Lst =
  struct
    module type ElemS =
      sig
        type t;
        value read: IO.input -> t;
        value toString: t -> string;
        value equal: t -> t -> bool;
      end;

    module Make(Elem:ElemS) =
      struct
        type t = list Elem.t;
        value read inp = List.init (IO.read_i32 inp) (fun _ -> Elem.read inp);
        value toString t = if t = [] then "[]" else String.concat "," (List.map (fun elem -> Elem.toString elem) t);
        value equal a b = List.for_all (fun (a, b) -> Elem.equal a b) (List.combine a b);
      end;
  end;

module Rect =
  struct
    type t =
      {
        x: float;
        y: float;
        width: float;
        height: float;
      };


    value read inp =
      let x = Int32.float_of_bits (IO.read_real_i32 inp) in
      let y = Int32.float_of_bits (IO.read_real_i32 inp) in
      let width = Int32.float_of_bits (IO.read_real_i32 inp) in
      let height = Int32.float_of_bits (IO.read_real_i32 inp) in
        { x; y; width; height };

    value toString t = Printf.sprintf "(%f,%f,%f,%f)" t.x t.y t.width t.height;

    value equal a b = a.x = b.x && a.y = b.y && a.width = b.width && a.height = b.height;
  end;

module Point =
  struct
    type t =
      {
        x: float;
        y: float;
        label: string;
      };

    value read inp =
      let x     = Int32.float_of_bits (IO.read_real_i32 inp) in
      let y     = Int32.float_of_bits (IO.read_real_i32 inp) in
      let label = Utils.readUTF inp in
        { x; y; label };

    (* TODO: добавил функции для получения значений свойств *)
    value label t = t.label;
    value x t     = t.x;
    value y t     = t.y;

    value toString t = Printf.sprintf "(%s, %f, %f)" t.label t.x t.y;

    value equal a b = a.x = b.x && a.y = b.y && a.label = b.label;
  end;

module RectsList = Lst.Make(Rect);
module PointsList = Lst.Make(Point);

module Common =
  struct
    exception No_propety of string;
    exception Wrong_type of string;

    module Property =
      struct
        type kind = [= `string of string | `float of float | `bool of bool | `rects of RectsList.t | `points of PointsList.t ];

        type t =
          {
            name:string;
            kind:mutable kind;
          };

        value clone t = { name = t.name; kind = t.kind };

        value read inp =
          let name = Utils.readUTF inp in
          let tag = IO.read_byte inp in
          let kind =
            match tag with
            [ 1 -> `string (Utils.readUTF inp)
            | 2 -> `float (Int32.float_of_bits (IO.read_real_i32 inp))
            | 3 -> `bool (IO.read_byte inp > 0)
            | 4 -> `rects (RectsList.read inp)
            | 5 -> `points (PointsList.read inp)
            | _ -> assert False
            ]
          in
            { name; kind };

        value toString t =
          match t.kind with
          [ `string s -> Printf.sprintf "%s:%s" t.name s
          | `float f -> Printf.sprintf "%s:%f" t.name f
          | `bool b -> Printf.sprintf "%s:%B" t.name b
          | `rects rs -> Printf.sprintf "%s:%s" t.name (RectsList.toString rs)
          | `points ps -> Printf.sprintf "%s:%s" t.name (PointsList.toString ps)
          ];

        value create name kind = { name; kind };

        value equal a b =
          a.name = b.name &&
          match (a.kind, b.kind) with
          [ (`string a, `string b) -> a = b
          | (`float a, `float b) -> a = b
          | (`bool a, `bool b) -> a = b
          | (`rects a, `rects b) -> RectsList.equal a b
          | (`points a, `points b) -> PointsList.equal a b
          | _ -> False
          ];

        value compareByName a b = compare a.name b.name;
      end;

    module Propertiesv1 =
    	struct
    		type t = list Property.t;

    		value clone t = List.map (fun p -> Property.clone p) t;

    		value read inp = List.init (IO.read_i32 inp) (fun _ -> Property.read inp);

    		value find t name =
		      try List.find (fun p -> p.Property.name = name) t
		      with [ Not_found -> raise (No_propety name) ];

        value toString t = String.concat ", " (List.map (fun p -> Property.toString p) t);

        value equal a b = List.for_all (fun (a, b) -> Property.equal a b) (List.combine a b);

        value sortByName t = List.sort ~cmp:Property.compareByName t;
    	end;

    module Propertiesv2 =
    	struct
    		module PropsSet = Set.Make (struct type t = Property.t; value compare = Property.compareByName; end);

    		type t = PropsSet.t;

    		value clone t = PropsSet.fold (fun p props -> PropsSet.add (Property.clone p) props) t PropsSet.empty;

				value read inp =
		      let rec readProps props rest =
		        if rest = 0
		        then props
		        else
		          readProps (PropsSet.add (Property.read inp) props) (rest - 1)
		      in
		      	readProps PropsSet.empty (IO.read_i32 inp);

				value find t name =
		      try List.find (fun p -> p.Property.name = name) (PropsSet.elements t)
		      with [ Not_found -> raise (No_propety name) ];

        value toString t = String.concat ", " (List.map (fun p -> Property.toString p) (PropsSet.elements t));

        value equal a b = List.for_all (fun (a, b) -> Property.equal a b) (List.combine (PropsSet.elements a) (PropsSet.elements b));

        value sortByName t = t;
    	end;

    module Properties = Propertiesv1;

    type t =
      {
        childs: mutable list t;
        childsNum: mutable int;
        properties: mutable Properties.t;
      };

    value rec sortProps t =
      (
        t.properties := Properties.sortByName t.properties;
        List.iter (fun c -> sortProps c) t.childs;
      );

    value rec equal a b =
      Properties.equal a.properties b.properties
        && a.childsNum = b.childsNum
        && List.for_all (fun (a, b) -> equal a b) (List.combine a.childs b.childs);

    value rec clone t =
      (
        { childs = List.map (fun c -> clone c) t.childs; childsNum = t.childsNum; properties = Properties.clone t.properties };
      );

    value rec read inp =
      let properties = Properties.read inp in
      let childsNum = IO.read_i32 inp in
      let childs = List.init childsNum (fun _ -> read inp) in
        { childs; childsNum; properties };

    value childs t = t.childs;
    
    value childsNum t = t.childsNum;

    value addChilds t childs =
      (
        t.childs := t.childs @ childs;
        t.childsNum := t.childsNum + (List.length childs);
      );

    value findProp t name = Properties.find t.properties name;

    value propKind t name = (findProp t name).Property.kind;

    value strProp t name =
      match propKind t name with
      [ `string s -> s
      | _ -> raise (Wrong_type name)
      ];

    value optStrProp t name =
      try 
        match propKind t name with
        [ `string s -> Some s
        | _ -> raise (Wrong_type name)
        ]
      with [ No_propety _ -> None ];

    value floatProp t name =
      match propKind t name with
      [ `float f -> f
      | _ -> raise (Wrong_type name)
      ];

    value boolProp t name =
      match propKind t name with
      [ `bool f -> f
      | _ -> raise (Wrong_type name)
      ];

    value rectsProp t name =
      match propKind t name with
      [ `rects f -> f
      | _ -> raise (Wrong_type name)
      ];

    value pointsProp t name =
      match propKind t name with
      [ `points f -> f
      | _ -> raise (Wrong_type name)
      ];

    value setStrProp t name s =
      let prop = findProp t name in
        match prop.Property.kind with
        [ `string _ -> prop.Property.kind := `string s
        | _ -> raise (Wrong_type name)
        ];

    value setFloatProp t name f =
      let prop = findProp t name in
        match prop.Property.kind with
        [ `float _ -> prop.Property.kind := `float f
        | _ -> raise (Wrong_type name)
        ];

    value setBoolProp t name b =
      let prop = findProp t name in
        match prop.Property.kind with
        [ `bool _ -> prop.Property.kind := `bool b
        | _ -> raise (Wrong_type name)
        ];

    value setRectsProp t name r =
      let prop = findProp t name in
        match prop.Property.kind with
        [ `rects _ -> prop.Property.kind := `rects r
        | _ -> raise (Wrong_type name)
        ];

    value setPointsProp t name p =
      let prop = findProp t name in
        match prop.Property.kind with
        [ `points _ -> prop.Property.kind := `points p
        | _ -> raise (Wrong_type name)
        ];
  end;

module Layer =
  struct
    value imgPath t = Common.strProp t "imgPath";
    value flip t = Common.boolProp t "flip";
    value alpha t = Common.floatProp t "alpha";
    value x t = Common.floatProp t "x";
    value y t = Common.floatProp t "y";
    value visible t = Common.boolProp t "visible";
    value scale t = Common.floatProp t "scale";
    value scaleX t = Common.floatProp t "scaleX";
    value scaleY t = Common.floatProp t "scaleY";

    value setImgPath t s = Common.setStrProp t "imgPath" s;
    value setFlip t b = Common.setBoolProp t "flip" b;
    value setAlpha t f = Common.setFloatProp t "alpha" f;
    value setX t f = Common.setFloatProp t "x" f;
    value setY t f = Common.setFloatProp t "y" f;
    value setVisible t b = Common.setBoolProp t "visible" b;
    value setScale t f = Common.setFloatProp t "scale" f;
    value setScaleX t f = Common.setFloatProp t "scaleX" f;
    value setScaleY t f = Common.setFloatProp t "scaleY" f;

    (* value toString t = Printf.sprintf "\t\t\tlayer %s, flip %B, alpha %f, pos %f,%f, visible %B, scale %f" (imgPath t) (flip t) (alpha t) (x t) (y t) (visible t) (scale t); *)
    value toString t = Printf.sprintf "\t\t\tlayer %s" Common.(Properties.toString t.properties);
    value trace t = Printf.printf "%s\n%!" (toString t);
  end;

module Frame =
  struct
    value x t = Common.floatProp t "x";
    value y t = Common.floatProp t "y";
    value points t = Common.pointsProp t "points";

    (* value toString t = Printf.sprintf "\t\tframe %f,%f, points %s" (x t) (y t) (PointsList.toString (points t)); *)
    value toString t = Printf.sprintf "\t\tframe %s" Common.(Properties.toString t.properties);
    value trace t =
      (
        Printf.printf "%s\n%!" (toString t);
        List.iter (fun l -> Layer.trace l) t.Common.childs;
      );
  end;

module Animation =
  struct
    value name t = Common.strProp t "name";
    value lib t = Common.optStrProp t "lib";
    value frameRate t = Common.floatProp t "frameRate";
    value iconX t = Common.floatProp t "iconX";
    value iconY t = Common.floatProp t "iconY";
    value rects t = Common.rectsProp t "rects";

    (* value toString t = Printf.sprintf "\tanimation %s from lib %s, frameRate %f, icon %f,%f, rects %s" (name t) (match lib t with [ Some s -> s | _ -> "none"]) (frameRate t) (iconX t) (iconY t) (RectsList.toString (rects t)); *)
    value toString t = Printf.sprintf "\tanimation %s" Common.(Properties.toString t.properties);
    value trace t =
      (
        Printf.printf "%s\n%!" (toString t);
        List.iter (fun f -> Frame.trace f) t.Common.childs;
      );
  end;

module Object =
  struct
    value name t = Common.strProp t "name";
    value lib t = Common.optStrProp t "lib";
    value width t = Common.floatProp t "width";
    value height t = Common.floatProp t "height";

    (* value toString t = Printf.sprintf "object %s from lib %s, width %f, height %f" (name t) (match lib t with [ Some s -> s | _ -> "none"]) (width t) (height t); *)
    value toString t = Printf.sprintf "object %s" Common.(Properties.toString t.properties);
    value trace t =
      (
        Printf.printf "%s\n%!" (toString t);
        List.iter (fun a -> Animation.trace a) t.Common.childs;
      );
  end;

module Project =
  struct
    value objects t = t.Common.childs;
    value objectsNum t = t.Common.childsNum;
    value trace t = List.iter (fun o -> Object.trace o) t.Common.childs;
  end;
