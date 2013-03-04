DEFINE ERROR(errMes) = failwith (Printf.sprintf "ERROR: %s" errMes);
DEFINE ASSERT(cond, errMes) = if not cond then ERROR(errMes) else ();

value concat = ref False;
value extract = ref False;
value diff = ref False;
value inp = ref "";
value out = ref "";
value fname = ref "";
value diffFnameA = ref "";
value diffFnameB = ref "";

value args = [
  ("-concat", Arg.Set concat, "");
  ("-extract", Arg.Set extract, "");
  ("-diff", Arg.Tuple [ Arg.Set diff; Arg.Set_string diffFnameA; Arg.Set_string diffFnameB ], "");
  ("-i", Arg.Set_string inp, "");
  ("-o", Arg.Set_string out, "");
  ("-fname", Arg.Set_string fname, "");
];

Arg.parse args (fun _ -> ()) "Android resources maker";

(* ASSERT(!concat || !extract || !diff, "-concat, -extract or -diff option should be given to determine what to do"); *)

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
    _readdir root [];

value concatFiles ?(fprefix = "") files out =
  let outChan = open_out out in
  let rec _concatFiles index files offset =
    match files with
    [ [] -> index
    | [ fname :: files ] ->
      let inChan = open_in (if fprefix <> "" then Filename.concat fprefix fname else fname) in
      let inLen = in_channel_length inChan in
      let buf = Buffer.create inLen in (
        try Buffer.add_channel buf inChan inLen with [ End_of_file -> ERROR ("error when reading " ^ fname) ];
        close_in inChan;

        Buffer.output_buffer outChan buf;
        _concatFiles (Index.add index fname (Index.Entry.create offset inLen)) files (offset + inLen);
      )
    ]
  in
  let index = _concatFiles (Index.create ()) files 0 in (
    close_out outChan;

    let outChan = open_out (out ^ Index.ext) in (
      Marshal.to_channel outChan index [];
      close_out outChan;
    );
  );

value checkOut () = (
  ASSERT(not (Sys.file_exists !out && Sys.is_directory !out), "output file exists and it's directory, remove at first or specify another output filename");
  ASSERT(Sys.file_exists (Filename.dirname !out), "output filename path doesn't exists");

  if Sys.file_exists !out
  then Sys.remove !out
  else ();  
);

value runConcat inp out = (
  ASSERT(inp <> "" && out <> "", "specify both input directory and output filename");
  ASSERT(Sys.file_exists inp, "input directory doesn't exists");
  ASSERT(Sys.is_directory inp, "input should be directory, not regular file");

  checkOut ();
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
  ASSERT(Sys.file_exists fnameA, "input file A doesn't exists");
  ASSERT(Sys.file_exists fnameA, "input directory B doesn't exists");
  ASSERT(not (Sys.is_directory fnameA), "input file A is directory. should be regular file");
  ASSERT(Sys.is_directory fnameB, "input directory B is regular file. should be directory");
  ASSERT(out <> "", "specify output filename");

  checkOut ();

  let indexFnameA = fnameA ^ Index.ext in (
    ASSERT(Sys.file_exists indexFnameA, "index for input file A doesn't exists");

    let inChanA = open_in fnameA in
    let indexInChanA = open_in (fnameA ^ Index.ext) in
    let indexA = Marshal.from_channel indexInChanA in (
      close_in indexInChanA;

      let files =
        List.filter (fun fname ->
          try
            let entry = Index.get indexA fname in
            let size = Index.Entry.getSize entry in
            let inChanB = open_in (Filename.concat fnameB fname) in
            let inLenB = in_channel_length inChanB in
              if size <> inLenB
              then True
              else (
                seek_in inChanA (Index.Entry.getOffset entry);

                let retval = Digest.(compare (channel inChanA size) (channel inChanB inLenB)) <> 0 in (
                  close_in inChanB;
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

if !concat
then runConcat !inp !out
else if !extract then runExtract !inp !out !fname
else if !diff then runDiff !diffFnameA !diffFnameB !out
else ();
