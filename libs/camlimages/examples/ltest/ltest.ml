open Freetype;;


let t = Freetype.init () in
let (face,_) = Freetype.new_face t "DejaVuSerif.ttf" 0 in
let () = Freetype.set_char_size face 24.0 0. 72 0 in
let gsm = Freetype.get_size_metrics face in
Printf.printf 
	"asc: %f, desc: %f, height: %f, max_advance: %f\n%!"
	gsm.ascender gsm.descender gsm.sm_height gsm.max_advance
;;
