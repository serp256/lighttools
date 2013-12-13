value indir = ref "";
value suffix = ref "";
value font = ref "";
value fontFamily = ref "";
value fontWeight = ref "regular";
value fontSize = ref 20; 

value () =
  let files = ref [] in
  (
    Arg.parse 
    [
      ("-i", Arg.Set_string indir, "input directory relative to Resources");
      ("-f", Arg.Set_string font, "font name");
      ("-fs", Arg.Set_int fontSize, "font size. by default: 20");
      ("-suf", Arg.Set_string suffix, "light lib suffix");
    ]
    (fun s -> files.val := [s :: !files]) "copy showllib.byte into directory containing Resources of project";
    let (_, dir) = ExtLib.String.replace !indir "Resources/" "" in
    indir.val := dir;
    match String.length !font = 0 with
    [True -> 
      let default =
      ExtLib.Array.find (fun file -> Filename.check_suffix file "fnt") (Sys.readdir "Resources/fonts") in
      let (_,fontName) = ExtLib.String.replace (Filename.chop_extension default) !suffix "" in
      font.val := fontName
    |False -> ()
    ];

    let inp = 
      try
      open_in (Printf.sprintf "Resources/fonts/%s%s.fnt" !font !suffix) 
      with [_ -> open_in (Printf.sprintf "Resources/fonts/%s.fnt" !font ) ]
    in
    let bin_inp = IO.input_channel inp in
    let family = IO.read_string bin_inp in
    let weight = IO.read_string bin_inp in
    let _ = IO.read_byte bin_inp in
    let pages_count = IO.read_ui16 bin_inp in
    (*
    let () = List.iter (fun i -> ignore (IO.read_string bin_inp)) (ExtLib.List.init (fun i -> i) pages_count) in
    let chars_count = IO.read_ui16 bin_inp in 
    let () = List.iter begin fun chars ->
                (
                  ignore(IO.read_double bin_inp);
                  ignore(IO.read_ui16 bin_inp);
                  ignore(IO.read_double bin_inp);
                  ignore(IO.read_double bin_inp);
                  ignore(IO.read_double bin_inp chars.descender;
                  ignore(IO.read_ui16 bin_inp (List.length chars.char_list);
                  List.iter begin fun ch ->
                    (
                      IO.write_i32 bin_inp ch.id;
                      IO.write_ui16 bin_inp ch.xadvance;
                      IO.write_i16 bin_inp ch.xoffset;
                      IO.write_i16 bin_inp ch.yoffset;
                      IO.write_ui16 bin_inp ch.x;
                      IO.write_ui16 bin_inp ch.y;
                      IO.write_ui16 bin_inp ch.width;
                      IO.write_ui16 bin_inp ch.height;
                      IO.write_ui16 bin_inp ch.page;
                    )
                  end chars.char_list;
                )
              end (ExtLib.List.init (fun i -> i) chars_count) ;
 *)
      let () = Debug.d "%s: %s" family weight in
      (
        fontFamily.val := family;
        fontWeight.val := String.uncapitalize weight;
      );
    Drawllib.draw !indir (!font, !fontFamily, !fontWeight, !fontSize) !suffix;
  );
