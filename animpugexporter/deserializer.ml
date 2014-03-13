open ExtString;
open ExtArray;

type t =
  {
    proj: Node.Common.t;
    libs: Libs.t;
  };





value run inp =
  try
    let fname = Array.find (fun fname -> String.ends_with fname ".pug") (Sys.readdir inp) in
    let store = Binstore.read (Filename.concat inp fname) in
    let inp   = Binstore.openChunk store 0 in
    let proj  = Node.Common.read inp in
    let libs  = Libs.ofProject proj in
      { proj; libs };
  with [ Not_found -> failwith "no project file found in input directory" ];

value project t = t.proj;
value libs t    = t.libs;


(* exit 0; *)