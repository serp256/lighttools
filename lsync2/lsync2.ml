value binFname = "lsync2run";
value binPath = Filename.concat "." binFname;
value rulesFile = ref "lsync2_rules.ml";

Array.iter (fun param -> 
  match  ExtString.String.nsplit param "=" with
  [ ["rule_file"; fname] -> 
      (
        rulesFile.val := fname;
      )
  | _ -> ()
  ]
) Sys.argv;

value rulesPath = Filename.concat "." !rulesFile;

value compile () =
  if Sys.file_exists rulesPath
  then
    let cmd = Printf.sprintf "ocamlfind ocamlc -g -package camlp4 -syntax camlp4r -package lsync2lib -package ojson -package str -linkpkg %s -o %s" rulesPath binFname in
    let ret = Sys.command cmd in
      (
        Sys.command "rm -f *.cm{o,i}";

        if ret <> 0
        then failwith ("Error when making '" ^ binFname ^ "' binary")
        else ();        
      )
  else failwith "Rules file not found";

if Sys.file_exists binPath
then
  let binStat = Unix.stat binPath in
  let rulesStat = try Unix.stat rulesPath with [ _ -> failwith "Rules file not found" ] in
    if binStat.Unix.st_mtime < rulesStat.Unix.st_mtime
    then compile ()
    else ()
else compile ();

let args = String.concat " " (List.tl (Array.to_list Sys.argv)) in
let cmd = binPath ^ " " ^ args in
  if Sys.command cmd <> 0
  then failwith ("Error when running '" ^ binPath ^ "'")
  else ();
