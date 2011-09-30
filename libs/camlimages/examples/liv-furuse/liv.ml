(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Jun Furuse, projet Cristal, INRIA Rocquencourt           *)
(*                                                                     *)
(*  Copyright 1999,2000,2001,2002,2001,2002                            *)
(*  Institut National de Recherche en Informatique et en Automatique.  *)
(*  Distributed only by permission.                                    *)
(*                                                                     *)
(***********************************************************************)
open Images
open OImages

(*
let _ =
  Bitmap.maximum_live := 15000000; (* 60MB *)
  Bitmap.maximum_block_size := !Bitmap.maximum_live / 16;
;;
*)

<<<<<<< liv.ml
open Gc
open Unix
open LargeFile
open Gdk
open GDraw
open GMain

open Livmisc
open Gui
open Display
open Tout

exception Skipped

let cwd = Unix.getcwd ()
let home = Sys.getenv "HOME"

let convert_file file = 
  let b = Buffer.create (String.length file) in

  let rec loop file =
    let dir = Filename.dirname file in
    let base = Filename.basename file in
    begin match dir with
    | "." -> Buffer.add_string b dir
    | "/" -> ()
    | _ -> loop dir
    end;
    Buffer.add_char b '/';
    Buffer.add_string b (try Glib.Convert.locale_to_utf8 base with _ -> base)
  in
  loop file;
  Buffer.contents b
;;

let base_filters = ref ([] : Display.filter list);;

let _ =
  let r = Gc.get () in r.max_overhead <- 0; Gc.set r;

  let files = ref [] in
  let random = ref false in
  let dirrandom = ref false in
  let dirsample = ref false in
  let size = ref false in

(*JPF*)  
  let mtimesort = ref false in
  let xmode = ref `n in
  let check = ref true in
  let gcheck = ref false in
(*/JPF*)  

  Random.init (Pervasives.truncate (Unix.time ()));
  Arg.parse 
    [
      "-random", Arg.Unit (fun () -> random := true), ": random mode";
      "-dirrandom", Arg.Unit (fun () -> dirrandom := true), ": random per directory mode";
      "-dirsample", Arg.Unit (fun () -> dirsample := true), ": random per directory sample mode";
      "-wait", Arg.Float (fun sec -> Tout.wait := sec), "sec : wait sec";
      "-root", Arg.String (function
	  "center" -> Display.root_mode := `CENTER
	| "random" -> Display.root_mode := `RANDOM
	| _ -> raise (Failure "root mode")), ": on root [center|random]";
      "-transition", Arg.String (function
	  "myst" -> Display.transition := `MYST
	| "transparent" -> Display.transition := `TRANSPARENT
	| _ -> raise (Failure "transition")), ": transition [myst|transparent]";
      "-transparentborder", Arg.Unit (fun () ->
	base_filters := `TRANSPARENT_BORDER :: !base_filters),
      ": transparent border filter";
      "-size", Arg.String (fun s ->
	match Mstring.split_str (function 'x' -> true | _ -> false) s with
	  [w;h] -> 
	    size := true; 
	    base_filters := `SIZE (int_of_string w, int_of_string h,`NOASPECT) :: !base_filters
  	| _ -> raise (Failure "size")), ": size [w]x[h]";
      "-atleast", Arg.String (fun s ->
	match Mstring.split_str (function 'x' -> true | _ -> false) s with
	  [w;h] -> 
	    size := true; 
	    base_filters := `SIZE (int_of_string w, int_of_string h,`ATLEAST) :: !base_filters
  	| _ -> raise (Failure "zoom")), ": zoom [w]x[h]";
      "-atmost", Arg.String (fun s ->
	match Mstring.split_str (function 'x' -> true | _ -> false) s with
	  [w;h] -> 
	    size := true; 
	    base_filters := `SIZE (int_of_string w, int_of_string h,`ATMOST) :: !base_filters
  	| _ -> raise (Failure "zoom")), ": zoom [w]x[h]";

      "-normalize", Arg.Unit (fun () ->
	base_filters := `NORMALIZE :: !base_filters), 
            ": normalize colormap";

      "-enhance", Arg.Unit (fun () ->
	base_filters := `ENHANCE :: !base_filters), 
            ": enhance colormap";

