open ExtString;

value chop_ext f = 
  try
    let idx = (String.rindex f '.') + 1 in
    String.sub f 0 (idx - 1)
  with [ Not_found -> f ];


let fname = Sys.argv.(1) in
let img = Images.load fname [] in
let fname = chop_ext fname in
Utils.save_alpha img (fname ^ ".alpha");
