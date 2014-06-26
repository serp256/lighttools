open ExtString;

module Filter = struct
  type t = [ I of string | IF of string |  E of string | EF of string | P of string | M of string | DM of string | H of string | S of string | R of string ];

  value toStr t =
    match t with
    [ I s -> "+ " ^ s
    | IF s -> "+! " ^ s
    | E s -> "- " ^ s
    | EF s -> "-! " ^ s
    | P s -> "P " ^ s
    | M s -> "." ^ s
    | DM s -> ":" ^ s
    | H s -> "H" ^ s
    | S s -> "S" ^ s
    | R s -> "R" ^ s
    ];
end;

module Rule = struct
  type t =
    {
      src: list string;
      dst: string;
      filters: list Filter.t;
      delExcl: bool;
    };

  value rule ?(delExcl = False) ?(filters = []) ~src ~dst () = { src; dst; filters; delExcl };
end;

value rsync = "rsync -rLptgoDv";
value profile = ref None;

value defs = Hashtbl.create 10;
value args = 
  [
    ("-def", Arg.String (fun def -> try let (k, v) = String.split def "=" in Hashtbl.add defs k v with [ Invalid_string -> failwith "wrong -def option value, should be something like -def key=value"]), "define key-value pair, example: -def key=value")
  ];
value def k = try Hashtbl.find defs k with [ Not_found -> failwith ("cannot find define for key '" ^ k ^ "'") ];

Arg.parse args (fun arg -> match !profile with [ None -> profile.val := Some arg | _ -> () ]) "";

value run rules =
  (
    List.iter (fun rule ->
      let fs = String.concat " " (List.map (fun f -> "--filter=\"" ^ (Filter.toStr f) ^ "\"") rule.Rule.filters) in
      let src = String.concat " " rule.Rule.src in
      let cmd = Printf.sprintf "%s %s %s %s %s" rsync (if rule.Rule.delExcl then " --delete-excluded" else "") fs src rule.Rule.dst in
      let _ = Printf.printf "%s\n%!" cmd in
        if Sys.command cmd <> 0
        then failwith "rsync failed"
        else ()
    ) rules;    
  );

value profile = match !profile with [ Some p -> p | _ -> failwith "You should provide profile name" ];