exception No_entry;
type t = Hashtbl.t string int;

module Entry =
  struct
    type t = {
      offset:int;
      size:int;
    };

    value create offset size = { offset; size };
    value getOffset entry = entry.offset;
    value getSize entry = entry.size;
  end;

value ext = ".index";
value create () = Hashtbl.create 0;
value iter index func = Hashtbl.iter (fun fname entry -> func fname entry) index;
value fold index func init = Hashtbl.fold func index init;
value add index fname entry = (
  Hashtbl.replace index fname entry;
  index;
);
value get index fname = try Hashtbl.find index fname with [ Not_found -> raise No_entry ];