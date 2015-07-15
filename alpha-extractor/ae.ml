#!/usr/bin/env ocaml

#use "topfind";;
#require "extlib";;
#require "camlimages";;
#require "camlimages.png";;

let args = ref [];;
let argc = ref 0;;
let pot = ref false;;

Arg.parse [ ("-pot", Arg.Set pot, "pot texture")] 
   (fun arg -> ( 
     incr argc; 
     if !argc > 2 then failwith "alpha extractor takevs only two arguments" else args := arg :: !args; 
   )) "alpha extractor, usage: ./ae.ml <source image> <out image>";;

let find_next_pot x =
  let x = x -1 in
  let x = x lor (x lsr 1) in
  let x = x lor (x lsr 2) in
  let x = x lor (x lsr 4) in
  let x = x lor (x lsr 8) in
  let x = x lor (x lsr 16) in
  let x = x + 1 in
  x in
let src = Images.load (List.hd (List.tl !args)) [] in
	let (srcw, srch) = Images.size src in
  let (dstw, dsth) = 
    if !pot 
    then
      let m = max srcw srch in
      let r = find_next_pot m in
      (r, r)
    else (srcw, srch) in
		let dst = Rgb24.make dstw dsth { Color.Rgb.r = 0; g = 0; b = 0 } in
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
