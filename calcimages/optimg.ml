open Images;
open ExtList;
open IO;


value verbose = ref False;
value recursive = ref False;
value nop = ref False;

(* value colors = Hashtbl.create 3; *)


value mgb = 1024 * 1024;
value kb = 1024;



value rec nextPowerOfTwo number =
  let rec loop result = 
    if result < number 
    then loop (result * 2)
    else result
  in 
  loop 1;


value sizeToFit length = 
  let rec calcsize w h length = 
    if w * h > length then
      (w,h)
    else if h > w then
      calcsize (w*2) h length
    else
      calcsize w (h*2) length
  in calcsize 1 1 length;


value string_of_infos infos = 
  match infos with
  [ [] ->  ""
  | _ -> "some"
  ];


value string_of_clr elt = 
  Printf.sprintf "#%02x%02x%02x%02x" elt.color.r elt.color.g elt.color.b elt.alpha;




(* build color table *)
value reduce_colors colors = 
  let colorMap = Hashtbl.create 3 in
  let colorsOpt = List.map (fun c -> Some c) colors in
  let colorArray = Array.of_list colorsOpt in
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
    let newColors = Array.fold_left (fun l c -> match c with [None -> l | Some x -> [x::l]]) [] colorArray in  (colorMap, newColors);
  );

(* *)
value build_palette reducedColors = 
  let palette = Array.of_list reducedColors in
  let paletteIdx = Hashtbl.create (List.length reducedColors) in 
  (
    Array.iteri (fun i c -> Hashtbl.add paletteIdx c i) palette; 
    (palette, paletteIdx);
  );
  
  

(* *)
value setImageColor image x y clr = 
  match image with
  [ Rgb24  i24 -> Rgb24.set i24 x y clr.color
  | Rgba32 i32 -> Rgba32.set i32 x y clr
  | _ -> failwith "Unsupported format"
  ];



(* *)
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



  
  
  

(* *)
value iter_2d f sx sy mx my = 
  let y = ref sy in
  while !y < my do
  (
    let x = ref sx in
    while !x < mx do
    (
      f !x !y;
      incr x;
    )
    done; 
    incr y;
  ) done;
  


(* iterate over image *)
value image_iter f img = 
  let (w,h) = Images.size img in
  iter_2d begin fun x y ->
      let elt =                                                                                                                                                                       
        match img with                                                                                                                                                                
        [ Rgb24  i24 ->                                                                                                                                                                 
            let elt = (Rgb24.get i24 x y) in                                                                                                                                            
            { Color.Rgba.color = elt; alpha = 1 }                                                                                                                                         
        | Rgba32 i32 -> Rgba32.get i32 x y                                                                                                                                            
        | _   -> failwith "Unsupported format"                                                                                                                                          
        ] 
      in (f x y elt);
  end 0 0 w h;




(* *)
value convert_to_hicolor_palette_img image remapTable palette paletteIndex outputfname = 
  let oc_bitmap     = IO.output_channel (open_out_bin (outputfname ^ ".btmp")) 
  and oc_palette    = IO.output_channel (open_out_bin (outputfname ^ ".pltt")) in
  (
  
    (* print header *)
    let (w,h) = Images.size image in
    (
      write_ui16 oc_bitmap w;
      write_ui16 oc_bitmap h;
    );
    
    (* print data *)
    image_iter 
      begin fun x y clr ->         
        let remapedClr = 
          try 
            Hashtbl.find remapTable clr
          with [Not_found -> clr]
        in
        let colorIndex = Hashtbl.find paletteIndex remapedClr
        in write_ui16 oc_bitmap colorIndex;
      end image;
      
    (* calc palette size (each size is a power of 2) *)
    let (w,h) = sizeToFit (Array.length palette) in
    (
      write_ui16 oc_palette w;
      write_ui16 oc_palette h;    
      
      iter_2d 
        begin fun x y -> 
          let idx = y * h + x in
          let clr = 
            if idx < Array.length palette then 
              palette.(idx)
            else 
              { Color.Rgba.color = { Color.Rgb.r = 0; g = 0; b = 0; }; alpha = 0 }
          in    
          (
            write_byte oc_palette clr.color.r;
            write_byte oc_palette clr.color.g;
            write_byte oc_palette clr.color.b;
            write_byte oc_palette clr.alpha;              
          )
        end 0 0 w h;
    );
  );    


(* return list of all colors *)
value get_colors img = 
  let clrTable = Hashtbl.create 3 in
  let () = image_iter 
    begin fun _ _ clr ->
      try
        let cnt = Hashtbl.find clrTable clr in
        Hashtbl.replace clrTable clr (cnt + 1)
      with [Not_found -> Hashtbl.add clrTable clr 1];
    end img
  in Hashtbl.fold (fun k _ l -> [k :: l]) clrTable [];
  


(* *)
value process_file fn = 
  let () = Printf.eprintf "Processing %s...  %!\n" fn in
  try
    let image = Images.load fn [] in
    let colors   = get_colors image in
    
    let () = Printf.eprintf "Total %d colors\n%!" (List.length colors) in
    
    let (remapTable, reducedColors) = reduce_colors colors in
    
    let () = Printf.eprintf "Reduced to %d colors (keys in table %d)\n%!" (List.length reducedColors) (Hashtbl.length remapTable) in
    
    let (palette, paletteIdx) = build_palette reducedColors in
    
    let () = Printf.eprintf "Colors in palette %d (keys in index %d)\n%!" (Array.length palette) (Hashtbl.length paletteIdx) in
    
    convert_to_hicolor_palette_img image remapTable palette paletteIdx "output"
  with [ Images.Wrong_file_type | Exit -> () ];



(* *)
value rec calc_dir dir = 
  let files = Sys.readdir dir in
  Array.iter begin fun f ->
    let fn = Filename.concat dir f in
    if Sys.is_directory fn
    then
      if !recursive then calc_dir fn else ()
    else
      match Filename.check_suffix f ".png" || Filename.check_suffix f ".jpg" with
      [ True ->  process_file fn
      | False -> ()
      ]
  end files;




let dirs = ref [] in
let () = Arg.parse [ ("-v",Arg.Set verbose,"verbose mode"); ("-r",Arg.Set recursive,"recursive"); ("-nop",Arg.Set nop,"use NextPowerTwo") ] (fun s -> dirs.val := [ s :: !dirs]) "usage" in
List.iter calc_dir !dirs;
