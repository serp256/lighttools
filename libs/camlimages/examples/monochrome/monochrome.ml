(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Jun Furuse, projet Cristal, INRIA Rocquencourt           *)
(*                                                                     *)
(*  Copyright 1999-2004,                                               *)
(*  Institut National de Recherche en Informatique et en Automatique.  *)
(*  Distributed only by permission.                                    *)
(*                                                                     *)
(***********************************************************************)

(* $Id: monochrome.ml,v 1.7 2009/02/08 15:25:37 weis Exp $ *)

open Images;;
open OImages;;
open Info;;

let files = ref [] in
Arg.parse [] (fun s -> files := s :: !files) "monochrome src dst";
let src, dst =
  match List.rev !files with
  | [src; dst] -> src, dst
  | _ -> invalid_arg "you need two arguments" in

let src = OImages.rgb24 (OImages.load src []) in

let mono img =
  (* Make monochrome *)
  for x = 0 to src#width - 1 do
    for y = 0 to src#height - 1 do
      let rgb = src#get x y in
      let mono = Color.brightness rgb in
      src#set x y { r = mono; g = mono; b = mono; }
    done
  done in

let saver img = img#save dst None [] in

mono src;
saver src
;;
