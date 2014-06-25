module Filter = struct
  type t = [ I of string | E of string | P of string | M of string | DM of string | H of string | S of string | R of string ];

  value toStr t =
    match t with
    [ I s -> "+ " ^ s
    | E s -> "- " ^ s
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
    };
end;

value rsync = "rsync -rLptgoDv";

value run rules =
  List.iter (fun rule ->
    let fs = String.concat " " (List.map (fun f -> "--filter=\"" ^ (Filter.toStr f) ^ "\"") rule.Rule.filters) in
    let src = String.concat " " rule.Rule.src in
    let cmd = Printf.sprintf "%s %s %s %s" rsync fs src rule.Rule.dst in
    let _ = Printf.printf "%s\n%!" cmd in
      if Sys.command cmd <> 0
      then failwith "rsync failed"
      else ()
  ) rules;

value profile = ref None;

Arg.parse [] (fun arg -> match !profile with [ None -> profile.val := Some arg | _ -> () ]) "";

value profile = match !profile with [ Some p -> p | _ -> failwith "You should provide profile name" ];