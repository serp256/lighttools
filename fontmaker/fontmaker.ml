open Printf;
open ExtString;

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
value color = ref {Color.r = 255; g = 255; b = 255};
value dpi = ref 72;

value bgcolor = {Color.color = {Color.r = 0; g = 0; b = 0}; alpha = 0};

value make_size face size callback = 
(
  Freetype.set_char_size face size 0. !dpi 0;
  UTF8.iter begin fun uchar ->
  (
    let code = UChar.code uchar in
(*     let () = Printf.printf "process char: %d\n%!" code in *)
    let char_index = Freetype.get_char_index face code in
    let (xadv,yadv) = Freetype.render_glyph face char_index [] Freetype.Render_Normal in
    let bi = Freetype.get_bitmap_info face in
    (* take bitmap as is for now *)
    let open Freetype in
(*     let () = Printf.printf "bi.width: %d, bi.height: %d\n%!" bi.bitmap_width bi.bitmap_height in *)
    let img =  Rgba32.make bi.bitmap_width bi.bitmap_height bgcolor in
    (
      for y = 0 to bi.bitmap_height - 1 do
        for x = 0 to bi.bitmap_width - 1 do
          let level = read_bitmap face x y in
          let color = {Color.color = {Color.r=level;Color.g=level;Color.b=level}; alpha = level} in
          Rgba32.set img x (bi.bitmap_height - y - 1) color
        done
      done;
(*         img#save (Printf.sprintf "%d.png" code) (Some Images.Png) []; *)
      callback code xadv bi.bitmap_left bi.bitmap_top img
    )
  )
  end !pattern;
);

type sdescr = 
  {
    id: int; xadvance: float; xoffset: int; yoffset: int; 
    width: int; height: int; x: mutable int; y: mutable int; page: mutable int
  };


value parse_sizes str = 
  try
    sizes.val := List.map int_of_string (String.nsplit str ",")
  with [ _ -> failwith "Failure parse sizes" ];

value read_chars fname = pattern.val := String.strip (Std.input_file fname);

(* use xmlm for writing xml *)
Arg.parse 
  [
    ("-c",Arg.Set_string pattern,"chars");
    ("-s",Arg.String parse_sizes,"sizes");
    ("-cf",Arg.String read_chars,"chars from file")
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

Printf.printf "chars: [%s] = %d\n%!" !pattern (UTF8.length !pattern);
let t = Freetype.init () in
let (face,face_info) = Freetype.new_face t !fontFile 0 in
let chars = Hashtbl.create 1 in
let fname = Filename.chop_extension !fontFile in
let xmlfname = fname ^ ".fnt" in
let out = open_out xmlfname in
let xmlout = Xmlm.make_output (`Channel (open_out xmlfname)) in
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
    let textures = TextureLayout.layout !imgs in
    ExtList.List.iteri begin fun i (w,h,imgs) ->
      let texture = Rgba32.make w h bgcolor in
      (
        List.iter begin fun (key,(x,y,img)) ->
          (
            let img = match img with [ Images.Rgba32 img -> img | _ -> assert False ] in
            Rgba32.blit img 0 0 texture x y img.Rgba32.width img.Rgba32.height;
            let r = Hashtbl.find chars key in
            ( r.x := x; r.y := y; r.page := i;)
          )
        end imgs;
        let imgname = Printf.sprintf "%s%d.png" fname i in
        (
          Images.save imgname (Some Images.Png) [] (Images.Rgba32 texture);
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
      let sizeInfo = Freetype.get_size_metrics face in
      Xmlm.output xmlout (`El_start (("","Chars"),[ "size" =*= size ; "lineHeight" =.= sizeInfo.Freetype.height; "baseLine" =.= sizeInfo.Freetype.ascender ]));
      UTF8.iter begin fun uchar ->
        let code = UChar.code uchar in
        let info = Hashtbl.find chars (code,size) in
        let attribs = 
          [ "id" =*= code
          ; "xadvance" =.= info.xadvance
          ; "xoffset" =*= info.xoffset
          ; "yoffset" =*= info.yoffset
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
      end !pattern;
      Xmlm.output xmlout `El_end;
    )
  end !sizes;
  Xmlm.output xmlout `El_end;
  close_out out;
);


