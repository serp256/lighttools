open Images;
open ExtList;


value verbose = ref False;
value recursive = ref False;
value nop = ref False;


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

value rec nextPowerOfTwo number =
  let rec loop result = 
    if result < number 
    then loop (result * 2)
    else result
  in 
  loop 1;


value string_of_infos infos = 
  match infos with
  [ [] ->  ""
  | _ -> "some"
  ];

value rec calc_dir res dir = 
  let files = Sys.readdir dir in
  let nop = match !nop with [ True -> nextPowerOfTwo | False -> fun x -> x] in
  Array.fold_left begin fun ((cnt,size) as res) f ->
    let fn = Filename.concat dir f in
    if Sys.is_directory fn
    then
      if !recursive then calc_dir res fn else res
    else
      match Filename.check_suffix f ".png" || Filename.check_suffix f ".jpg" with
      [ True ->
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
          let s = (nop header.header_width) * (nop header.header_height) * (bpp / 8) in
          (
            if !verbose then Printf.printf "\t%s\t\t\t%s\n" fn (format_size s) else ();
            (cnt + 1,size + s)
          )
        with [ Images.Wrong_file_type | Exit -> res ]
      | False -> res
      ]
  end res files;


let dirs = ref [] in
let () = Arg.parse [ ("-v",Arg.Set verbose,"verbose mode"); ("-r",Arg.Set recursive,"recursive"); ("-nop",Arg.Set nop,"use NextPowerTwo") ] (fun s -> dirs.val := [ s :: !dirs]) "usage" in
let (cnt,size) = List.fold_left calc_dir (0,0) !dirs in
Printf.printf "Total: %d images, memory: %s\n" cnt (format_size size);
