open ExtString;


let fname = Sys.argv.(1) in
let img = Images.load fname [] in
let fname = chop_ext fname in
Utils.save_alpha img (fname ^ ".alpha");
