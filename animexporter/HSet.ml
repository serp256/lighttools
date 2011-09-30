external hash_param : int -> int -> 'a -> int = "caml_hash_univ_param" "noalloc";
value hash x = hash_param 10 100 x;
type bucketlist 'a = [ Empty | Cons of 'a and bucketlist 'a ] 
and t 'a =
  { size : mutable int; (* number of elements *)
    data : mutable array (bucketlist 'a)
  };

value create initial_size =
  let s = min (max 1 initial_size) Sys.max_array_length
  in { size = 0; data = Array.make s Empty; };

value empty () = {size = 0; data = Array.make 1 Empty };

value clear h =
(
  for i = 0 to (Array.length h.data) - 1 do h.data.(i) := Empty done;
  h.size := 0
);

value copy h = { size = h.size; data = Array.copy h.data; };
value length h = h.size;
value is_empty h = h.size = 0;

value resize hashfun tbl =
  let odata = tbl.data in
  let osize = Array.length odata in
  let nsize = min ((2 * osize) + 1) Sys.max_array_length
  in
    if nsize <> osize
    then
      let ndata = Array.create nsize Empty in
      let rec insert_bucket = fun
        [ Empty -> ()
        | Cons data rest ->
          (
            insert_bucket rest;(* preserve original order of elements *)
            let nidx = (hashfun data) mod nsize;
            Array.unsafe_set ndata nidx (Cons data ndata.(nidx))
          ) 
        ]

      in
      (
        for i = 0 to osize - 1 do 
          insert_bucket (Array.unsafe_get odata i) 
        done;
        tbl.data := ndata
      )
    else ();

value add h data =
  let i = (hash data) mod (Array.length h.data) in
  let rec mem_in_bucket = fun
    [ Empty -> False
    | Cons d rest -> (d = data) || (mem_in_bucket rest) 
    ]
  in
  let b = Array.unsafe_get h.data i in
  if b = Empty || not (mem_in_bucket b)
  then
    let bucket = Cons data b in
    (
      Array.unsafe_set h.data i bucket;
      h.size := succ h.size;
      if h.size > ((Array.length h.data) lsl 1) then resize hash h else ()
    )
  else ();

value singleton v = { size = 1; data = [| Cons v Empty |] };

value remove h data =
  let rec remove_bucket = fun
    [ Empty -> Empty
    | Cons d next ->
        if d = data
        then (h.size := pred h.size; next)
        else Cons d (remove_bucket next) 
    ] 
  in
  let i = (hash data) mod (Array.length h.data) in 
  Array.unsafe_set h.data i (remove_bucket (Array.unsafe_get h.data i));



value remove_exn h data = 
  let rec remove_bucket = fun
    [ Empty -> raise Not_found
    | Cons d next ->
        if d = data
        then (h.size := pred h.size; next)
        else Cons d (remove_bucket next) 
    ] 
  in
  let i = (hash data) mod (Array.length h.data) in 
  Array.unsafe_set h.data i (remove_bucket (Array.unsafe_get h.data i));

value mem h data =
  match Array.unsafe_get h.data ((hash data) mod (Array.length h.data)) with
  [ Empty -> False
  | Cons d rest -> 
    let rec mem_in_bucket = fun
      [ Empty -> False
      | Cons d rest -> (d = data) || (mem_in_bucket rest) 
      ]
    in
    (d = data) || (mem_in_bucket rest)
  ];

exception Is_empty;
value any h =
  let d = h.data in
  let len = Array.length d in
  let rec find i =
    if i < len
    then
      match Array.unsafe_get d i with
      [ Empty -> find (i+1)
      | Cons d _ -> d
      ]
    else 
      raise Is_empty
  in
  find 0
  ;

value random_h h rand =
  let d = h.data in
  let len = Array.length d in
  let size = h.size in
  if size  = 0 
  then raise Is_empty
  else 
    let rand = (int_of_float ((float_of_int rand) /. (float_of_int size) *. (float_of_int len))) in
    let diff = 
      if rand < (len / 2) 
      then 1
      else (-1)
    in
    let rec find i =
      match Array.unsafe_get d i with
      [ Empty ->
          let new_i = i + diff in
          let new_i =
            if new_i >= len 
            then 0
            else 
              if new_i < 0 
              then len - 1
              else new_i 
          in
          find new_i
      | Cons d _ -> d
      ]
    in
    find rand;

value iter f h =
  let rec do_bucket = fun 
    [ Empty -> () 
    | Cons d rest -> (f d; do_bucket rest) 
    ] 
  in
  let d = h.data in 
  for i = 0 to (Array.length d) - 1 do 
    do_bucket d.(i) 
  done;

value print print_data h =
  let rec do_bucket = fun 
    [ Empty -> () 
    | Cons d rest -> (print_data d; do_bucket rest) 
    ] 
  in
  let d = h.data in 
  let () = Printf.printf "Length hash = %d \n%!" (Array.length d) in
  for i = 0 to (Array.length d) - 1 do 
    Printf.printf "%s: %!" (match d.(i) with [ Empty -> "Empty" | Cons _ _ -> "Cons "]) ;
    do_bucket d.(i);
    Printf.printf "\n%!";
  done;
  

value fold f h init =
  let rec do_bucket b accu =
    match b with
    [ Empty -> accu
    | Cons d rest -> do_bucket rest (f d accu) ] in
  let d = h.data in
  let accu = ref init
  in
  (
    for i = 0 to (Array.length d) - 1 do
      accu.val := do_bucket d.(i) accu.val
    done;
    accu.val
  );

value to_list t = fold (fun e l -> [ e :: l ] ) t [];
value of_list lst = 
  let s = create (List.length lst) in
  (
    List.iter (fun v -> add s v) lst;
    s;
  );


(*
value enum h = (*{{{*)
  let rec make ipos ibuck idata icount =
    let pos = ref ipos in
    let buck = ref ibuck in
    let hdata = ref idata in
    let hcount = ref icount in
    let force() =
      (** this is a hack in order to keep an O(1) enum constructor **)
      if !hcount = -1 then begin
        hcount.val := h.size;
        hdata.val := Array.copy h.data;
      end
      else ()
    in
    let rec next() =
    (
      force();
      match !buck with
      [ Empty ->					
          if !hcount = 0 
          then raise BatEnum.No_more_elements
          else
          (
            incr pos;
            buck.val := Array.unsafe_get !hdata !pos;
            next()
          )
        | Cons (v,next_buck) ->
          (
            buck.val := next_buck;
            decr hcount;
            v
          )
        ]
      )
    in
    let count() =
      if !hcount = -1 then h.size else !hcount
    in
    let clone() =
    (
      force();
      make !pos !buck !hdata !hcount
    )
    in
    BatEnum.make ~next ~count ~clone 
  in		
  make (-1) Empty (Obj.magic()) (-1); (*}}}*)
*)

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


module Make(H: Hashtbl.HashedType): (S with type key = H.t) = struct
  type key = H.t;
  type hset = t key;
  type t = hset;
  value hash = H.hash;

  value create = create;
  value empty = empty;
  value singleton = singleton;
  value any = any;
  value is_empty = is_empty;
  value add h data =
    let i = (hash data) mod (Array.length h.data) in
    let rec mem_in_bucket = fun
      [ Empty -> False
      | Cons d rest -> (H.equal d data) || (mem_in_bucket rest) 
      ]
    in
    let b = Array.unsafe_get h.data i in
    if b = Empty || not (mem_in_bucket b)
    then
      let bucket = Cons data b in
      (
        Array.unsafe_set h.data i bucket;
        h.size := succ h.size;
        if h.size > ((Array.length h.data) lsl 1) then resize hash h else ()
      )
    else ();

  value remove h data =
    let rec remove_bucket = fun
      [ Empty -> Empty
      | Cons d next ->
          if H.equal d data
          then (h.size := pred h.size; next)
          else Cons d (remove_bucket next) 
      ] 
    in
    let i = (hash data) mod (Array.length h.data) in 
    Array.unsafe_set h.data i (remove_bucket (Array.unsafe_get h.data i));
    
  value iter = iter;
  value fold = fold;

end;
