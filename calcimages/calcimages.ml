open Images;
open ExtList;


value verbose = ref False;
value recursive = ref False;
value nop = ref False;
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

value calc_file fn ((cnt,size) as res) =
  let iname = Filename.chop_extension fn in
  match (not (Hashtbl.mem alredy_calc iname)) && (Filename.check_suffix fn ".png" || Filename.check_suffix fn ".jpg" || Filename.check_suffix fn ".plx" || Filename.check_suffix fn ".alpha") with
  [ True ->
    let () = Hashtbl.add alredy_calc iname True in
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
            let gzin = TCommon.gzip_input plx in
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
      (
        if !verbose then Printf.printf "\t%s\t\t\t%s\n" fn (format_size s) else ();
        (cnt + 1,size + s)
      )
    with [ Images.Wrong_file_type | Exit -> res ]
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
    ("-pvr",Arg.Set pvr, "pvr mode")
  ] 
  (fun s -> dirs.val := [ s :: !dirs]) "usage" in
let (cnt,size) = List.fold_left calc_dir (0,0) !dirs in
Printf.printf "Total: %d images, memory: %s\n" cnt (format_size size);
