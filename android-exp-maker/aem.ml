open Arg;
open Sys;
open ExtString;
open Printf;

value bufLen = 104857600;
value fileBuf = Buffer.create bufLen;
value inDir = ref ".";
value outDir = ref ".";
value package = ref "xyu.pizda.lala";
value version = ref 1;
value patchFor = ref "";
value patch = ref "";
value (indexBuf, indexBufLen) = IO.pos_out (IO.output_string ());
value (filesBuf, filesBufLen) = IO.pos_out (IO.output_string ());
value indexEntiesNum = ref 0;

value args =
  [
    ("-i", Set_string inDir, "input directory");
    ("-o", Set_string outDir, "output directory");
    ("-p", Set_string patchFor, "generate patch. pass through this option previous patch filename, it should contains only index, i.e. this patch of base-expansion version");
    ("-package", Set_string package, "application package");
    ("-version", Set_int version, "expansion and patch version, when generate fresh expansion-patch pair, and patch version, when generate only patch")
  ];

value addIndexEntry ?(main=True) filename offset size =
(
  incr indexEntiesNum;
  IO.write_byte indexBuf (String.length filename);
  IO.nwrite indexBuf filename;
  IO.write_i32 indexBuf offset;
  IO.write_i32 indexBuf size;
  IO.write_byte indexBuf (if main then 1 else 0);
);

value addFileEntry inChan size =
(
  Buffer.clear fileBuf;
  seek_in inChan 0;

  Buffer.add_channel fileBuf inChan size;
  IO.nwrite filesBuf (Buffer.contents fileBuf);    
);

value rec processFile ?(indent="") filename =
  try
  (
    printf "%sprocessing %s... " indent filename;

    if is_directory filename then
      let filename = if String.ends_with filename "/" then filename else filename ^ "/" in
      (
        printf "directory, scan it's content\n";
        Array.iter (fun childFilename -> processFile ~indent:(indent ^ "  ") (filename ^ childFilename)) (readdir filename);
      )
    else
      let inChan = open_in filename in
        let offset = filesBufLen ()
        and size = in_channel_length inChan in
        (
          printf "file, offset %d, size %d\n" offset size;

          let (_, filename) = String.replace filename !inDir "" in
            addIndexEntry filename offset size;
          
          addFileEntry inChan size;
          close_in inChan;
        )
  )
  with [ Sys_error _ -> () ];

value buildExpansion () =
  if is_directory !inDir then
  (
    if String.ends_with !inDir "/" then () else inDir.val := !inDir ^ "/";
    if String.ends_with !outDir "/" then () else outDir.val := !outDir ^ "/";

    processFile !inDir;

    let outFname = !outDir ^ "main." ^ (string_of_int !version) ^ "." ^ !package ^ ".obb" in
      let outChan = open_out outFname in
        let (out, outLen) = IO.pos_out (IO.output_channel outChan) in
        (
          IO.nwrite out (IO.close_out filesBuf);

          printf "main expansion done, out file location: %s; size %d\n" outFname (outLen ());

          IO.close_out out;
          close_out outChan;
        );

    let outFname = !outDir ^ "patch." ^ (string_of_int !version) ^ "." ^ !package ^ ".obb" in
      let outChan = open_out outFname in
        let (out, outLen) = IO.pos_out (IO.output_channel outChan) in
        (
          IO.write_i32 out !indexEntiesNum;
          IO.nwrite out (IO.close_out indexBuf);

          printf "patch done, out file location: %s; size %d\n" outFname (outLen ());

          IO.close_out out;
          close_out outChan;
        );
  )
  else
    printf "error: input should be directory";

