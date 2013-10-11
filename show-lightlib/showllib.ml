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
      ("-ff", Arg.Set_string fontFamily, "font family. by default: font name");
      ("-fw", Arg.Set_string fontWeight, "font weight");
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
    match String.length !fontFamily = 0 with [True -> fontFamily.val := !font| False -> ()];
    Drawllib.draw !indir (!font, !fontFamily, !fontWeight, !fontSize) !suffix;
  );
