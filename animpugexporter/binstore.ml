module Chunk =
  struct
    type t =
      {
        len: int;
        buf: string;
      };

    value read inp =
      let len = IO.read_i32 inp in
      let buf = IO.nread inp len in
        { len; buf };

    value input t = IO.input_string t.buf;
  end;

type t = array Chunk.t;

value read fname =
  let chan = open_in fname in
  let inp = IO.input_channel chan in
  let retval = Array.init (IO.read_i32 inp) (fun _ -> Chunk.read inp) in
    (
      close_in chan;
      retval;
    );

value openChunk t i = Chunk.input t.(i);