open Printf;

open ExtString;
open ExtList;

module Ft = Freetype;

value print_face_info fi =
  Printf.printf
    "num_faces: %d, num_glyphs: %d, fname: %s, sname: %s\n"
    fi.Ft.num_faces fi.Ft.num_glyphs fi.Ft.family_name fi.Ft.style_name
;

value (=|=) k v = (("",k),v);
value (=.=) k v = k =|= string_of_float v;
value (=*=) k v = k =|= string_of_int v;


value stroke = ref 0.;
value pattern = ref "";
value fontFile = ref "";
value suffix = ref "";
value sizes = ref [ ]; (* add support for multisize *)
value color = {Color.r = 255; g = 255; b = 255};
value dpi = ref 72;
(* value alpha_texture = ref False; *)
value xml = ref False;
value with_png = ref False;

value bgcolor = {Color.color = {Color.r = 0; g = 0; b = 0}; alpha = 0};
value scale = ref 1.;

value make_size face size callback =
  (
    Freetype.set_char_size face (!scale *. size) 0. !dpi 0;


    Printf.printf "count symbols : %d\n%!" (UTF8.length !pattern); 
    let i = ref 0 in
      UTF8.iter (fun uchar ->
        (
          let code = UChar.code uchar in
          let char_index = Freetype.get_char_index face code in
          let () = Printf.printf "%d; uchar : %s; code : %d; char_index : %d \n%!" !i (UTF8.init 1 (fun _ -> uchar )) code (Freetype.int_of_char_index char_index) in
          let () = incr i in
          let (xadv,yadv) = Freetype.render_glyph face char_index [] Freetype.Render_Normal in
          let bi = Freetype.get_bitmap_info face in
          let open Freetype in
          let () = Printf.printf "bitmap: %d x %d\n%!" bi.bitmap_width bi.bitmap_height in
          if bi.bitmap_width = 0 || bi.bitmap_height = 0
          then
            let img = Rgba32.make 1 1 bgcolor in
            callback code char_index xadv bi.bitmap_left bi.bitmap_top img
          else
          let img =  Rgba32.make bi.bitmap_width bi.bitmap_height bgcolor in
          (
            for y = 0 to bi.bitmap_height - 1 do
              for x = 0 to bi.bitmap_width - 1 do
                let level = read_bitmap face x y in
                let color = {Color.color; alpha =level } in
                  Rgba32.set img x (bi.bitmap_height - y - 1) color
              done
            done;

(*             for y = 0 to bi.bitmap_height - 1 do
              for x = 0 to bi.bitmap_width - 1 do
                let color = Rgba32.get img x y in
                  Printf.printf "%c" (if color.alpha = 0 then '.' else '+')
              done;

              Printf.printf "\n%!";
            done; *)

            if !stroke = 0.
            then callback code char_index xadv bi.bitmap_left bi.bitmap_top img
            else
              let blankLinesNum ~img ~nextLine ~nextInLine ~linesScaned ~lineScaned () =
                let rec scanLine ((col, row) as pixel) = if lineScaned pixel then True else if (Rgba32.get img col row).Color.alpha = 0 then scanLine (nextInLine pixel) else False in
                let rec blankLinesNum pixel num =
                  if scanLine pixel
                  then blankLinesNum (nextLine pixel) num + 1
                  else num
                in
                  blankLinesNum (0, 0) 0
              in
              let blankRows =
                blankLinesNum ~img
                  ~nextLine:(fun (col, row) -> (col, row + 1))
                  ~nextInLine:(fun (col, row) -> (col + 1, row))
                  ~lineScaned:(fun (col, _) -> col = bi.bitmap_width)
                  ~linesScaned:(fun (_, row) -> row = bi.bitmap_height)
                  ()
              in
              let blankCols =
                blankLinesNum ~img
                  ~nextLine:(fun (col, row) -> (col + 1, row))
                  ~nextInLine:(fun (col, row) -> (col, row + 1))
                  ~lineScaned:(fun (_, row) -> row = bi.bitmap_height)
                  ~linesScaned:(fun (col, _) -> col = bi.bitmap_width)
                  ()
              in
              let (xadv, _) = Freetype.load_glyph face char_index [] in
              let metrics = Freetype.get_glyph_metrics face in
              let (stroke, bearingx, bearingy) = Freetype.stroke_render face (size *. !scale *. !stroke) in
              let (w, h) = Freetype.stroke_dims stroke in
              let img =  Rgba32.make w h bgcolor in
                (
                  for y = 0 to h - 1 do
                    for x = 0 to w - 1 do
                      let levelA = Freetype.stroke_get_pixel stroke x y False in
                      let levelB = Freetype.stroke_get_pixel stroke x y True in
                        Rgba32.set img x (h - y - 1) {Color.color = {Color.r = levelA; g = 0; b = 0}; alpha = levelB }
                    done
                  done;

(*                   for y = 0 to h - 1 do
                    for x = 0 to w - 1 do
                      let color = Rgba32.get img x y in
                        Printf.printf "%c" (if color.alpha = 0 then '.' else '+')
                    done;

                    Printf.printf "\n%!";
                  done;

                  Printf.printf "\n%!";

                  for y = 0 to h - 1 do
                    for x = 0 to w - 1 do
                      let color = Rgba32.get img x y in
                        Printf.printf "%c" (if color.color.r = 0 then '.' else '+')
                    done;

                    Printf.printf "\n%!";
                  done;

                  Printf.printf "blank rows: %d, cols %d\n%!" blankRows blankCols; *)
                  callback code char_index  xadv (int_of_float metrics.gm_hori.bearingx - bearingx + blankCols) (int_of_float metrics.gm_hori.bearingy + bearingy - blankRows) img;
                );
            )
        )
      ) !pattern;
);


