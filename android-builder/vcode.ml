#!/usr/bin/env ocaml

let screens = [ ("small", 0); ("normal", 1); ("large", 2); ("xlarge", 3) ];;
let densities = [ ("ldpi", 0); ("mdpi", 1); ("hdpi", 2); ("xhdpi", 3); ("tvdpi", 4); ("xxhdpi", 5) ];;
let textures = [ ("etc", 0); ("pvr", 1); ("atc", 2); ("dds", 3); ("dxt", 3); ("etc2", 4) ];;
let argv = Array.make 3 "";;
let argc = ref 0;;

Arg.parse [] (fun arg -> if !argc > 2 then failwith "vcode takes only three arguments" else ( Array.set argv !argc arg; incr argc; )) "android version code generator, usage: vcode <small|normal|large|xlarge> <ldpi|mdpi|hdpi|xhdpi|tvdpi> <etc|pvr|atc|dxt|etc2>";;
Printf.printf "%d%d%d\n" (List.assoc (Array.get argv 0) screens) (List.assoc (Array.get argv 1) densities) (List.assoc (Array.get argv 2) textures);