(*JPF*)	
     "-check", Arg.Unit (fun () -> check := true), ": check mode";
     "-Check", Arg.Unit (fun () -> check := true; gcheck := true), 
       ": ground check mode";
     "-x", Arg.Unit (fun () -> xmode := `x), ": x mode";
     "-X", Arg.Unit (fun () -> xmode := `X), ": X mode";
     "-_", Arg.Unit (fun () -> xmode := `u), ": -_ mode";
     "--_", Arg.Unit (fun () -> xmode := `u), ": -_ mode";
     "-mtime", Arg.Unit (fun () -> mtimesort := true), ": mtimesort mode";
(*/JPF*)
    ]  
    (fun s -> files := s :: !files)
    "liv files";
=======
module D = Display
open D

open Gc
open Unix
open LargeFile
open Gdk
open GDraw
open GMain

open Livmisc
open Gui
open Tout

exception Skipped

let cwd = Unix.getcwd ()
let home = Sys.getenv "HOME"

let convert_file file = 
  let b = Buffer.create (String.length file) in

  let rec loop file =
    let dir = Filename.dirname file in
    let base = Filename.basename file in
    begin match dir with
    | "." -> Buffer.add_string b dir
    | "/" -> ()
    | _ -> loop dir
    end;
    Buffer.add_char b '/';
    Buffer.add_string b (try Glib.Convert.locale_to_utf8 base with _ -> base)
  in
  loop file;
  Buffer.contents b
;;

let base_filters = ref ([] : D.filter list);;

let _ =
  let files = ref [] in
  let random = ref false in
  let dirrandom = ref false in
  let dirsample = ref false in
  let size = ref false in

(*JPF*)  
  let mtimesort = ref false in
  let xmode = ref `n in
  let check = ref true in
  let gcheck = ref false in
(*/JPF*)  

  Random.init (Pervasives.truncate (Unix.time ()));
  Arg.parse 
    [
      "-random", Arg.Unit (fun () -> random := true), ": random mode";
      "-dirrandom", Arg.Unit (fun () -> dirrandom := true), ": random per directory mode";
      "-dirsample", Arg.Unit (fun () -> dirsample := true), ": random per directory sample mode";
      "-wait", Arg.Float (fun sec -> Tout.wait := sec), "sec : wait sec";
      "-root", Arg.String (function
	  "center" -> D.root_mode := `CENTER
	| "random" -> D.root_mode := `RANDOM
	| _ -> raise (Failure "root mode")), ": on root [center|random]";
(*
      "-transition", Arg.String (function
	  "myst" -> D.transition := `MYST
	| "transparent" -> D.transition := `TRANSPARENT
	| _ -> raise (Failure "transition")), ": transition [myst|transparent]";
      "-transparentborder", Arg.Unit (fun () ->
	base_filters := `TRANSPARENT_BORDER :: !base_filters),
      ": transparent border filter";
*)
      "-size", Arg.String (fun s ->
	match Mstring.split_str (function 'x' -> true | _ -> false) s with
	  [w;h] -> 
	    size := true; 
	    base_filters := `SIZE (int_of_string w, int_of_string h,`NOASPECT) :: !base_filters
  	| _ -> raise (Failure "size")), ": size [w]x[h]";
      "-atleast", Arg.String (fun s ->
	match Mstring.split_str (function 'x' -> true | _ -> false) s with
	  [w;h] -> 
	    size := true; 
	    base_filters := `SIZE (int_of_string w, int_of_string h,`ATLEAST) :: !base_filters
  	| _ -> raise (Failure "zoom")), ": zoom [w]x[h]";
      "-atmost", Arg.String (fun s ->
	match Mstring.split_str (function 'x' -> true | _ -> false) s with
	  [w;h] -> 
	    size := true; 
	    base_filters := `SIZE (int_of_string w, int_of_string h,`ATMOST) :: !base_filters
  	| _ -> raise (Failure "zoom")), ": zoom [w]x[h]";

(*
      "-normalize", Arg.Unit (fun () ->
	base_filters := `NORMALIZE :: !base_filters), 
            ": normalize colormap";

      "-enhance", Arg.Unit (fun () ->
	base_filters := `ENHANCE :: !base_filters), 
            ": enhance colormap";
*)
(*JPF*)	
     "-check", Arg.Unit (fun () -> check := true), ": check mode";
     "-Check", Arg.Unit (fun () -> check := true; gcheck := true), 
       ": ground check mode";
     "-x", Arg.Unit (fun () -> xmode := `x), ": x mode";
     "-X", Arg.Unit (fun () -> xmode := `X), ": X mode";
     "-_", Arg.Unit (fun () -> xmode := `u), ": -_ mode";
     "--_", Arg.Unit (fun () -> xmode := `u), ": -_ mode";
     "-mtime", Arg.Unit (fun () -> mtimesort := true), ": mtimesort mode";
