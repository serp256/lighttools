DEFINE ERROR(errMes) = failwith (Printf.sprintf "ERROR: %s" errMes);
DEFINE ASSERT(cond, errMes) = if not cond then ERROR(errMes) else ();
DEFINE LOG(mes) = Printf.printf "%s\n%!" mes;
DEFINE LOGN(mes) = Printf.printf "%s%!" mes;

value concat = ref False;
value extract = ref False;
value diff = ref False;
value merge = ref False;
value inp = ref "";
value out = ref "";
value fname = ref "";
value diffFnameA = ref "";
value diffFnameB = ref "";
value mergeFnames = ref [];

value appendToMerge fname = (
  LOG("appendToMerge " ^ fname);
  ASSERT(List.length !mergeFnames < 3, "cannot merge more than 3 files");
  mergeFnames.val := [ fname :: !mergeFnames ];
);

value args = [
  ("-concat", Arg.Set concat, "\tmake so-called light archive (sigle file which contains files from input directory one-by-one)");
  ("-extract", Arg.Set extract, "\textract specified file from light-archive");
  ("-diff", Arg.Tuple [ Arg.Set diff; Arg.Set_string diffFnameA; Arg.Set_string diffFnameB ], "\tmake light archive from diff between directory content and another light archve");
  ("-merge", Arg.Set merge, "\tperform merging of specified archives indexes");
  ("-i", Arg.Set_string inp, "\t\tinput file or directody, depend on usage");
  ("-o", Arg.Set_string out, "\t\toutput file");
  ("-fname", Arg.Set_string fname, "\tusing only with -extract option, specifies file name to extract from light archive");
];

value usage = "Android resources maker, usage:\n"
  ^ "\taresmkr -concat -i <inp-dirname> -o <out-fname> -- reads content of directory <inp-dirname> and make light archive, named <out-fname>\n"
  ^ "\taresmkr -extract -i <light-archive> -fname <fname-to-extract> -o <out-fname> -- extract <fname-to-extract> from <light-archive> to <out-fname>\n"
  ^ "\taresmkr -diff -o <out-fname> <light-archive> <dir> -- makes diff light-archive, determine which files are not in <light-archive> or changed since <light-archive> was made and include these files into new light-archive named <out-fname>\n"
  ^ "\taresmkr -merge -o <out-fname> <assets-archive> -- makes binary index for single light-archive <assets-archive>, uses for apps without expansions\n"
  ^ "\taresmkr -merge -o <out-fname> <assets-archive> <main-exp-archive> -- makes common binary index for specified light archives\n"
  ^ "\taresmkr -merge -o <out-fname> <assets-archive> <patch-exp-archive> <main-exp-archive> -- same as previous\n"
  ^ "\tpay attention to archives order, when merging, assets have high priority, than patch, than main expansion\n";


Arg.parse args appendToMerge usage;

ASSERT(!concat || !extract || !diff || !merge, "-concat, -extract, -diff or -merge option should be given to determine what to do");

value readdir root =
  let rec _readdir dir files =
    Array.fold_right (fun fname files ->
      let fname = Filename.concat dir fname in
        if Sys.is_directory fname
        then _readdir fname files
        else
          let (_, fname) = ExtString.String.replace fname root "" in
          let fname = if ExtString.String.starts_with fname "/" then String.sub fname 1 (String.length fname - 1) else fname in
            [ fname :: files ]
    ) (Sys.readdir dir) files
  in
    List.sort (fun a b -> compare a b) (_readdir root []);