value buildPatch () =
  if Sys.file_exists !patchFor then
    let index = Hashtbl.create 0
    and inpChan = open_in !patchFor in
      let (inp, posInp) = IO.pos_in (IO.input_channel inpChan) in
      (
        let idxEntriesNum = IO.read_i32 inp in
          (
            for i = 1 to idxEntriesNum do {
              let fnameLen = IO.read_byte inp in
                let fname = IO.nread inp fnameLen
                and offset = IO.read_i32 inp
                and size = IO.read_i32 inp
                and inMain = IO.read_byte inp in
                  if inMain = 0 then failwith "index contains entries for files from patch, it may cause some promlems, choose another expansion version as base"
                  else
                    Hashtbl.replace index fname (offset, size);
            };

            IO.close_in inp;
            close_in inpChan;

            let patchname = Filename.basename !patchFor
            and dirname = Filename.dirname !patchFor in
              if not (String.starts_with patchname "patch") then failwith "wrong patch filename"
              else
                let (_, expname) = String.replace patchname "patch" "main" in
                  let expname = Filename.concat dirname expname in
                  if not (Sys.file_exists expname) then failwith "no suitable main expansion file found"
                  else
                    let inpChan = open_in expname in
                      let (inp, posInp) = IO.pos_in (IO.input_channel inpChan) in
                        let curContent = Buffer.create bufLen
                        and newContent = Buffer.create bufLen in
                          let addToPatch fname inpChan size = ( addIndexEntry ~main:False fname (filesBufLen ()) size; addFileEntry inpChan size; ) in
                          let rec processFile ?(indent="") filename =
                            try
                              if is_directory filename then
                                let filename = if String.ends_with filename "/" then filename else filename ^ "/" in
                                  Array.iter (fun childFilename -> processFile ~indent:(indent ^ "  ") (filename ^ childFilename)) (readdir filename)
                              else
                                let _inpChan = open_in filename in
                                (
                                  let newSize = in_channel_length _inpChan in
                                    let (_, relativeFname) = String.replace filename !inDir "" in
                                      try                                            
                                        let (offset, curSize) = Hashtbl.find index relativeFname in
                                          if newSize <> curSize then addToPatch relativeFname _inpChan newSize 
                                          else
                                          (
                                            seek_in inpChan (offset);
                                            Buffer.clear curContent;
                                            Buffer.add_channel curContent inpChan curSize;

                                            Buffer.clear newContent;
                                            Buffer.add_channel newContent _inpChan newSize;

                                            if Buffer.contents curContent <> Buffer.contents newContent then addToPatch relativeFname _inpChan newSize
                                            else addIndexEntry relativeFname offset curSize;
                                          )
                                      with [ Not_found -> addToPatch relativeFname _inpChan newSize ];
                                  close_in _inpChan;
                                )
                            with [ Sys_error _ -> () ]
                          in
                          (
                            if String.ends_with !inDir "/" then () else inDir.val := !inDir ^ "/";
                            if String.ends_with !outDir "/" then () else outDir.val := !outDir ^ "/";

                            processFile !inDir;

                            IO.close_in inp;
                            close_in inpChan;

                            let outFname = Filename.concat !outDir ("patch." ^ (string_of_int !version) ^ "." ^ !package ^ ".obb") in
                              let outChan = open_out outFname in
                                let (out, outLen) = IO.pos_out (IO.output_channel outChan) in
                                (
                                  IO.write_i32 out !indexEntiesNum;
                                  IO.nwrite out (IO.close_out indexBuf);
                                  IO.nwrite out (IO.close_out filesBuf);

                                  printf "patch done, out file location: %s; size %d\n" outFname (outLen ());

                                  IO.close_out out;
                                  close_out outChan;
                                );

                            let src = if Filename.is_relative expname then Filename.concat (Unix.getcwd ()) expname else expname
                            and dst = Filename.concat !outDir (Filename.basename expname) in
                              let dst = if Filename.is_relative dst then Filename.concat (Unix.getcwd ()) dst else dst in
                              (                                                                
                                try Sys.remove dst with [ Sys_error _ -> () ];
                                Unix.symlink src dst;
                              );
                          );
          );
      )
  else failwith "cannot open source expansion file";

parse args (fun _ -> ()) "Lightning android expansions maker";

if !patchFor <> "" then
  buildPatch ()
else
  buildExpansion ();