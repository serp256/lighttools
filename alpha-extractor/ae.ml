#!/usr/bin/env ocaml

#use "topfind";;
#require "extlib";;
#require "camlimages";;
#require "camlimages.png";;

let args = ref [];;
let argc = ref 0;;

Arg.parse [] (fun arg -> ( incr argc; if !argc > 2 then failwith "alpha extractor takes only two arguments" else args := arg :: !args; )) "alpha extractor, usage: ./ae.ml <source image> <out image>";;

let src = Images.load (List.hd (List.tl !args)) [] in
	let (srcw, srch) = Images.size src in
		let dst = Rgb24.make srcw srch { Color.Rgb.r = 0; g = 0; b = 0 } in
			match src with
			  Images.Rgba32 src ->
				(
					for i = 0 to srcw - 1 do
						for j = 0 to srch - 1 do
							let srcc = Rgba32.get src i j in
								let alpha = srcc.Color.Rgba.alpha in
									Rgb24.set dst i j { Color.Rgb.r = alpha; g = 0; b = 0 };
						done;
					done;

					Images.save (List.hd !args) (Some Images.Png) [] (Images.Rgb24 dst);
				)
			| _ -> assert false;;