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


value string_of_clr elt = 
  Printf.sprintf "#%02x%02x%02x%02x" elt.color.r elt.color.g elt.color.b elt.alpha;


value makeColorRemapTable colors = 
  let colorMap = Hashtbl.create 3 in
  let colorArray = Array.make (Hashtbl.length colors) None in
  let _ = Hashtbl.fold (fun k v i -> (colorArray.(i) := Some k; i+1) ) colors 0 in
  let () = Printf.eprintf "HOHO: %d" (Array.length colorArray) in
  let i = ref 0 in
  (
    while !i < Array.length colorArray do
    (
      let cclr = colorArray.(!i) in
      match cclr with
      [ Some cclr -> 
          let j = ref (!i + 1) in 
          while !j < Array.length colorArray do
          ( 
            let nclr = colorArray.(!j) in
            match nclr with
            [ Some nclr -> 
              let dist = Color.Rgb.square_distance cclr.color nclr.color in
              if dist < 33 & dist > 0 & cclr.alpha == nclr.alpha then
              (
                Hashtbl.add colorMap nclr cclr; (* заменяем cclr на nclr *)
                colorArray.(!j) := None;
              )  
              else ()
            | None -> ()
            ];
            incr j
          )
          done  
      | None -> ()
      ]; 
      incr i
    )
    done;
    colorMap;
  );  


value setImageColor image x y clr = 
  match image with
  [ Rgb24  i24 -> Rgb24.set i24 x y clr.color
  | Rgba32 i32 -> Rgba32.set i32 x y clr
  | _ -> failwith "Unsupported format"
  ];


value remapColorsInImage image remapTable =
  let (w,h) = Images.size image in
  let i = ref 0 in
  (
    while !i < h do 
    (
      let j = ref 0 in
      while !j < w do 
      (   
        let elt = 
        match image with
        [ Rgb24  i24 -> let elt = (Rgb24.get i24 !j !i) in { Color.Rgba.color = elt; alpha = 1 }
        | Rgba32 i32 -> Rgba32.get i32 !j !i
        | _   -> failwith "Unsupported format"
        ] in 
        try 
          let newClr = Hashtbl.find remapTable elt in
          setImageColor image !j !i newClr
        with [Not_found -> ()];
        incr j;
      )
      done;
      incr i;
    )
    done;
    
    Images.save "output.png" (Some Images.Png) [] image;
    
  );
  

  


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
          (
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
              try 
                let c = Hashtbl.find colors elt in
                Hashtbl.replace colors elt (c + 1)
              with [Not_found -> Hashtbl.add colors elt 1];
              incr j;
            )
            done;
            incr i;
          )
          done;
          Printf.printf "Total unique colors: %d\n%!" (Hashtbl.length colors);
          let remapTable = makeColorRemapTable colors in
          remapColorsInImage image remapTable;
          );
          Hashtbl.clear colors;
        )
        with [ Images.Wrong_file_type | Exit -> () ]
      | False -> ()
      ]
  end files;




let dirs = ref [] in
let () = Arg.parse [ ("-v",Arg.Set verbose,"verbose mode"); ("-r",Arg.Set recursive,"recursive"); ("-nop",Arg.Set nop,"use NextPowerTwo") ] (fun s -> dirs.val := [ s :: !dirs]) "usage" in
List.iter calc_dir !dirs;