value concatFiles ?(fprefix = "") files out = (
  let outChan = open_out out in
  let rec _concatFiles index files offset =
    match files with
    [ [] -> index
    | [ fname :: files ] ->
      let () = LOGN("process '" ^ fname ^ "'...") in
      try
      let inChan = open_in (if fprefix <> "" then Filename.concat fprefix fname else fname) in
      let inLen = in_channel_length inChan in
      let buf = Buffer.create inLen in (
        try Buffer.add_channel buf inChan inLen with [ End_of_file -> ERROR ("error when reading " ^ fname) ];
        close_in inChan;

        Buffer.output_buffer outChan buf;
        LOG(Printf.sprintf " done, offset %d, size %d" offset inLen);
        _concatFiles (Index.add index fname (Index.Entry.create offset inLen)) files (offset + inLen);
      )
       with
      [ exn ->
          (
            Printf.printf "!!!ERROR %s :\n %s\n%!" (Printexc.to_string exn) (Printexc.get_backtrace () );
            raise exn;
          )
      ]
    ]
  in
  let index = _concatFiles (Index.create ()) files 0 in (
    close_out outChan;

    let outChan = open_out (out ^ Index.ext) in (
      Marshal.to_channel outChan index [];
      close_out outChan;
    );

    LOG("done, files written to '" ^ out ^ "', index written to '" ^ (out ^ Index.ext) ^ "'");
  );  
);

value checkOutFname out = (
  ASSERT(not (Sys.file_exists out && Sys.is_directory out), "output file exists and it's directory, remove at first or specify another output filename");
  ASSERT(Sys.file_exists (Filename.dirname out), "output filename path doesn't exists");

  if Sys.file_exists out
  then Sys.remove out
  else ();  
);

value runConcat inp out = (
  LOG("concatenating files from '" ^ inp ^ "'");

  ASSERT(inp <> "" && out <> "", "specify both input directory and output filename");
  ASSERT(Sys.file_exists inp, "input directory doesn't exists");
  ASSERT(Sys.is_directory inp, "input should be directory, not regular file");

  checkOutFname out;
  concatFiles ~fprefix:inp (readdir inp) out;
);

value runExtract inp out fname =
  let indexFname = inp ^ Index.ext in (
    ASSERT(inp <> "" && out <> "", "specify both input and output filenames");
    ASSERT(Sys.file_exists inp, "input file doesn't exists");
    ASSERT(Sys.file_exists indexFname, "index file doesn't exists");
    ASSERT(not (Sys.file_exists out && Sys.is_directory out), "output file exists and it's directory, remove at first or specify another output filename") ;
    ASSERT(Sys.file_exists (Filename.dirname out), "output filename path doesn't exists");

    let inChan = open_in indexFname in 
    let index = Marshal.from_channel inChan in (
      close_in inChan;

      try
        let entry = Index.get index fname in
        let inChan = open_in inp in (
          seek_in inChan (Index.Entry.getOffset entry);

          let bufSize = Index.Entry.getSize entry in
          let buf = Buffer.create bufSize in (
            Buffer.add_channel buf inChan bufSize;
            close_in inChan;

            let out = open_out out in (
              Buffer.output_buffer out buf;
              close_out out;
            );
          );
        );
              
      with [ Index.No_entry -> ERROR(fname ^ " not found in files index") ]
    );  
  );

value runDiff fnameA fnameB out = (
  LOG("making diff between '" ^ fnameA ^ "' and files from '" ^ fnameB ^ "'");

  ASSERT(Sys.file_exists fnameA, "input file " ^ fnameA ^ " doesn't exists");
  ASSERT(Sys.file_exists fnameA, "input directory " ^ fnameB ^ " doesn't exists");
  ASSERT(not (Sys.is_directory fnameA), "input file " ^ fnameA ^ " is directory. should be regular file");
  ASSERT(Sys.is_directory fnameB, "input directory " ^ fnameB ^ " is regular file. should be directory");
  ASSERT(out <> "", "specify output filename");

  checkOutFname out;

  let indexFnameA = fnameA ^ Index.ext in (
    ASSERT(Sys.file_exists indexFnameA, "index for input file A doesn't exists");

    let inChanA = open_in fnameA in
    let indexInChanA = open_in (fnameA ^ Index.ext) in
    let indexA = Marshal.from_channel indexInChanA in (
      close_in indexInChanA;

      let files =
        List.filter (fun fname ->
          let () = LOGN("processing '" ^ fname ^ "'... ") in
          try
            let entry = Index.get indexA fname in
            let size = Index.Entry.getSize entry in
            let inChanB = open_in (Filename.concat fnameB fname) in
            let inLenB = in_channel_length inChanB in
              if size <> inLenB
              then (
                LOG "different sizes, include in diff";
                True;
              )
              else (
                LOGN "sizes matched, checking content... ";
                seek_in inChanA (Index.Entry.getOffset entry);

                let retval = Digest.(compare (channel inChanA size) (channel inChanB inLenB)) <> 0 in (
                  close_in inChanB;
                  LOG (if retval then "different content, include in diff" else "content identical, skip");
                  retval;
                );
              )
          with [ Index.No_entry -> True ]
        ) (readdir fnameB)
      in (
        close_in inChanA;        
        concatFiles ~fprefix:fnameB files out;
      );
    );
  );
);