(*/JPF*)
    ]  
    (fun s -> files := s :: !files)
    "liv files";
>>>>>>> 1.10

  let files =
    let fs = ref [] in
    List.iter (fun f ->
      try
	let st = stat f in
	match st.st_kind with
	| S_DIR ->
	    Scandir.scan_dir (fun f -> 
	      try 
		ignore (guess_extension (snd (Livmisc.get_extension f)));
		fs := f :: !fs;
	      with e -> (* prerr_endline ((f^": "^ Printexc.to_string e)) *) ()) f
	| _ -> fs := f :: !fs
      with
      | _ -> prerr_endline ("ERROR: " ^ f)) !files;
    Array.of_list !fs 
  in

  if not !size then
    base_filters := `SIZE (fst root_size, snd root_size, `ATMOST) 
                         :: !base_filters;
  base_filters := List.rev !base_filters;
  
  let cur = ref (-1) in
  let curpath = ref "" in

  let disp_cur = ref (-1) in

  let random_array ary = 
    let num = Array.length ary in
    for i = 0 to num - 1 do
      let tmp = ary.(i) in
      let pos = Random.int num in
      ary.(i) <- ary.(pos);
      ary.(pos) <- tmp
    done
  in

  if !dirsample then begin
    let tbl = Hashtbl.create 17 in
    let dirs = ref [] in
    let num_files = Array.length files in
    for i = 0 to num_files - 1 do
      let dirname = Filename.dirname files.(i) in
      Hashtbl.add tbl dirname files.(i);
      if not (List.mem dirname !dirs) then dirs := dirname :: !dirs
    done;
    let dirsarray = Array.of_list !dirs in
    random_array dirsarray;
    let pos = ref 0 in
    let subpos = ref 0 in
    let subfiles = Array.init (Array.length dirsarray) (fun a ->
      let ary = Array.of_list (Hashtbl.find_all tbl dirsarray.(a)) in
      random_array ary; ary)
    in
    while !pos < Array.length files do
      for i = 0 to Array.length dirsarray - 1 do
	if !subpos < Array.length subfiles.(i) then begin
	  files.(!pos) <- subfiles.(i).(!subpos);
	  incr pos
	end
      done;
      incr subpos
    done 
  end else
  if !dirrandom then begin
    let tbl = Hashtbl.create 17 in
    let dirs = ref [] in
    let num_files = Array.length files in
    for i = 0 to num_files - 1 do
      let dirname = Filename.dirname files.(i) in
      Hashtbl.add tbl dirname files.(i);
      if not (List.mem dirname !dirs) then dirs := dirname :: !dirs
    done;
    let dirsarray = Array.of_list !dirs in
    random_array dirsarray;
    let pos = ref 0 in
    for i = 0 to Array.length dirsarray - 1 do
      let dirfiles = Array.of_list 
	  (List.sort compare (Hashtbl.find_all tbl dirsarray.(i))) in
      if !random then begin
	random_array dirfiles
      end;
      for j = 0 to Array.length dirfiles - 1 do
	files.(!pos) <- dirfiles.(j);
	incr pos
      done
    done
  end else if !random then random_array files;

(*JPF*)
  let files =
    if !mtimesort then begin
      let ctimes = 
        Array.map (fun f ->
    	  let st = lstat f in
    	  let t = st.st_mtime in
    	  f,(if !random then t +. Random.float (float (24*60*60)) else t)) files
      in
      Array.sort (fun (f1,t1) (f2,t2) ->
	let c = compare t1 t2 in
        if c = 0 then compare f1 f2 else c) ctimes;
      Array.map fst ctimes
    end else files
  in 