(*   UTF8.iter begin fun uchar ->
  (
    let code = UChar.code uchar in
(*     let () = Printf.printf "process char: %d\n%!" code in *)
    let char_index = Freetype.get_char_index face code in
    (* let (xadv,yadv) = Freetype.render_glyph face char_index [] Freetype.Render_Normal in *)
    (* let bi = Freetype.get_bitmap_info face in *)
    (* take bitmap as is for now *)
    let open Freetype in
(*     let () = Printf.printf "%C: bi.left = %d, bi.top = %d,bi.width: %d, bi.height: %d\n%!" (char_of_int code) bi.bitmap_left bi.bitmap_top bi.bitmap_width bi.bitmap_height in *)

(*     let w = bi.bitmap_width in
    let h = bi.bitmap_height in *)

    (* let img =  Rgba32.make bi.bitmap_width bi.bitmap_height bgcolor in *)
    (
(*       for y = 0 to bi.bitmap_height - 1 do
        for x = 0 to bi.bitmap_width - 1 do
          let level = read_bitmap face x y in
          let color = {Color.color; alpha =level } in
          Rgba32.set img x (bi.bitmap_height - y - 1) color
        done
      done; *)




      let (stroke, xadv, yadv) = Freetype.stroke_render face char_index [] Freetype.Render_Normal (size *. !stroke) in
      let (w, h) = Freetype.stroke_dims stroke in
      let strokeImg =  Rgba32.make w h bgcolor in
        (
          for y = 0 to h - 1 do
            for x = 0 to w - 1 do
              let levelA = Freetype.stroke_get_pixel stroke x y False in
              let levelB = Freetype.stroke_get_pixel stroke x y True in
                Rgba32.set strokeImg x (h - y - 1) {Color.color = {Color.r = levelA; g = 0; b = 0}; alpha = levelB }
(*               let colorA = {Color.color = {Color.r = 255; g = 0; b = 0}; alpha = levelA } in
              let colorB = {Color.color; alpha = levelB } in
                Rgba32.set strokeImg x (h - y - 1) (Color.Rgba.merge colorA colorB) *)
            done
          done;

          callback code mertics.gm_hori.advance (int_of_float mertics.gm_hori.bearingx) (int_of_float mertics.gm_hori.bearingy) strokeImg;
          (* callback code xadv bi.bitmap_left bi.bitmap_top strokeImg; *)
        );
    )
  )
  end !pattern; *)

(*
type sdescr =
  {
    id: int; xadvance: float; xoffset: int; yoffset: int;
    width: int; height: int; x: mutable int; y: mutable int; page: mutable int
  };
*)
type char_info =
  {
    id : mutable int;
    xadvance : mutable int;
    xoffset :  mutable int;
    yoffset : mutable int;
    x : mutable int;
    y : mutable int;
    width : mutable int;
    height : mutable int;
    page : mutable int;
  };

type chars =
  {
    space : mutable float;
    size : mutable int;
    lineHeight : mutable float;
    ascender : mutable float;
    descender : mutable float;
    char_list : mutable list char_info;
  };

