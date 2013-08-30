open ExtList;

value (=|=) k v = (("",k),v);
value (=.=) k v = k =|= string_of_float v;
value (=*=) k v = k =|= string_of_int v;

value read_un_byte bininp =
(
  let k = IO.read_byte bininp 
  in
  if k land (1 lsl 7) = 0 
  then k 
  else (k mod (1 lsl 7)) * (1 lsl 8) + (IO.read_byte bininp);
);

value read_option_string bininp =
  let len = IO.read_byte bininp in
  match len with
  [ 0 -> None
  | _ -> Some (IO.nread bininp len)
  ];

value convert_child bininp xmlout = 
  let id = IO.read_ui16 bininp in
  let posx = IO.read_double bininp in
  let posy = IO.read_double bininp in
  let name = read_option_string bininp in
  let attrs = [ "id" =*= id; "posX" =.= posx; "posY" =.= posy ] in
  let attrs = match name with [ Some n -> [ "name" =|= n :: attrs ] | None -> attrs ] in
  (
    Xmlm.output xmlout (`El_start (("","child"),attrs));
    Xmlm.output xmlout `El_end
  );


let input_file = Sys.argv.(1) in
let inp = open_in input_file in
let out = open_out "out.xml" (*outdir // (Printf.sprintf "out.xml" suffix)*) in
(
  let bininp = IO.input_channel inp in
  let xmlout = Xmlm.make_output ~indent:(Some 2) (`Channel out) in
  let convert_child () = convert_child bininp xmlout in
  (
    Xmlm.output xmlout (`Dtd None);
    Xmlm.output xmlout (`El_start (("","lib"),[]));

    Xmlm.output xmlout (`El_start (("","textures"),[]));
    let n_textures = IO.read_ui16 bininp in
    for i = 1 to n_textures do
      let tname = IO.read_string bininp in
      Xmlm.output xmlout (`El_start (("","texture"),["file" =|= tname])); 
      Xmlm.output xmlout `El_end;
    done;
    Xmlm.output xmlout `El_end;

    Xmlm.output xmlout (`El_start (("","items"),[]));
    let n_items = IO.read_ui16 bininp in
    for i = 1 to n_items do
      let id = IO.read_ui16 bininp in
      let kind = IO.read_byte bininp in
      match kind with
      [ 0 -> (* image {{{*)
        (
          let page = IO.read_ui16 bininp in
          let x = IO.read_ui16 bininp in
          let y = IO.read_ui16 bininp in
          let width = IO.read_ui16 bininp in
          let height = IO.read_ui16 bininp in
          let attributes =
            [
              "type" =|= "image";
              "texture" =*= page;
              "x" =*= x;
              "y" =*= y;
              "width" =*= width;
              "height" =*= height
            ]
          in
          Xmlm.output xmlout (`El_start (("","item"),[ "id" =*= id :: attributes ]));
          Xmlm.output xmlout `El_end;
        )(*}}}*)
      | 1 -> (* sprite {{{*)
        (
          Xmlm.output xmlout (`El_start (("","item"),[ "id" =*= id ; "type" =|= "sprite" ]));
          let n_children = read_un_byte bininp in
          for j = 1 to n_children do
            match IO.read_byte bininp with
            [ 0 -> convert_child ()
            | 1 -> (* atlas *)
              (
                Xmlm.output xmlout (`El_start (("","atlas"),[]));
                let cnt = read_un_byte bininp in
                for k = 1 to cnt do convert_child (); done;
                Xmlm.output xmlout `El_end;
              )
            | 2 -> (* box *)
              (
                let posx = IO.read_double bininp in
                let posy = IO.read_double bininp in
                let name = IO.read_string bininp in
                Xmlm.output xmlout (`El_start (("","box"),[ "posX" =.= posx; "posY" =.= posy; "name" =|= name ]));
                Xmlm.output xmlout `El_end
              )
            | _ -> assert False
            ]
          done;
          Xmlm.output xmlout `El_end;
        )(*}}}*)
      | 2 -> (* image clip {{{*)
        (
          Xmlm.output xmlout (`El_start (("","item"),[ "id" =*= id ; "type" =|= "iclip" ]));
          let n_frames = IO.read_ui16 bininp in
          for j = 1 to n_frames  do
            let duration = IO.read_byte bininp in
            let label = read_option_string bininp in
            let imgid = IO.read_ui16 bininp in
            let x = IO.read_double bininp in
            let y = IO.read_double bininp in
            let attrs = [ "duration" =*= duration ] in 
            let attrs = match label with [ Some l -> [ "label" =|= l :: attrs ] | None -> attrs ] in
            let imgattrs = [ "img" =*= imgid; "posX" =.= x; "posY" =.= y ] in
            Xmlm.output xmlout (`El_start (("","frame"),attrs @ imgattrs));
            Xmlm.output xmlout `El_end;
          done;
          Xmlm.output xmlout `El_end;
        )(*}}}*)
      | 3 -> (* clip {{{*)
        (
          Xmlm.output xmlout (`El_start (("","item"),[ "id" =*= id ; "type" =|= "clip" ]));
          let n_frames = IO.read_ui16 bininp in
          for j = 1 to n_frames do
            let duration = IO.read_byte bininp in
            let label = read_option_string bininp in
            let attrs = [ "duration" =*= duration ] in 
            let attrs = match label with [ Some l -> [ "label" =|= l :: attrs ] | None -> attrs ] in
            Xmlm.output xmlout (`El_start (("","frame"),attrs));

            (* children {{{*)
            Xmlm.output xmlout (`El_start (("","children"),[]));
            let n_children = read_un_byte bininp in
            for k = 1 to n_children do
              let id = IO.read_ui16 bininp in
              let posx = IO.read_double bininp in
              let posy = IO.read_double bininp in
              let name = read_option_string bininp in
              let attrs = [ "id" =*= id; "posX" =.= posx; "posY" =.= posy ] in
              let attrs = match name with [ Some n -> [ "name" =|= n :: attrs ] | None -> attrs ] in
              Xmlm.output xmlout (`El_start (("","child"),attrs));
              Xmlm.output xmlout `El_end
            done;
            Xmlm.output xmlout `El_end; (*}}}*)
            (* commands {{{*)
            match IO.read_byte bininp with 
            [ 0 -> ()
            | n -> 
              (
                Xmlm.output xmlout (`El_start (("","commands"),[]));
                let n_commands = IO.read_ui16 bininp in
                for k = 1 to n_commands do
                  match IO.read_byte bininp with
                  [ 0 -> (* place {{{*)
                    (
                      let idx = IO.read_ui16 bininp in
                      let id = IO.read_ui16 bininp in
                      let name = read_option_string bininp in
                      let posx = IO.read_double bininp in
                      let posy = IO.read_double bininp in
                      let attrs = [ "idx" =*= idx; "id" =*= id; "posX" =.= posx; "posY" =.= posy ] in
                      let attrs = match name with [ Some n -> [ "name" =|= n :: attrs ] | None -> attrs ] in
                      Xmlm.output xmlout (`El_start (("","place"),attrs));
                      Xmlm.output xmlout `El_end;
                    )(*}}}*)
                  | 1 -> (* clear {{{*)
                    (
                      let from = IO.read_ui16 bininp in
                      let count = IO.read_ui16 bininp in
                      Xmlm.output xmlout (`El_start (("","clear-from"),[ "idx" =*= from; "count" =*= count ]));
                      Xmlm.output xmlout `El_end
                    )(*}}}*)
                  | 2 ->  (* change {{{*)
                    (
                      let idx = IO.read_ui16 bininp in
                      let n_changes = IO.read_byte bininp in
                      let changes = 
                        List.init n_changes begin fun _ ->
                          match IO.read_byte bininp with
                          [ 0 -> (* move *) "move" =*= (IO.read_ui16 bininp)
                          | 1 -> (* posx *) "posX" =.= (IO.read_double bininp)
                          | 2 -> (* posy *) "posY" =.= (IO.read_double bininp)
                          | _ -> failwith "unknown clip change command"
                          ]
                        end
                      in
                      Xmlm.output xmlout (`El_start (("","change"),["idx" =*= idx :: changes ]));
                      Xmlm.output xmlout `El_end;
                    )(*}}}*)
                  | _ -> assert False
                  ];
                done;
                Xmlm.output xmlout `El_end;
              )
            ];(*}}}*)

            Xmlm.output xmlout `El_end;
          done;
          Xmlm.output xmlout `El_end;
        )(*}}}*)
      | _ -> assert False
      ];
    done;
    Xmlm.output xmlout `El_end;

  (* write symbols {{{*)
    Xmlm.output xmlout (`El_start (("","symbols"),[])); 
    let n_symbols = IO.read_ui16 bininp in
    for i = 1 to n_symbols do
      let cls = IO.read_string bininp in
      let id = IO.read_ui16 bininp in
      Xmlm.output xmlout (`El_start (("","symbol"),[ "class" =|= cls; "id" =*= id ]));
      Xmlm.output xmlout `El_end;
    done;
    Xmlm.output xmlout `El_end;(*}}}*)


    Xmlm.output xmlout `El_end;

  );


  close_out out;
  close_in inp;
);
