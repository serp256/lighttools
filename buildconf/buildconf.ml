




(* Находит в текущей папке myocamlbuild.ml и апдейтит его иначе создает новый *)



value (//) = Filename.concat;

value mbuild = "myocamlbuild.ml";
value start_config_line = "(* __ LIGHTNING CONFIG START __ *)";
value end_config_line = "(* __ LIGHTNING CONFIG END __ *)";
value light_path = ref None;

value _lightning_path = 
  lazy (
    match !light_path with
    [ None ->
      try
        Sys.getenv "LIGHTNING_PATH"
      with [ Not_found -> (Sys.getenv "HOME") // "/Projects/lightning" ]
    | Some path -> path
    ];
  );

value lightning_path () = Lazy.force _lightning_path;

value _include_file = lazy ((lightning_path()) // "ocaml/myocamlbuild.ml");
value include_file () = Lazy.force _include_file;

value check_include () = 
  match Sys.file_exists (include_file()) with
  [ True -> ()
  | False -> failwith (Printf.sprintf "'%s' not found'" (include_file()))
  ];


value do_include out = 
  let incl = open_in (include_file ()) in
  (
    (* transfer content *)
    loop () where
      rec loop () = 
        try
          output_char out '\n';
          let line = input_line incl in
          output_string out line;
          loop ();
        with [ End_of_file -> () ];
    close_in incl;
  );



(* нужно путь до экзампла нах. *)
value create () =
  let () = print_endline "create new myocamlbuild.ml" in
  let mb = open_out mbuild in
  (
    output_string mb "let ios_path = failwith \"put here path to your xcode project with AppDelegate and main\"\n";
    output_string mb "let main = failwith \"put here name of main binary without suffix\"\n\n";
    output_string mb start_config_line; 
    do_include mb;
    output_string mb end_config_line;
    output_string mb "\n\n\n(* ENTER YOUR CODE HERE *)\nlet my_dispatch = function | After_rules -> () | _ -> ();;\n\n";
    output_string mb "let _ = dispatch (function stage -> lightning_dispatch stage; my_dispatch stage);;\n";
    close_out mb;
  );



value update () = 
  let () = print_endline "update myocamlbuild.ml" in
  (* бля тут уже сложнее нах. *)
  let tmpb = mbuild ^ ".tmp" in
  let () = Sys.rename mbuild tmpb in
  let omb = open_in tmpb 
  and mb = open_out mbuild in
  (
    (* читаем файл исходный и пишем в новый пока не встретим нашу заветную линию *)
    let skip_to_config_end () = 
      let pos = pos_in omb in
      loop () where
        rec loop () = 
          try
            let line = input_line omb in
            match line = end_config_line with
            [ True -> True
            | False -> loop ()
            ]
          with [ End_of_file -> (prerr_endline "[ERROR] corrupted myocamlbuid.ml, can't do job";  seek_in omb pos; False) ]
    in
    transfer True where
      rec transfer find_start = 
        try 
          let line = input_line omb in
          (
            output_string mb line;
            output_char mb '\n';
            match find_start with
            [ True ->
              match line = start_config_line with
              [ True -> 
                match skip_to_config_end () with
                [ True ->
                  (
                    do_include mb;
                    output_string mb end_config_line;
                    output_char mb '\n';
                    transfer False;
                  )
                | False -> transfer False
                ]
              | False -> transfer True 
              ]
            |  False -> transfer False
            ]
          )
        with [ End_of_file when find_start ->  print_endline "[ERROR] file incorrect can't do job" | End_of_file -> () ];
      close_in omb;
      close_out mb;
  );


check_include ();
if Sys.file_exists mbuild 
then update ()
else create ();