type font =
  {
    face : mutable string;
    style : mutable string;
    kerning : mutable int;
    pages : mutable list string;
    chars : mutable list chars;
  };

value empty_font () =
  {
    face = "";
    style = "";
    kerning = 0;
    pages = [];
    chars = [];
  };

value parse_sizes str =
  try
    sizes.val := List.map int_of_string (String.nsplit str ",")
  with [ _ -> failwith "Failure parse sizes" ];

value read_chars_from_json fname = 
      let rslt = Hashtbl.create 100 in
      let checkSymbols str =
        (
          let is_whitespace ch = 
            match UChar.uint_code ch with
            [ 010 | 013 | 009 | 026 | 032 | 012 -> True
            |_ -> False
            ] in
          UTF8.iter (fun ch -> if Hashtbl.mem rslt ch || is_whitespace ch then () else Hashtbl.add rslt ch True) str
        ) in
      let json  = Ojson.from_file fname in
      (
        match json with
        [`Assoc jsons ->
          (
            List.iter (fun (key, json) ->
              match json with
              [`String v ->
                checkSymbols v
              | _ -> ()
              ];
            ) jsons;
          )
        | _ -> assert False
        ];
        let keys = ExtLib.List.of_enum(ExtLib.Hashtbl.keys rslt) in
        let str =  (UTF8.init (Hashtbl.length rslt) (fun i -> List.nth keys i)) in
        (
          Printf.printf "%s\n%!" (String.strip str);
          pattern.val := !pattern ^ (String.strip str);
        );
      );

value read_chars fname = 
  match Filename.check_suffix fname "json" with
  [False -> pattern.val := !pattern ^ (String.strip (Std.input_file fname))
  | _ -> read_chars_from_json fname
  ];
value set_pattern p = pattern.val := !pattern ^ p;

value output = ref None;

value read_sizes fname = parse_sizes (String.strip (Std.input_file fname));
value styles = ref "Regular";
value stylesList = ref False;
value skip_style_suffix = ref False;

(* use xmlm for writing xml *)
Arg.parse
  [
    ("-c",Arg.String set_pattern,"chars");
    ("-s",Arg.String parse_sizes,"sizes");
    ("-cf",Arg.String read_chars,"chars from file");
    ("-sf",Arg.String read_sizes,"sizes from file");
    (* ("-alpha",Arg.Set alpha_texture,"make alpha texture"); *)
    ("-stroke", Arg.Float (fun s -> stroke.val := s /. 100.), "stroke font. value passed through this option is stroke 'fatness' in percents relative to size");
    ("-o",Arg.String (fun s -> output.val := Some s),"output dir");
    ("-scale", Arg.Float (fun s -> scale.val := s ), "scale factor");
    ("-xml", Arg.Set xml, "xml format" ) ;
    ("-suf", Arg.Set_string suffix, "suffix");
    ("-styles", Arg.Set_string styles, "comma-separated list of styles to be exported. use -styles-list to display styles list");
    ("-styles-list", Arg.Set stylesList, "display full styles list of input file");
    ("-pmaxt", Arg.Int (fun v -> TextureLayout.max_size.val := v), "max texture size");
    ("-skip-style-suffix", Arg.Set skip_style_suffix, "skip_style_suffix");
    ("-with-png", Arg.Set with_png, "save fonts png file" ) ;
  ]
  (fun f -> fontFile.val := f) "Usage msg";

if !stylesList
then
  let t = Freetype.init () in
  let (_, face_info) = Freetype.new_face t !fontFile 0 in
    (
      Printf.printf "face_info.Freetype.num_faces %d\n%!" (face_info.Freetype.num_faces);
      for i = 0 to face_info.Freetype.num_faces - 1 do {
        let (_, face_info) = Freetype.new_face t !fontFile i in
          Printf.printf "family %s, style %s\n" face_info.Freetype.family_name face_info.Freetype.style_name;
      };

      exit 0;
    )
else ();

value bad_arg what = (Printf.printf "bad argument '%s'\n%!" what; exit 1);
if !pattern = ""
then bad_arg "chars"
else
  if !sizes = [] then bad_arg "sizes"
  else
    if !fontFile = "" then bad_arg "font file"
    else ();

value str_of_float v =
  snd ( ExtString.String.replace ~str:(string_of_float v) ~sub:"." ~by:"");

