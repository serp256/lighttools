value binFname = "lsync2run";
value binPath = Filename.concat "." binFname;
value rulesFile = ref "lsync2_rules.ml";

value args  = 
  let cmd_params  = ref "" in
  let skip_i = ref 0 in
  let argv = Sys.argv in
  (
    Array.iteri (fun i param -> 
      match i = !skip_i with
      [ True -> ()
      | _ -> 
          match param with
          [ "-rule-file" -> 
              (
                rulesFile.val := argv.(i+1);
                skip_i.val := i + 1;
              )
          | _ -> cmd_params.val := !cmd_params ^ param ^ " " 
          ]
      ]
    ) argv;
    !cmd_params;
  );

(*
Arg.parse 
  [
    ("-rule-file",  Arg.Set_string rulesFile, "rules name file bu default lsync2_rules.ml");
  ]
  (fun _ -> ())
  "";
  *)

value rulesPath = Filename.concat "." !rulesFile;

value compile () =
  if Sys.file_exists rulesPath
  then
    let cmd = Printf.sprintf "ocamlfind ocamlc -package camlp4 -syntax camlp4r -package lsync2lib -linkpkg %s -o %s" rulesPath binFname in
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

(*
let args = String.concat " " (List.tl (Array.to_list Sys.argv)) in
*)
let cmd = binPath ^ " " ^ args in
  if Sys.command cmd <> 0
  then failwith ("Error when running '" ^ binPath ^ "'")
  else ();
