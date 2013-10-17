value pvrGap = 4; (* how much pixels should be cutted from image due to pvr compression to prevent bad effects *)
value moveGap = 2; (* size of pieces overlap to prevent black holes between pieces when scrolling map *)

value size = ref 0;
value src = ref "";
value outDir = ref "";
value suffix = ref  "";
value scale = ref 1.;
value gen_dds = ref False;
value gen_pvr = ref False;

value write_utf out str =
(
  IO.write_i16 out (String.length str);
  IO.nwrite out str;
);

value args = 
  [
    ("-size", Arg.Set_int size, "\tmax size of map piece, must be power of 2");
    ("-i", Arg.Set_string src, "\t\tsource map image");
    ("-o", Arg.Set_string outDir, "\t\toutDirput directory for images and metadata");
    ("-suffix", Arg.Set_string suffix,"\t\tSuffix for name images");
    ("-scale", Arg.Set_float scale, "\t\tScaling factor");
    ("-pvr", Arg.Set gen_pvr, "\t\tCompress to pvr");
    ("-dds", Arg.Set gen_dds, "\t\tCompress to dds");
  ];

Arg.parse args (fun _ -> ()) "Tool to cut large map image into small pieces to use it on mobile devices.";

value isPot n = n land (n - 1) = 0;

value nextPot n =
  if isPot n
  then n
  else
    let rec nextPot n pot =
      if n > pot
      then nextPot n (pot * 2)
      else pot
    in
      nextPot n 1;

if !size = 0
then failwith "-size option is required"
else ();

if not (isPot !size)
then failwith "-size must be power of 2"
else ();

if (!src = "") || not (Sys.file_exists !src) || (Sys.is_directory !src)
then failwith "wrong source image: it is not specified or it doesn't exists or it is directory"
else ();

if (!outDir = "") || (Sys.file_exists !outDir) && not (Sys.is_directory !outDir)
then failwith "wrong output directory: it is not specified or it exists, but it is not directory"
else ();

let img =
  match !scale with
  [ 1. -> Images.load !src [] 
  | _ -> 
      let dstFname = Filename.temp_file "" ""  in
        (
          if Sys.command (Printf.sprintf "convert -resize %d%% -filter catrom %s png32:%s" (int_of_float (!scale *. 100.)) !src dstFname) <> 0 then failwith "convert returns non-zero exit code"
          else ();
          Images.load dstFname [];
        )
  ]
in
let (imgW, imgH) = Images.size img in

let next coord dim = coord + dim - 2 * pvrGap - moveGap in

let rec layout coord dim lt =
  if coord + !size > dim
  then List.rev [ coord :: lt ]
  else layout (next coord !size) dim  [ coord :: lt ]
in

let outChan = open_out (Filename.concat !outDir ("layout" ^ !suffix )) in
let out = IO.output_channel outChan in
let xlayout = layout 0 imgW [] in
let ylayout = layout 0 imgH [] in
let i = ref ~-1 in
  (
    IO.write_byte out ((List.length xlayout) * (List.length ylayout));

    List.iter (fun y ->
      let h = min !size (imgH - y) in
      List.iter (fun x ->
        let w = min !size (imgW - x) in
        let piece = Images.sub img x y w h in
        let () = incr i in
        let fname = (string_of_int !i) ^ !suffix ^ ".png" in

        let potSize =
          if w = !size && h = !size
          then
            (
              Images.save (Filename.concat !outDir fname) (Some Images.Png) [] piece;
              !size;
            )
          else
            let potSize = max (nextPot w) (nextPot h) in
            let piece' =
              match piece with
              [ Images.Index8 _ -> Images.Index8 (Index8.make potSize potSize 0)
              | Images.Rgb24 _ -> Images.Rgb24 (Rgb24.make potSize potSize { Color.Rgb.r = 0; g = 0; b = 0 })
              | Images.Index16 _ -> Images.Index16 (Index16.make potSize potSize 0)
              | Images.Rgba32 _ -> Images.Rgba32 (Rgba32.make potSize potSize { Color.Rgba.color = { Color.Rgb.r = 0; g = 0; b = 0 }; alpha = 0 })
              | Images.Cmyk32 _ -> Images.Cmyk32 (Cmyk32.make potSize potSize { Color.Cmyk.c = 0; m = 0; y = 0; k = 0 })
              ]
            in
              (
                Images.blit piece 0 0 piece' 0 0 w h;
                Images.save (Filename.concat !outDir fname) (Some Images.Png) [] piece';

                let file_name = Filename.chop_extension (Filename.concat !outDir fname) in
                  (
                    if !gen_dds then
                    (
                      Utils.dxt_png file_name;
                      Utils.gzip_img (file_name ^ ".dds");
                    )
                    else ();
                    match !gen_pvr with
                    [ True -> 
                        (
                          Utils.pvr_png file_name;
                          Utils.gzip_img (file_name ^ ".pvr");
                        )
                    | _ -> ()
                    ];

                  );
                Images.destroy piece';
                potSize;
              )
        in
          (
            write_utf out fname;
            IO.write_i16 out (if x <> 0 then x + pvrGap else x);
            IO.write_i16 out (if y <> 0 then y + pvrGap else y);

            let paddingL = if x = 0 then 0 else pvrGap in
            let paddingT = if y = 0 then 0 else pvrGap in
            let paddingR = if x + w = imgW then potSize - w else pvrGap in
            let paddingB = if y + h = imgH then potSize - h else pvrGap in
              (
                IO.write_byte out paddingL;
                IO.write_byte out paddingT;
                IO.write_i16 out (potSize - paddingL - paddingR);
                IO.write_i16 out (potSize - paddingT - paddingB);
              );

            Images.destroy piece;
          );
      ) xlayout
    ) ylayout;

    close_out outChan;
    Images.destroy img;
  );
