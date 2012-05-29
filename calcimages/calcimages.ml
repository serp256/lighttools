open Images;
open ExtList;


value verbose = ref False;
value recursive = ref False;
value nop = ref False;
value suffix = ref None;
value esuffix = ref None;

value rec nextPowerOfTwo number =
  let rec loop result = 
    if result < number 
    then loop (result * 2)
    else result
  in 
  loop 1;

value donop x = match !nop with [ True -> nextPowerOfTwo x | False -> x];
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


value alredy_calc = Hashtbl.create 1;

value add_result (cnt,size) fn s = 
(
  if !verbose then Printf.printf "\t%s\t\t\t%s\n" fn (format_size s) else ();
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
    [ Some es -> not (ExtString.String.ends_with name es)
    | None -> True
    ]
  | False -> False
  ];

value calc_file fn ((cnt,size) as res) =
  let iname = Filename.chop_extension fn in
  match check_suffix iname && (not (Hashtbl.mem alredy_calc iname)) with 
  [ True ->
    let () = Hashtbl.add alredy_calc iname True in
    match Filename.check_suffix fn ".alpha" with
    [ True -> (*{{{*)
      let gzin = Utils.gzip_input fn in
      let w = IO.read_ui16 gzin in
      let h = IO.read_ui16 gzin in
      add_result res fn (w*h)
      (*}}}*)
    | False -> 
        match Filename.check_suffix fn ".png" || Filename.check_suffix fn ".jpg" || Filename.check_suffix fn ".plx" with
        [ True ->(*{{{*)
          try
            let (fn,s) = 
              let fpvr = iname ^ ".pvr" in
              if !pvr && Sys.file_exists fpvr
              then 
                let s = Unix.stat fpvr in
                (fpvr,s.Unix.st_size - 52) (* FIXME: meta in pvr3, ну да хуй с ней *)
              else
                let plx = iname ^ ".plx" in
                if Sys.file_exists plx
                then
                  let gzin = Utils.gzip_input plx in
                  (
                    ignore (IO.read_byte gzin);
                    let w = IO.read_ui16 gzin
                    and h = IO.read_ui16 gzin in
                    (
                      IO.close_in gzin;
                      (plx,w * h * 2);
                    )
                  )
                else
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
                  (fn, (donop header.header_width) * (donop header.header_height) * (bpp / 8))
            in
            add_result res fn s
          with [ Images.Wrong_file_type | Exit -> res ] (*}}}*)
        | False -> res
        ]
    ]
  | False -> res
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
    ("-pvr",Arg.Set pvr, "pvr mode");
    ("-suffix",Arg.String (fun s -> suffix.val := Some s),"set suffix");
    ("-esuffix",Arg.String (fun es -> esuffix.val := Some es),"exclude suffix")
  ] 
  (fun s -> dirs.val := [ s :: !dirs]) "usage" in
let (cnt,size) = List.fold_left calc_dir (0,0) !dirs in
Printf.printf "Total: %d images, memory: %s\n" cnt (format_size size);
