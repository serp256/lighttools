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
value rulesMD5 = Filename.concat "." ".lsync2rule.md5";

value compile () =
  if Sys.file_exists rulesPath
  then
    let cmd = Printf.sprintf "ocamlfind ocamlc -g -package camlp4 -syntax camlp4r -package lsync2lib -package ojson -package str -linkpkg %s -o %s" rulesPath binFname in
    let ret = Sys.command cmd in
      (
        Sys.command "rm -f *.cm{o,i}";
        let cur_md5 = Digest.to_hex (Digest.file rulesPath) in
        let out = open_out rulesMD5 in
          (
            Digest.output out cur_md5;
            close_out out;
          );

        if ret <> 0
        then failwith ("Error when making '" ^ binFname ^ "' binary")
        else ();        
      )
  else failwith "Rules file not found";



if Sys.file_exists rulesMD5
then
  let cur_md5 = Digest.to_hex (Digest.file rulesPath) in
  let inp = open_in rulesMD5 in
  let old_md5 = Digest.input inp in
    (
      close_in inp;
      match cur_md5 = old_md5 with
      [ True ->  ()
      | _ -> 
          (
            compile ();
          )
      ]
    )
else compile ();

let args = String.concat " " (List.tl (Array.to_list Sys.argv)) in
let cmd = binPath ^ " " ^ args in
  if Sys.command cmd <> 0
  then failwith ("Error when running '" ^ binPath ^ "'")
  else ();
