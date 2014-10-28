type t 'a;
exception Is_empty;

value length: t 'a -> int;
value empty: unit -> t 'a;
value create: int -> t 'a;
value singleton: 'a -> t 'a;

value copy: t 'a -> t 'a;
value is_empty: t 'a -> bool;
value clear: t 'a -> unit;
value add: t 'a -> 'a -> unit;
value remove: t 'a -> 'a -> unit;
value remove_exn: t 'a -> 'a -> unit;
value mem: t 'a -> 'a -> bool;
value any: t 'a -> 'a;
value random_h: t 'a -> int -> 'a;
value iter: ('a -> unit) -> t 'a -> unit;
value print: ('a -> unit) -> t 'a -> unit;
value fold: ('a -> 'b -> 'b) -> t 'a -> 'b -> 'b;
value to_list: t 'a -> list 'a;
value of_list: list 'a -> t 'a;
(* value enum: t 'a -> BatEnum.t 'a; *)


module type S = sig
  type key;
  type t;
  value create: int -> t;
  value empty: unit -> t;
  value singleton: key -> t;
  value is_empty: t -> bool;
  value any: t -> key;
  value add: t -> key -> unit;
  value remove: t -> key -> unit;
  value iter: (key -> unit) -> t -> unit;
  value fold: (key -> 'b -> 'b) -> t -> 'b -> 'b;
end;


module Make(H:Hashtbl.HashedType): S with type key = H.t;
