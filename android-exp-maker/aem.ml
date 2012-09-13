open Arg;
open Sys;
open ExtString;
open Printf;

type index = Hashtbl.t string (int * int);

value inDir = ref ".";
value outDir = ref ".";
value indexBuf = IO.output_string ();
value (filesBuf, filesBufLen) = IO.pos_out (IO.output_string ());
value indexEntiesNum = ref 0;
value expansionDefFilename = "expansion";
value arg =
	[
		("-o", Set_string outDir, "expansion output directory")
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
					(
						addEntry filename offset size;

						if (String.ends_with filename ".pvr") || (String.ends_with filename ".plx") then
							let filename = (Filename.chop_extension filename) ^ ".png" in
								let () = printf "%sappending addition entry %s\n" indent filename in
									addEntry filename offset size
						else ();
					);
					
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


		let outDir = !outDir in
			let outFilename = if String.ends_with outDir "/" then outDir ^ expansionDefFilename else outDir in
				let (out, outLen) = IO.pos_out (IO.output_channel (open_out outFilename)) in
				(
					IO.write_i32 out !indexEntiesNum;
					IO.nwrite out (IO.close_out indexBuf);
					IO.nwrite out (IO.close_out filesBuf);

					printf "done, out file location: %s; size %d\n" outFilename (outLen ());

					IO.close_out out;
				);
	)
	else
		printf "error: input should be directory";

parse arg (fun args -> if args <> "" then inDir.val := args else ())  "Lightning android expansions maker";
buildExpansion ();