open Images;
open ExtList;


value verbose = ref False;
value recursive = ref False;
value nop = ref False;

value colors = Hashtbl.create 3;

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




value rec calc_dir dir = 
  let files = Sys.readdir dir in
  Array.iter begin fun f ->
    let fn = Filename.concat dir f in
    if Sys.is_directory fn
    then
      if !recursive then calc_dir fn else ()
    else
      match Filename.check_suffix f ".png" || Filename.check_suffix f ".jpg" with
      [ True ->
        try
        (
          let () = Printf.eprintf "Processing %s...  %!" fn in
          let image = Images.load fn [] in
          let (w,h) = Images.size image in
          let i = ref 0 in
          while !i < h do
          (
            let j = ref 0 in
            while !j < w do
            (   
              let elt = 
              match image with
              [ Rgb24  i24 -> 
                let elt = (Rgb24.get i24 !j !i) in
                { Color.Rgba.color = elt; alpha = 1 }
              | Rgba32 i32 -> Rgba32.get i32 !j !i
              | _   -> failwith "Unsupported format"
              ] in 
              let clrstr = Printf.sprintf "%02x%02x%02x%02x" elt.color.r elt.color.g elt.color.b elt.alpha in
              try 
                let c = Hashtbl.find colors clrstr in
                Hashtbl.replace colors clrstr (c + 1)
              with [Not_found -> Hashtbl.add colors clrstr 1];
              incr j;
            )
            done;
            incr i;
          )
          done;
          
          Printf.printf "Total unique colors: %d\n%!" (Hashtbl.length colors);
          Hashtbl.clear colors;
        )
        with [ Images.Wrong_file_type | Exit -> () ]
      | False -> ()
      ]
  end files;


let dirs = ref [] in
let () = Arg.parse [ ("-v",Arg.Set verbose,"verbose mode"); ("-r",Arg.Set recursive,"recursive"); ("-nop",Arg.Set nop,"use NextPowerTwo") ] (fun s -> dirs.val := [ s :: !dirs]) "usage" in
List.iter calc_dir !dirs;




