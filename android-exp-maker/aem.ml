open Arg;
open Sys;
open ExtString;
open Printf;

value bufLen = 104857600;
value inDir = ref ".";
value outFname = ref "expansion";
value patchFor = ref "";
value indexBuf = IO.output_string ();
value (filesBuf, filesBufLen) = IO.pos_out (IO.output_string ());
value indexEntiesNum = ref 0;

value args =
    [
        ("-i", Set_string inDir, "output filename");
        ("-p", Set_string patchFor, "generate patch for file, gived through this option, instead of full expansion");
        ("-o", Set_string outFname, "output filename")
    ];

value addEntry filename offset size =
(
    incr indexEntiesNum;
    IO.write_byte indexBuf (String.length filename);
    IO.nwrite indexBuf filename;
    IO.write_i32 indexBuf offset;
    IO.write_i32 indexBuf size;
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
                        addEntry filename offset size;
                    
                    let fileContent = String.create size in
                    (
                        really_input inChan fileContent 0 size;
                        IO.nwrite filesBuf fileContent;  
                    );
                                
                    close_in inChan;
                )
    )
    with [ Sys_error _ -> () ];

value buildExpansion () =
    if is_directory !inDir then
    (
        if String.ends_with !inDir "/" then () else inDir.val := !inDir ^ "/";
        processFile !inDir;

        let outFname = !outFname
        and outChan = open_out !outFname in
            let (out, outLen) = IO.pos_out (IO.output_channel outChan) in
            (
                IO.write_byte out 0;
                IO.write_i32 out !indexEntiesNum;
                IO.nwrite out (IO.close_out indexBuf);
                IO.nwrite out (IO.close_out filesBuf);

                printf "done, out file location: %s; size %d\n" outFname (outLen ());

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
                let patchVerLen = IO.read_byte inp in
                    ignore(IO.nread inp patchVerLen);

                let idxEntriesNum = IO.read_i32 inp in
                    let indexArr = DynArray.make idxEntriesNum in
                    (
                        for i = 1 to idxEntriesNum do {
                            let fnameLen = IO.read_byte inp in
                                let fname = IO.nread inp fnameLen
                                and offset = IO.read_i32 inp
                                and size = IO.read_i32 inp in
                                (
                                    DynArray.add indexArr (fname, offset, size);
                                    Hashtbl.replace index fname (offset, size, i);
                                );
                        };

                        let curContent = Buffer.create bufLen
                        and newContent = Buffer.create bufLen
                        and indexAppendix = ref []
                        and dataOffset = posInp () in
                            let rec processFile ?(indent="") filename =
                                try
                                (
                                    if is_directory filename then
                                        let filename = if String.ends_with filename "/" then filename else filename ^ "/" in
                                            Array.iter (fun childFilename -> processFile ~indent:(indent ^ "  ") (filename ^ childFilename)) (readdir filename)
                                    else
                                        let (_, relativeFname) = String.replace filename !inDir "" in
                                            try                                            
                                                let (offset, curSize, entryIdx) = Hashtbl.find index relativeFname in                                                
                                                (
                                                    seek_in inpChan (offset + dataOffset);
                                                    Buffer.clear curContent;
                                                    Buffer.add_channel curContent inpChan curSize;

                                                    let _inpChan = open_in filename in
                                                    (
                                                        let newSize = in_channel_length _inpChan in
                                                            if newSize <> curSize then ()
                                                            else
                                                            (
                                                                Buffer.clear newContent;
                                                                Buffer.add_channel newContent _inpChan newSize;

                                                                if Buffer.contents curContent <> Buffer.contents newContent then ()
                                                                else Hashtbl.remove index relativeFname;
                                                            );

                                                        close_in _inpChan;
                                                    );
                                                )
                                            with [ Not_found -> indexAppendix.val := [ relativeFname :: !indexAppendix ] ];
                                )
                                with [ Sys_error _ -> () ]
                            in
                            (
                                if String.ends_with !inDir "/" then () else inDir.val := !inDir ^ "/";
                                processFile !inDir;

                                printf "appendix list:\n";
                                List.iter (fun fname -> printf "%s\n" fname) !indexAppendix;
                                

                                printf "remove list:\n";

                                Hashtbl.iter (fun fname _ -> printf "rm %s\n" fname) index;
                                (* List.iter (fun idx -> printf "%d\n" idx) !removeFromIndex; *)
                            );
                    );

                (* Hashtbl.iter (fun fname (offset, size) -> Printf.printf "filename %s %d %d\n" fname offset size) index; *)


                IO.close_in inp;
                close_in inpChan;
            )
    else failwith "cannot open source expansion file";

parse args (fun arg -> if arg <> "" then inDir.val := arg else ())  "Lightning android expansions maker";

if !patchFor <> "" then
    buildPatch ()
else
    buildExpansion ();