(*/JPF*)

  infowindow#show ();

  imglist#freeze ();
  Array.iter (fun file -> 
    ignore (imglist#append [convert_file file]))
    files;
  imglist#thaw ();

  let cache = Cache.create 5 in

  let rename pos newname =
    let oldname = files.(pos) in
    let xvname s = Filename.dirname s ^ "/.xvpics/" ^ Filename.basename s in
    let oldxvname = xvname oldname in
    let newxvname = xvname newname in
    let gthumbname s = 
      let abs = 
	if s = "" then "" else 
	if s.[0] = '/' then s
	else Filename.concat cwd s
      in
      (Filename.concat (Filename.concat home ".gnome2/gthumb/comments") abs)
	^ ".xml"
    in
    let oldgthumbname = gthumbname oldname in
    let newgthumbname = gthumbname newname in
    imglist#set_cell ~text: (convert_file newname) pos 0;
    let command s = Sys.command s in
    if Filename.dirname newname <> Filename.dirname oldname then begin
      ignore (command 
		(Printf.sprintf "mkdir -p %s" (Filename.dirname newname)));
    end;
    prerr_endline (Printf.sprintf "%s => %s" oldname newname); 
    ignore (command 
	      (Printf.sprintf "yes no | mv -i \"%s\" \"%s\"" oldname newname));
    if Sys.file_exists oldxvname then begin
      ignore (command 
		(Printf.sprintf "mkdir -p %s" (Filename.dirname newxvname)));
	ignore (command 
		  (Printf.sprintf "yes no | mv -i \"%s\" \"%s\"" oldxvname newxvname))
    end;
    if Sys.file_exists oldgthumbname then begin
      ignore (command 
		(Printf.sprintf "mkdir -p %s" (Filename.dirname newgthumbname)));
      ignore (command 
		(Printf.sprintf "yes no | mv -i \"%s\" \"%s\"" oldgthumbname newgthumbname))
    end;
    files.(pos) <- newname;
    Cache.rename cache oldname newname
  in

  let image_id = ref 0 in

  let display_image reload file =
    (* prerr_endline file; *)
    remove_timeout ();

    let load_image () =
      prog#map (); 
      prog#set_fraction 0.01; 
      prog#set_format_string ("loading...");
      let image = 
	try
  	  match tag (OImages.load file 
  		       [Load_Progress prog#set_fraction]) with
  	  | Rgb24 i -> i
	  | Rgba32 i -> i#to_rgb24
  	  | Index8 i -> i#to_rgb24
  	  | Index16 i -> i#to_rgb24
  	  | _ -> raise (Failure "not supported")
	with 
	| e -> prerr_endline (Printexc.to_string e); raise e
      in
      prog#set_fraction 1.0; sync ();
      image
    in

    let id, image =
      try
      	if not reload then begin
      	  Cache.find cache file
	end else raise Not_found
      with
	Not_found ->
	  let im = load_image () in
	  incr image_id;
	  !image_id, im
    in
    Cache.add cache file (id, image);
<<<<<<< liv.ml
    
    prog#set_fraction 0.01;
    display id image !base_filters;
=======
    
    prog#set_fraction 0.01;
    display id image !base_filters; (* this cause lots of gc *)
>>>>>>> 1.10

<<<<<<< liv.ml
    window#set_title (convert_file file);

=======
    window#set_title (convert_file file);
    
>>>>>>> 1.10
    disp_cur := !cur;
<<<<<<< liv.ml
    curpath := file;
(*JPF*)
    (* update mtime *)
    if !check then begin
      try
	let st = lstat file in
	if st.st_kind = S_LNK then begin
	  let lnk = Unix.readlink file in
	  Unix.unlink file;
	  Unix.symlink lnk file
	end else begin
	  Unix.utimes file (Unix.time ()) (Unix.time ());
	end
      with
	_ -> ()
    end;
    Gc.compact ()
(*/JPF*)
  in
=======
    curpath := file;
(*JPF*)
    (* update mtime *)
    if !check then begin
      try
	let st = lstat file in
	if st.st_kind = S_LNK then begin
	  let lnk = Unix.readlink file in
	  Unix.unlink file;
	  Unix.symlink lnk file
	end else begin
	  Unix.utimes file (Unix.time ()) (Unix.time ());
	end
      with
	_ -> ()
    end;
(*/JPF*)
  in
>>>>>>> 1.10

  let display_image reload file =
    try 
      display_image reload file 
    with Wrong_file_type | Wrong_image_type ->
      try
	prerr_endline "guess type";
	let typ =
	  let typ = Livshtype.guess file in
	  match typ with
	  | Livshtype.ContentType x ->
	      begin match
		Mstring.split_str (function '/' -> true | _ -> false) x
	      with
	      | [mj;mn] -> mj,mn
      	      | _ -> assert false
	      end
	  | Livshtype.ContentEncoding x ->
	      "encoding", x
	  | Livshtype.Special m ->
	      "special",m
	in
	prerr_endline (fst typ ^ "/" ^ snd typ);  
	match typ with
(*JPF*)
	| "application", "vnd.rn-realmedia"
	| "audio", "x-pn-realaudio" ->
	    disp_cur := !cur;
	    curpath := file;
	    ignore (Sys.command "killall -KILL mplayer");
	    ignore (Sys.command (Printf.sprintf "mplayer -framedrop \"%s\" &" file))
	| "video", _ ->
	    disp_cur := !cur;
	    curpath := file;	
	    ignore (Sys.command "killall -KILL mplayer");
	    ignore (Sys.command (Printf.sprintf "mplayer -framedrop '%s' &" file))
(*/JPF*)
	| _ -> raise Wrong_file_type
      with
      | _ -> ()
  in

  let filter_toggle opt = 
	if List.mem opt !base_filters then
	  base_filters :=
	     List.fold_right (fun x st ->
	       if x = opt then st
	       else x :: st) !base_filters []
	else
	  base_filters := !base_filters @ [opt]
  in

  let display_current reload =
    let f = 
      if !cur >= 0 && !cur < Array.length files then begin
<<<<<<< liv.ml
    	imglist#unselect_all ();
    	imglist#select !cur 0;
    	if imglist#row_is_visible !cur <> `FULL then begin
	  imglist#moveto ~row_align: 0.5 ~col_align: 0.0 !cur 0
    	end;
      	files.(!cur)
      end else !curpath
    in
(*JPF*)
    let xlevel, enhanced, checked = Jpf.get_flags f in
    if enhanced then filter_toggle `ENHANCE;

    let f = 
      if !gcheck && files.(!cur) = f then begin
	let xlevel, enhanced, checked = Jpf.get_flags files.(!cur) in
	let newname = Jpf.set_flags files.(!cur) (xlevel,enhanced,true) in
	if files.(!cur) <> newname then begin
	  rename !cur newname
	end;
	newname end else f
    in
(*/JPF*)

      display_image reload f;
(*JPF*)
    if enhanced then filter_toggle `ENHANCE;
(*/JPF*)

    ()
  in
=======
    	imglist#unselect_all ();
    	imglist#select !cur 0;
    	if imglist#row_is_visible !cur <> `FULL then begin
	  imglist#moveto ~row_align: 0.5 ~col_align: 0.0 !cur 0
    	end;
      	files.(!cur)
      end else !curpath
    in
(*JPF*)
    let xlevel, enhanced, checked = Jpf.get_flags f in
(*
    if enhanced then filter_toggle `ENHANCE;
*)

    let f = 
      if !gcheck && files.(!cur) = f then begin
	let xlevel, enhanced, checked = Jpf.get_flags files.(!cur) in
	let newname = Jpf.set_flags files.(!cur) (xlevel,enhanced,true) in
	if files.(!cur) <> newname then begin
	  rename !cur newname
	end;
	newname end else f
    in
(*/JPF*)

      display_image reload f;
(*JPF*)
(*
    if enhanced then filter_toggle `ENHANCE;
*)
(*/JPF*)
>>>>>>> 1.10

<<<<<<< liv.ml
(*JPF*)
  let check_skip mode =
    match mode with
    | Some `FORCE -> ()
    | Some `DIR ->
	let disp_file = files.(!disp_cur) in
	let cur_file = files.(!cur) in
	if Filename.dirname disp_file = Filename.dirname cur_file then
	  raise Skipped
    | None ->
        let xlevel, enhanced, checked = Jpf.get_flags files.(!cur) in
        if !gcheck && checked then raise Skipped;
        match !xmode with
        | `n -> ()
        | `u -> if xlevel < 0 then raise Skipped
        | `x ->
(*
    	let imgs = Array.length files in
*)
    	let perc = 
              if xlevel < 0 then 0 else  
    	  match xlevel with
    	    0 -> 25
    	  | 1 -> 50
    	  | 2 -> 75
    	  | _ -> 100
    	in
    	if Random.int 100 < perc then () else raise Skipped
        | `X ->
    	let perc = 
              if xlevel < 0 then 0 else  
    	  match xlevel with
    	    0 -> 0
    	  | _ -> 100
    	in
    	if Random.int 100 < perc then () else raise Skipped
  in
(*/JPF*)
=======
    ()
  in

(*JPF*)
  let check_skip mode =
    match mode with
    | Some `FORCE -> ()
    | Some `DIR ->
	let disp_file = files.(!disp_cur) in
	let cur_file = files.(!cur) in
	if Filename.dirname disp_file = Filename.dirname cur_file then
	  raise Skipped
    | None ->
        let xlevel, enhanced, checked = Jpf.get_flags files.(!cur) in
        if !gcheck && checked then raise Skipped;
        match !xmode with
        | `n -> ()
        | `u -> if xlevel < 0 then raise Skipped
        | `x ->
(*
    	let imgs = Array.length files in
*)
    	let perc = 
              if xlevel < 0 then 0 else  
    	  match xlevel with
    	    0 -> 25
    	  | 1 -> 50
    	  | 2 -> 75
    	  | _ -> 100
    	in
    	if Random.int 100 < perc then () else raise Skipped
        | `X ->
    	let perc = 
              if xlevel < 0 then 0 else  
    	  match xlevel with
    	    0 -> 0
    	  | _ -> 100
    	in
    	if Random.int 100 < perc then () else raise Skipped
  in
(*/JPF*)
>>>>>>> 1.10

  let rec next mode =
    if !cur >= 0 then begin
      let cur' = 
  	if !cur >= Array.length files - 1 then 0 else !cur + 1
      in
      if !cur = cur' then ()
      else begin
  	cur := cur';
  	try
(*JPF*)
	  check_skip mode;
(*/JPF*)
  	  display_current false;
      	with
      	| Sys_error s ->
  	    prerr_endline s;
  	    next mode
(*JPF*)
	| Skipped -> next mode
(*/JPF*)
        | Wrong_file_type | Wrong_image_type -> next mode
      end
    end
  in

  let rec prev mode =
    if !cur >= 0 then begin
      let cur' =
      	if !cur = 0 then Array.length files - 1 else !cur - 1
      in
      if !cur = cur' then ()
      else begin
      	cur := cur';
      	try
(*JPF*)
	  check_skip mode;
(*/JPF*)
  	  display_current false
      	with
      	| Sys_error s ->
  	    prerr_endline s;
  	    prev mode
      	| Skipped -> prev mode
      	| Wrong_file_type | Wrong_image_type -> prev mode
      end
    end
  in

  let bind () =
    let callback = fun ev ->
      begin match GdkEvent.Key.string ev with
(*
      | "E" -> 
	  filter_toggle `ENHANCE;
	  display_current true

*)
(*JPF*)
      | "E" -> 
	  let name = files.(!disp_cur) in
	  let xlevel,enhance,checked = Jpf.get_flags name in
          let enhance' = not enhance in
          let newname = Jpf.set_flags name (xlevel,enhance',checked) in
	  if name <> newname then begin
            rename !disp_cur newname
	  end;
	  display_current true
(*/JPF*)
(*
      | "N" -> 
	  filter_toggle `NORMALIZE;
	  display_current true
*)
	    
      |	"l" -> display_current true

      | " " | "n" | "f" -> next None
(*JPF*)
      | "\014" (* C-N *) | "\006" (* C-F *) -> next (Some `FORCE)
      | "N" | "F" -> next (Some `DIR)
(*/JPF*)
      | "p" | "b" -> prev None
(*JPF*)
      | "\016" (* C-P *) | "\002" (* C-B *) -> prev (Some `FORCE)
      | "P" | "B" -> prev (Some `DIR)
(*/JPF*)
      | "q" -> Main.quit ()
      | "v" -> 
	(* liv visual shell *)
  	  let rec func = fun file typ ->
	    match typ with
	    | "image", _ -> 
    	      	display_image false file
(*
            | "special", "dir" -> 
                new Livsh.livsh file func; ()
*)
	    | _ -> Gdk.X.beep ()
  	  in
	  (* where we should display ? *)
	  let dirname = 
	    if Array.length files = 0 then Unix.getcwd ()
	    else Filename.dirname files.(!cur) 
	  in
	  let dirname =
	    if Filename.is_relative dirname then begin
 	      let cwd = Unix.getcwd () in
	      Filename.concat cwd dirname
	    end else dirname
	  in
	  ignore (new Livsh.livsh dirname func)
(*JPF*)
      | "e" -> 
	  if !check then begin
	    let name = files.(!disp_cur) in
	    let xlevel,enhance,checked = Jpf.get_flags name in
            let xlevel' = -1 in
            let newname = Jpf.set_flags name (xlevel',enhance,checked) in
	    if name <> newname then begin
              rename !disp_cur newname
	    end;
	    next None
          end 
      | "x" -> 
	  if !check then begin
	    let name = files.(!disp_cur) in
	    let xlevel,enhance,checked = Jpf.get_flags name in
            let xlevel' = xlevel + 1 in
            let newname = Jpf.set_flags name (xlevel',enhance,checked) in
	    if name <> newname then begin
              rename !disp_cur newname
	    end;
	    next None
	  end
      | "r" -> 
	  if !check then begin
	    let name = files.(!disp_cur) in
	    let xlevel,enhance,checked = Jpf.get_flags name in
            let xlevel' = 
              if xlevel > 0 then xlevel - 1 
              else if xlevel < 0 then xlevel + 1
              else xlevel
            in
            let newname = Jpf.set_flags name (xlevel',enhance,checked) in
	    if name <> newname then begin
              rename !disp_cur newname
	    end;
	    next None
	  end
      | "s" -> 
	  if !check then begin
	    let name = files.(!disp_cur) in
	    let dir = Filename.dirname name in
            let base = Filename.basename name in
            let newname = 
              let trash =
                try string_tail dir 7 = "/series" with _ -> false 
              in
              if trash then
                Filename.concat 
                  (String.sub dir 0 (String.length dir - 7)) base 
              else Filename.concat (Filename.concat dir "series") base 
            in
	    if name <> newname then begin
              rename !disp_cur newname
	    end;
	    next None
	  end
      | "d" -> 
	  if !check then begin
	    let name = files.(!disp_cur) in
	    let dir = Filename.dirname name in
            let base = Filename.basename name in
            let newname = 
              let trash =
                try string_tail dir 6 = "/trash" with _ -> false 
              in
              if trash then
                Filename.concat 
                  (String.sub dir 0 (String.length dir - 6)) base 
              else Filename.concat (Filename.concat dir "trash") base 
            in
	    if name <> newname then begin
              rename !disp_cur newname
	    end;
	    next None
	  end
(*/JPF*)
      | _ -> () 
      end; false
    in
    ignore (window#event#connect#key_press ~callback: callback);
    ignore (infowindow#event#connect#key_press ~callback: callback);

    ignore (imglist#connect#select_row ~callback: (fun ~row ~column ~event ->
      if !cur <> row then begin
      	cur := row;
      	display_image false files.(!cur)
      end))
  in

  bind ();

  Tout.hook_next := next;

  window#show ();

  let starter = ref None in

<<<<<<< liv.ml
  starter := Some (window#event#connect#configure ~callback: (fun ev ->
    may window#misc#disconnect !starter;
    if Array.length files <> 0 then begin
      cur := 0;
      prog#unmap ();
      display_current false
    end else begin
      try
	display_image false (Pathfind.find [ "~/.liv"; 
					     "/usr/lib/liv"; 
					     "/usr/local/lib/liv";
					     "." ] "liv.jpg")
      with
      | _ -> ()
    end; false));
  
  Main.main ()
=======
  starter := Some (window#event#connect#configure ~callback: (fun ev ->
    may window#misc#disconnect !starter;
    if Array.length files <> 0 then begin
      cur := 0;
      prog#unmap ();
      display_current false
    end else begin
      try
	display_image false (Pathfind.find [ "~/.liv"; 
					     "/usr/lib/liv"; 
					     "/usr/local/lib/liv";
					     "." ] "liv.jpg")
      with
      | _ -> ()
    end; false));

(*
  let release _ = prerr_endline "freed string!" in
  let test () =
    let f () =
      let string = String.create 3000 in
      Gc.finalise release string;
      let buf = Gpointer.region_of_string string in
      ignore (GdkPixbuf.from_data ~width: 100 ~height: 10
		~bits: 8 ~rowstride:300 ~has_alpha: false buf);
      ()
    in
    for i = 0 to 100 do f () done
  in
  test ();
*)

  Main.main ()
>>>>>>> 1.10
