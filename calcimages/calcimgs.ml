open Images;
open ExtList;


value nop = ref False;
value donop x = match !nop with [ True -> Utils.nextPowerOfTwo x | False -> x];
value verbose = ref False;
value recursive = ref False;
value nop = ref False;
value suffix = ref None;
value esuffix = ref [];

value pvr = ref False;


value mgb = 1024 * 1024;
value kb = 1024;

value format_size s = 
  if s >= mgb 
  then 
    Printf.sprintf "%.3f MB" ((float s) /. (float mgb))
  else
    if s >= kb
    then
      Printf.sprintf "%.3f KB" ((float s) /. (float kb))
    else
      Printf.sprintf "%dB" s
;


value string_of_infos infos = 
  match infos with
  [ [] ->  ""
  | _ -> "some"
  ];



value result = DynArray.make 10;

value print_result () = 
  let result = DynArray.to_array result in
  (
    Array.sort (fun (_,s1) (_,s2) -> compare s1 s2) result;
    Array.iter (fun (fn,s) -> Printf.printf "\t%s\t\t\t%s\n" fn (format_size s)) result;
  );

value add_result (cnt,size) fn s = 
(
  if !verbose then DynArray.add result (fn,s) else ();
  (cnt + 1,size + s);
);

value check_suffix name = 
  let res = 
    match !suffix with
    [ Some s -> ExtString.String.ends_with name s
    | None -> True
    ]
  in
  match res with
  [ True ->
    match !esuffix with
    [ [] -> True
    | lst -> not (List.exists (fun es -> ExtString.String.ends_with name es) lst)
    ]
  | False -> False
  ];


  value gzip_size fn =
    let gzout = Unix.open_process_in (Printf.sprintf "gzip -l %s" fn) in
    let res = 
      try
        let _ = input_line gzout in
        Scanf.bscanf (Scanf.Scanning.from_channel gzout) " %d %d" (fun _ uc -> uc)
      with [ End_of_file ->
        let s = Unix.stat fn in
        s.Unix.st_size
      ]
    in
    (
      Unix.close_process_in gzout |> ignore;
      res;
    );


value calc_file fn ((cnt,size) as res) =
  let iname = Utils.chop_ext fn in
  match check_suffix iname with
  [ False -> res
  | True ->
    let ext = Utils.get_ext fn in
    match ext with
    [ "alpha" ->
      let gzin = Utils.gzip_input fn in
      let w = IO.read_ui16 gzin in
      let h = IO.read_ui16 gzin in
      add_result res fn (w*h)
    | "cmprs" | "pvr" | "dds" | "atc" | "etc" -> 
        let size = gzip_size fn in
        add_result res fn (size - 52) (* FIXME: meta in pvr3, ну да хуй с ней *)
    | "plx" ->
        let gzin = Utils.gzip_input fn in
        (
          ignore (IO.read_byte gzin);
          let w = IO.read_ui16 gzin
          and h = IO.read_ui16 gzin in
          (
            IO.close_in gzin;
            add_result res fn (w * h * 2);
          )
        )
    | "png" | "jpg" ->
        try
          let (fmt,header) = Images.file_format fn in
          let bpp = 
            match fmt with
            [ Jpeg -> 24
            | _ -> 
                try
                  List.find_map (fun [ Info_Depth d -> Some d | _ -> None ]) header.header_infos
                  with 
                  [ Not_found -> 
                    try
                      match List.find_map (fun [ Info_ColorModel cm -> Some cm | _ -> None ]) header.header_infos with
                      [ RGB -> 24
                      | RGBA -> 32
                      | _ -> raise Not_found
                      ]
                    with [ Not_found -> (Printf.printf "\tunknown bpp for %s, [%d:%d], info: [%s]\n%!" fn header.header_width header.header_height (string_of_infos header.header_infos); raise Exit) ]
                  ]
            ]
          in
          let size = (donop header.header_width) * (donop header.header_height) * (bpp / 8) in
          add_result res fn size
        with [ Images.Wrong_file_type | Exit -> res ]
      | _ -> res
    ]
  ];

value rec calc_dir res dir = 
  if Sys.is_directory dir
  then
    let files = Sys.readdir dir in
    Array.fold_left begin fun ((cnt,size) as res) f ->
      let fn = Filename.concat dir f in
      if Sys.is_directory fn
      then
        if !recursive then calc_dir res fn else res
      else 
        calc_file fn res
    end res files
  else calc_file dir res
;


let dirs = ref [] in
let () = Arg.parse 
  [ 
    ("-v",Arg.Set verbose,"verbose mode"); 
    ("-r",Arg.Set recursive,"recursive"); 
    ("-nop",Arg.Set nop,"use NextPowerTwo");
    ("-suffix",Arg.String (fun s -> suffix.val := Some s),"set suffix");
    ("-esuffix",Arg.String (fun es -> esuffix.val := [ es :: !esuffix ] ),"exclude suffix")
  ] 
  (fun s -> dirs.val := [ s :: !dirs]) "usage" 
in
let (cnt,size) = List.fold_left calc_dir (0,0) !dirs in
(
  print_result ();
  Printf.printf "Total: %d images, memory: %s\n" cnt (format_size size);
);
