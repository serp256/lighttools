DEFINE LOG(mes) = Printf.printf "%s\n%!" mes;
DEFINE LOGN(mes) = Printf.printf "%s%!" mes;
DEFINE ERROR(err) = ( LOG(Printf.sprintf "ERROR: %s" err); exit 1; );
DEFINE ASSERT(cond, err) = if not cond then ERROR(err) else ();
DEFINE RUN(cmd, err) = ( LOG(cmd); ASSERT(Sys.command cmd = 0, err); );

open Ojson;

value inp = ref "";
value out = ref "";
value rulesFiles = ref [];

value args = [
  ("-i", Arg.Set_string inp, "");
  ("-o", Arg.Set_string out, "")
];

Arg.parse args (fun fname -> rulesFiles.val := [ fname :: !rulesFiles ]) "";

ASSERT(!inp <> "" && !out <> "", "specify both input and output directory");
ASSERT(!rulesFiles <> [], "specify at least one rules file");
rulesFiles.val := List.rev !rulesFiles;

value (//) = Filename.concat;

type filterType = [ Include | Exclude | Protect ];

type rule = {
  path:string;
  dst:string;
  filter:list string;
  filterType:filterType;
  protect:list string;
};

List.iter (fun rulesFname ->
  try
    let rulesCnt = ref 0 in
    let rules =
      Browse.list (fun rule ->
        let props = try Browse.assoc rule with [ _ -> ERROR(Printf.sprintf "wrong %d rule format" !rulesCnt) ] in
        let path = try Browse.string (List.assoc "path" props) with [ Not_found -> "/" | _ -> ERROR(Printf.sprintf "wrong 'path' format on %d rule" !rulesCnt) ] in
        let dst = try Browse.string (List.assoc "dst" props) with [ Not_found -> path | _ -> ERROR("wrong 'dst' format for path '" ^ path ^ "'") ] in
        let incld = try Some (Browse.list (fun path -> Browse.string path) (List.assoc "include" props)) with [ Not_found -> None | _ -> ERROR("wrong 'include' format for path '" ^ path ^ "'") ] in
        let excld = try Some (Browse.list (fun path -> Browse.string path) (List.assoc "exclude" props)) with [ Not_found -> None | _ -> ERROR("wrong 'exclude' format for path '" ^ path ^ "'") ] in
        let protect = try Browse.list (fun path -> Browse.string path) (List.assoc "protect" props) with [ Not_found -> [] | _ -> ERROR("wrong 'protect' property format for path '" ^ path ^ "'") ] in
        let (filter, filterType) =
          match (incld, excld) with
          [ (Some _, Some _) -> ERROR("both include and exclude filtering not permited(specified for path '" ^ path ^ "')")
          | (Some incld, None) -> (incld, Include)
          | (None, Some excld) -> (excld, Exclude)
          | _ -> ([], Exclude)
          ]
        in (
          incr rulesCnt;
          { path; dst; filter; filterType; protect };
        )
      ) (from_file rulesFname)
    in
    let filterTypeStr filterType = match filterType with [ Include -> "+" | Exclude -> "-" | Protect -> "P" ] in
    let makeFilter path filters filterType =
      let filtersStr = String.concat " " (List.map (fun filter ->
                                                      let retval = Printf.sprintf "--filter=\"%s %s\"" (filterTypeStr filterType) filter in
                                                        if filterType = Include
                                                        then
                                                          let path = !inp // path // filter in
                                                          let filter =
                                                            if Sys.file_exists path && Sys.is_directory path
                                                            then filter ^ (if ExtString.String.ends_with filter "/" then "**" else "/**")
                                                            else filter in
                                                              Printf.sprintf "%s --filter=\"%s %s\"" retval (filterTypeStr filterType) filter                                                      
                                                        else retval
                                          ) filters)
      in
        if filterType = Include
        then filtersStr ^ " --filter=\"- **\""
        else filtersStr
    in
      List.iter (fun rule ->
        let inp = if rule.path = "/" then !inp ^ "/" else !inp // rule.path in
        let out = if rule.dst = "/" then !out ^ "/" else !out // rule.dst in
        let cmd = Printf.sprintf "rsync --delete-excluded -rLv %s %s %s %s" (makeFilter rule.dst rule.protect Protect) (makeFilter rule.path rule.filter rule.filterType) inp out in
          RUN(cmd,("rsync failed when processing rule for path '" ^ rule.path ^ "'"))
      ) rules;
  with [ _ -> ERROR("wrong rules file '" ^ rulesFname ^ "' format") ]
) !rulesFiles;
  