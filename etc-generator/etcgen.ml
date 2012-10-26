#!/usr/bin/env ocaml

#use "topfind";;
#require "extlib";;
#load "unix.cma";;

let argc = ref 0;;
let src = ref ".";;
let noAlpha = ref false;;

let myassert exp mes = if not exp then ( Printf.printf "\n%!"; failwith mes ) else ();;
let runCommand command errMes =
(
    Printf.printf "%s\n%!" command;
    myassert (Sys.command command = 0) errMes;
);;

Arg.parse [ ("-noalpha", Arg.Set noAlpha, "force etc generator to skip alpha texture") ] (fun arg -> ( incr argc; if !argc > 1 then failwith "etc generator takes only one argument: source image filename" else src := arg; )) "generate ETC texture for source file, separate alpha, compress alpha to ETC format, takes single argument -- source image";;

if !argc = 0 then
	failwith "no source image specified"
else
	let tmpDir = Filename.get_temp_dir_name ()
	and fname = Filename.basename (Filename.chop_extension !src)
	and dname = Filename.dirname !src in
		let alphaFname = Filename.concat tmpDir (fname ^ "_alpha.png")
		and pvrAlphaOutFname = Filename.concat tmpDir (fname ^ "_alpha.pvr")
		and pvrOutFname = Filename.concat tmpDir (fname ^ ".pvr") in
		(			
			runCommand ("PVRTexTool -i" ^ !src ^ " -yflip0 -fETC -o" ^ pvrOutFname) "";

			if not !noAlpha then
			(
				runCommand ("ae " ^ !src ^ " " ^ alphaFname) "";
				runCommand ("PVRTexTool -i" ^ alphaFname ^ " -yflip0 -fETC -o" ^ pvrAlphaOutFname) "";
			) else ();			

			Sys.rename pvrOutFname (Filename.concat dname (fname ^ ".etc"));

			if not !noAlpha then
			(
				Sys.rename pvrAlphaOutFname (Filename.concat dname (fname ^ "_alpha.etc"));
				Sys.remove alphaFname;				
			) else ();
		);;