value addBinIndexEntry buf fname offset size location =
(
  IO.write_byte buf (String.length fname);
  IO.nwrite buf fname;
  IO.write_i32 buf offset;
  IO.write_i32 buf size;
  IO.write_byte buf location;
);

value runMerge mergeFnames out = (
  LOG("merging indexes for files " ^ (String.concat "," mergeFnames));

  checkOutFname out;

  let indexes =
    List.map (fun fname ->
      let fname = fname ^ Index.ext in
      let () = ASSERT(Sys.file_exists fname, "index for '" ^ fname ^ "' doesn't exists") in
      let inp = open_in fname in
      let index = Marshal.from_channel inp in (        
        close_in inp;
        index;
      )
    ) mergeFnames
  in
  let (indexBuf, indexBufLen) = IO.pos_out (IO.output_string ()) in
  let indexes = 
    match indexes with
    [ [ assetsIndex; patchIndex; mainIndex ] ->
      let () = LOG("merging assets, patch and main expansion") in [ (assetsIndex, 0); (patchIndex, 1); (mainIndex, 2) ]
    | [ assetsIndex; mainIndex ] ->
      let () = LOG("merging assets and main expansions") in [ (assetsIndex, 0); (mainIndex, 2) ]
    | [ assetsIndex ] ->
      let () = LOG("merging only assets") in [ (assetsIndex, 0) ]
    | _ -> ERROR("at least one index should be provided for merge")
    ]
  in
  let rec merge indexes (alreadyAdded, entriesNum) =    
    match indexes with
    [ [ (index, location) :: indexes ] ->
      let () = LOG("processing index with location " ^ (string_of_int location) ^ "...") in
      let (alreadyAdded, entriesNum) =
        Index.fold index (fun fname entry (alreadyAdded, entriesNum) ->
          let () = LOGN("\tprocessing file '" ^ fname ^ "'...") in
          if List.mem fname alreadyAdded
          then
            let () = LOG(" already in index, skip") in (alreadyAdded, entriesNum)
          else (
            LOG(" adding to binary index");
            addBinIndexEntry indexBuf fname (Index.Entry.getOffset entry) (Index.Entry.getSize entry) location;
            ([ fname :: alreadyAdded ], entriesNum + 1);
          )
        ) (alreadyAdded, entriesNum)
      in
        merge indexes (alreadyAdded, entriesNum)
    | _ -> entriesNum
    ]
  in
  let entriesNum = merge indexes ([], 0) in
  let outChan = open_out out in
    let (out, outLen) = IO.pos_out (IO.output_channel outChan) in
    (
      LOG(" done, writing binary index, enties num " ^ (string_of_int entriesNum));
      IO.write_i32 out entriesNum;
      IO.nwrite out (IO.close_out indexBuf);
      IO.close_out out;
      close_out outChan;
    );  
);

if !concat
then runConcat !inp !out
else if !extract then runExtract !inp !out !fname
else if !diff then runDiff !diffFnameA !diffFnameB !out
else if !merge then runMerge (List.rev !mergeFnames) !out
else ();
