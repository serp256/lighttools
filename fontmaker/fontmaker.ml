open Printf;

module Ft = Freetype;

value print_face_info fi = 
  Printf.printf 
    "num_faces: %d, num_glyphs: %d, fname: %s, sname: %s\n" 
    fi.Ft.num_faces fi.Ft.num_glyphs fi.Ft.family_name fi.Ft.style_name
;

value (=|=) k v = (("",k),v);
value (=.=) k v = k =|= string_of_float v;
value (=*=) k v = k =|= string_of_int v;

value pattern = ref "";
value fontFile = ref "";
value sizes = ref [ ]; (* add support for multisize *)
value color = {Color.r = 255; g = 255; b = 255};
value dpi = ref 72;

value bgcolor = {Color.color = {Color.r = 0; g = 0; b = 0}; alpha = 0};

value make_size face size callback = 
(
  Freetype.set_char_size face size 0. !dpi 0;
  BatUTF8.iter begin fun uchar ->
  (
    let code = BatUChar.to_int uchar in
(*     let () = Printf.printf "process char: %d\n%!" code in *)
    let char_index = Freetype.get_char_index face code in
    let (xadv,yadv) = Freetype.render_glyph face char_index [] Freetype.Render_Normal in
    let bi = Freetype.get_bitmap_info face in
    (* take bitmap as is for now *)
    let open Freetype in
(*     let () = Printf.printf "%C: bi.left = %d, bi.top = %d,bi.width: %d, bi.height: %d\n%!" (char_of_int code) bi.bitmap_left bi.bitmap_top bi.bitmap_width bi.bitmap_height in *)
    let img =  Rgba32.make bi.bitmap_width bi.bitmap_height bgcolor in
    (
      for y = 0 to bi.bitmap_height - 1 do
        for x = 0 to bi.bitmap_width - 1 do
          let level = read_bitmap face x y in
(*           let () = Printf.printf "level: %d\n%!" level in *)
          let color = {Color.color; alpha =level } in
          Rgba32.set img x (bi.bitmap_height - y - 1) color
        done
      done;
(*         img#save (Printf.sprintf "%d.png" code) (Some Images.Png) []; *)
      callback code xadv bi.bitmap_left bi.bitmap_top img
    )
  )
  end (BatUTF8.of_string !pattern);
);

type sdescr = 
  {
    id: int; xadvance: float; xoffset: int; yoffset: int; 
    width: int; height: int; x: mutable int; y: mutable int; page: mutable int
  };


value parse_sizes str = 
  try
    sizes.val := List.map int_of_string (BatString.nsplit str ",")
  with [ _ -> failwith "Failure parse sizes" ];

value read_chars fname = pattern.val := BatString.strip (BatStd.input_file fname);
value output = ref None;

(* use xmlm for writing xml *)
Arg.parse 
  [
    ("-c",Arg.Set_string pattern,"chars");
    ("-s",Arg.String parse_sizes,"sizes");
    ("-cf",Arg.String read_chars,"chars from file");
    ("-o",Arg.String (fun s -> output.val := Some s),"output dir")
  ] 
  (fun f -> fontFile.val := f) "Usage msg";

value bad_arg what = (Printf.printf "bad argument '%s'\n%!" what; exit 1);
if !pattern = "" 
then bad_arg "chars"
else 
  if !sizes = [] then bad_arg "sizes"
  else 
    if !fontFile = "" then bad_arg "font file"
    else ();

(* Printf.printf "chars: [%s] = %d\n%!" !pattern (BatUTF8.length !pattern); *)
let t = Freetype.init () in
let (face,face_info) = Freetype.new_face t !fontFile 0 in
let chars = Hashtbl.create 1 in
let fname = Filename.chop_extension (Filename.basename !fontFile) in
let xmlfname =  fname ^ ".fnt" in
let xmlfname = match !output with [ None -> xmlfname | Some dir -> Filename.concat dir xmlfname ] in
let out = open_out xmlfname in
let xmlout = Xmlm.make_output ~nl:True ~indent:(Some 4) (`Channel (open_out xmlfname)) in
(
  Xmlm.output xmlout (`Dtd None);
  print_face_info face_info;
  let fattribs = 
    [ "face" =|= face_info.Ft.family_name 
    ; "style" =|= face_info.Ft.style_name
    ; "kerning" =*= (if face_info.Ft.has_kerning then 1 else 0)
    ]
  in
  Xmlm.output xmlout (`El_start (("","Font"),fattribs));
  let imgs = ref [] in
  (
    List.iter begin fun size ->
      make_size face (float size) begin fun code xadvance xoffset yoffset img ->
        let key = (code,size) in
        (
          imgs.val := [ (key,Images.Rgba32 img) :: !imgs ];
          Hashtbl.add chars key {id=code;xadvance;xoffset;yoffset;width=img.Rgba32.width;height=img.Rgba32.height;x=0;y=0;page=0};
        )
      end
    end !sizes;
    let () = Printf.printf "len imgs: %d\n%!" (List.length !imgs) in
    Xmlm.output xmlout (`El_start (("","Pages"),[]));

    let () = TextureLayout.rotate.val := False in
    let textures = TextureLayout.layout ~type_rects:`maxrect ~sqr:False !imgs in
    BatList.iteri begin fun i (w,h,imgs) ->
      let texture = Rgba32.make w h bgcolor in
      (
        List.iter begin fun (key,(x,y,_,img)) ->
          (
            let img = match img with [ Images.Rgba32 img -> img | _ -> assert False ] in
            Rgba32.blit img 0 0 texture x y img.Rgba32.width img.Rgba32.height;
            let r = Hashtbl.find chars key in
            ( r.x := x; r.y := y; r.page := i;)
          )
        end imgs;
        let imgname = Printf.sprintf "%s%d.png" fname i in
        (
          Images.save (match !output with [ None -> imgname | Some o ->
            Filename.concat o imgname]) (Some Images.Png) [] (Images.Rgba32 texture);
          Xmlm.output xmlout (`El_start (("","page"),["file" =|= imgname]));
          Xmlm.output xmlout `El_end;
        );
      )
    end textures;
    Xmlm.output xmlout `El_end;
  );
  List.iter begin fun size ->
    (
      Freetype.set_char_size face (float size) 0. !dpi 0;
      let spaceIndex = Freetype.get_char_index face (int_of_char ' ') in
      let (spaceXAdv, spaceYAdv) = Freetype.render_glyph face spaceIndex [] Freetype.Render_Normal in
      let sizeInfo = Freetype.get_size_metrics face in
      (
        let () = Printf.printf "descender: %f, max_advance: %f, x_ppem: %d, y_ppem: %d, ascender: %f, height: %f\n%!" sizeInfo.Freetype.descender sizeInfo.Freetype.max_advance sizeInfo.Freetype.x_ppem
        sizeInfo.Freetype.y_ppem sizeInfo.Freetype.ascender sizeInfo.Freetype.height in
        Xmlm.output xmlout (`El_start (("","Chars"),
          [ "space" =.= spaceXAdv; 
            "size" =*= size ; 
            "lineHeight" =.= sizeInfo.Freetype.height; 
            "ascender" =.= sizeInfo.Freetype.ascender;
            "descender" =.= ~-. (sizeInfo.Freetype.descender);
          ])
        );
        BatUTF8.iter begin fun uchar ->
          let code = BatUChar.to_int uchar in
          let info = Hashtbl.find chars (code,size) in
(*           let () = Printf.printf "char: %C, xoffset: %d, yoffset: %d\n%!" (char_of_int code) info.xoffset info.yoffset in *)
          let attribs = 
            [ "id" =*= code
            ; "xadvance" =.= info.xadvance
            ; "xoffset" =*= info.xoffset
            ; "yoffset" =*= (truncate (sizeInfo.Freetype.ascender -. (float info.yoffset)))
            ; "x" =*= info.x
            ; "y" =*= info.y
            ; "width" =*= info.width
            ; "height" =*= info.height
            ; "page" =*= info.page
            ]
          in
          (
            Xmlm.output xmlout (`El_start (("","char"),attribs));
            Xmlm.output xmlout `El_end;
          )
        end (BatUTF8.of_string !pattern);
      );
      Xmlm.output xmlout `El_end;
    )
  end !sizes;
  Xmlm.output xmlout `El_end;
  close_out out;
);