let t = Freetype.init () in
let (face,face_info) = Freetype.new_face t !fontFile 0 in
let availStyles = List.init face_info.Freetype.num_faces (fun i -> Freetype.new_face t !fontFile i) in
let faces = List.map (fun styleName -> try List.find (fun (_, face_info) -> face_info.Freetype.style_name = styleName) availStyles with [ Not_found -> failwith ("Style '" ^ styleName ^  "' not found") ]) (ExtString.String.nsplit !styles ",") in

  List.iter (fun (face, face_info) ->
    let chars_images = Hashtbl.create 1 in
    let postfix =
      match !suffix with
      [ "" ->
          if !scale = 1. then "" else "x" ^ (str_of_float !scale)
      | _ -> !suffix
      ]
    in
    let style_suffix = 
      match !skip_style_suffix with
      [ True -> ""
      | _ -> face_info.Freetype.style_name 
      ]
    in
    let fname = Filename.chop_extension (Filename.basename !fontFile) ^ style_suffix in
    let resfname = fname ^ postfix ^  ".fnt" in
    let resfname = match !output with [ None -> resfname | Some dir -> Filename.concat dir resfname ] in
    let font = empty_font () in
      (
        font.face := face_info.Ft.family_name;
        font.style := face_info.Ft.style_name;
        font.kerning :=(if face_info.Ft.has_kerning then 1 else 0);
        let imgs = ref [] in
          (
            List.iter begin fun size ->
              make_size face (float size) begin fun code char_index xadvance xoffset yoffset img ->
                let key = (char_index,size) in
                match Hashtbl.mem chars_images key with
                [ True -> ()
                | _ -> 
                  (
                    imgs.val := [ (key,Images.Rgba32 img) :: !imgs ];
                    Hashtbl.add chars_images key {id=code;xadvance=(int_of_float xadvance);xoffset;yoffset;width=img.Rgba32.width;height=img.Rgba32.height;x=0;y=0;page=0 };
                  )
                ]
              end
            end !sizes;
            Printf.printf "len imgs: %d\n%!" (List.length !imgs);

            let () = TextureLayout.rotate.val := False in
            let textures = TextureLayout.layout ~tsize:TextureLayout.Npot !imgs in
            List.iteri begin fun i {TextureLayout.width = w;height = h; placed_images = imgs} ->
              let texture = Rgba32.make w h bgcolor in
              (
                List.iter begin fun (key,(x,y,_,img)) ->
                  (
                    let img = match img with [ Images.Rgba32 img -> img | _ -> assert False ] in
                    Rgba32.blit img 0 0 texture x y img.Rgba32.width img.Rgba32.height;
                    let r = Hashtbl.find chars_images key in
                    ( r.x := x; r.y := y; r.page := i;)
                  )
                end imgs;
                (* let ext = match !alpha_texture with [ True -> "alpha" | False -> "png" ] in *)
                let ext = if !stroke > 0. then "lumal" else "alpha" in
                let imgname =  Printf.sprintf "%s_%d%s.%s" fname i postfix ext in
                let png_name =  Printf.sprintf "%s_%d%s.png" fname i postfix in
                let fname = match !output with [ None -> imgname | Some o -> Filename.concat o imgname] in
                (
                  match !with_png with
                  [ True -> 
                      Images.save (match !output with [ Some o -> Filename.concat o png_name | _ -> png_name]) (Some Images.Png) [] (Images.Rgba32 texture)
                  | _ -> ()
                  ];
                  Utils.save_alpha ~with_lum:(!stroke > 0.) (Images.Rgba32 texture) fname;
                  font.pages := [ imgname :: font.pages ];
                );
              )
            end textures;
          );

          List.iter begin fun size ->
            (
              Freetype.set_char_size face (!scale *. (float size)) 0. !dpi 0;
              let spaceIndex = Freetype.get_char_index face (int_of_char ' ') in
              let (spaceXAdv, spaceYAdv) = Freetype.render_glyph face spaceIndex [] Freetype.Render_Normal in
              let sizeInfo = Freetype.get_size_metrics face in
              (
                let () = Printf.printf "descender: %f, max_advance: %f, x_ppem: %d, y_ppem: %d, ascender: %f, height: %f\n%!" sizeInfo.Freetype.descender sizeInfo.Freetype.max_advance sizeInfo.Freetype.x_ppem
                sizeInfo.Freetype.y_ppem sizeInfo.Freetype.ascender sizeInfo.Freetype.height in
                let chars' =
                  {
                    space = spaceXAdv;
                    size  = size;
                    lineHeight = sizeInfo.Freetype.height;
                    ascender = sizeInfo.Freetype.ascender;
                    descender = ~-. (sizeInfo.Freetype.descender);
                    char_list = [];
                  }
                in
                  (
                    UTF8.iter begin fun uchar ->
                      let code = UChar.code uchar in
                      let char_index = Freetype.get_char_index face code in
                      let info = Hashtbl.find chars_images (char_index,size) in
            (*           let () = Printf.printf "char: %C, xoffset: %d, yoffset: %d\n%!" (char_of_int code) info.xoffset info.yoffset in *)
                      chars'.char_list :=
                        [ {id=code; xadvance=info.xadvance; xoffset=info.xoffset; yoffset = (truncate (sizeInfo.Freetype.ascender -. (float info.yoffset))); x=info.x; y=info.y; width=info.width; height=info.height; page=info.page; } :: chars'.char_list ]
                    end !pattern;
                    font.chars := [ chars' :: font.chars]
                  )
              );
            )
          end !sizes;

          match !xml with
          [ True ->
          (*save in xmpl*)
              let out = open_out resfname in
              let xmlout = Xmlm.make_output ~nl:True ~indent:(Some 4) (`Channel (open_out resfname)) in
              (
                Xmlm.output xmlout (`Dtd None);
                let fattribs =
                  [ "face" =|= font.face
                  ; "style" =|= font.style
                  ; "kerning" =*= font.kerning
                  ]
                in
                Xmlm.output xmlout (`El_start (("","Font"),fattribs));
                Xmlm.output xmlout (`El_start (("","Pages"),[]));
                List.iter (fun imgname ->
                  (
                        Xmlm.output xmlout (`El_start (("","page"),["file" =|= imgname]));
                        Xmlm.output xmlout `El_end;
                  )
                ) (List.rev font.pages);
                Xmlm.output xmlout `El_end;
                List.iter begin fun chars ->
                  (
                    Xmlm.output xmlout (`El_start (("","Chars"),
                      [ "space" =.= chars.space;
                        "size" =*= chars.size ;
                        "lineHeight" =.= chars.lineHeight;
                        "ascender" =.= chars.ascender;
                        "descender" =.= chars.descender;
                      ])
                    );
                    List.iter begin fun ch ->
                      let attribs =
                        [ "id" =*= ch.id
                        ; "xadvance" =*= ch.xadvance
                        ; "xoffset" =*= ch.xoffset
                        ; "yoffset" =*= ch.yoffset
                        ; "x" =*= ch.x
                        ; "y" =*= ch.y
                        ; "width" =*= ch.width
                        ; "height" =*= ch.height
                        ; "page" =*= ch.page
                        ]
                      in
                      (
                        Xmlm.output xmlout (`El_start (("","char"),attribs));
                        Xmlm.output xmlout `El_end;
                      )
                    end chars.char_list;
                    Xmlm.output xmlout `El_end;
                  )
                end font.chars;
                Xmlm.output xmlout `El_end;
                close_out out;
              )
          | _ ->
              let out = open_out resfname in
              let binout = IO.output_channel out in
                (
                  IO.write_string binout font.face;
                  IO.write_string binout font.style;
                  IO.write_byte binout font.kerning;
                  IO.write_ui16 binout (List.length font.pages);
                  List.iter (IO.write_string binout) font.pages;
                  IO.write_ui16 binout (List.length font.chars);
                  List.iter begin fun chars ->
                    (
                      IO.write_double binout chars.space;
                      IO.write_ui16 binout chars.size;
                      IO.write_double binout chars.lineHeight;
                      IO.write_double binout chars.ascender;
                      IO.write_double binout chars.descender;
                      IO.write_ui16 binout (List.length chars.char_list);
                      List.iter begin fun ch ->
                        (
                          IO.write_i32 binout ch.id;
                          IO.write_ui16 binout ch.xadvance;
                          IO.write_i16 binout ch.xoffset;
                          IO.write_i16 binout ch.yoffset;
                          IO.write_ui16 binout ch.x;
                          IO.write_ui16 binout ch.y;
                          IO.write_ui16 binout ch.width;
                          IO.write_ui16 binout ch.height;
                          IO.write_ui16 binout ch.page;
                        )
                      end chars.char_list;
                    )
                  end font.chars;
                  close_out out;
                )
          ];
      )
  ) faces;
