open Images;

value zclr = {Color.color={Color.r=0;g=0;b=0}; alpha=0;};


value infinity_enum els = 
  let len = Array.length els in
  if len <= 0 then raise (Invalid_argument "els")
  else
    let idx = ref 0 in
    let rec from () = 
      if !idx < len
      then
        let res = els.(!idx) in
        (
          incr idx;
          res
        )
      else 
      (
        idx.val := 0;
        from ();
      )
    in
    Enum.from from;

value get_el en = match Enum.get en with [ None -> assert False | Some el -> el ];

value clr r g b = {Color.color={Color.r;g;b}; alpha=0xFF};

(* нужно сделать plx и plt *)
value () = 
  let fline = (fun () -> infinity_enum [| clr 0xFF 0x00 0x00 ; clr 0x00 0xFF 0x00 ; clr 0x00 0x00 0xFF |])
  and sline = (fun () -> infinity_enum [| clr 0 0 0; clr 0xFF 0xFF 0xFF; clr 0xCC 0xCC 0xCC |])
  and tline = (fun () -> infinity_enum [| clr 0xFF 0xFF 0x00; clr 0x00 0xFF 0xFF; clr 0xFF 0x00 0xFF |])
  in
  let lines = infinity_enum [| fline ; sline ; tline |] in
  let w = 256 and h = 256 in
  let plt = Rgba32.make w h zclr in
  let plxout = open_out_bin "test.plx" in
  let plx = IO.output_channel plxout in
  (
    IO.write_byte plx 0;
    IO.write_ui16 plx w;
    IO.write_ui16 plx h;
    for y = 0 to h - 1 do
      let line = (get_el lines) () in
      for x = 0 to w - 1 do
        let c = get_el line in
        Rgba32.set plt x y c;
        IO.write_byte plx x;
        IO.write_byte plx y;
      done;
    done;
    close_out plxout;
    Images.save "pallete.plt" (Some Png) [] (Rgba32 plt);
  );


