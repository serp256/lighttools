open List;

type mut_list 'a =  {
  hd: 'a;
  tl: mutable list 'a
};

external inj : mut_list 'a -> list 'a = "%identity";
value dummy_node () = { hd = Obj.magic (); tl = [] };

value rec find_map_raise f = fun
	[ [] -> raise Not_found
	| [ x :: xs ] ->
		match f x with
		[ Some y -> y
		| None -> find_map_raise f xs
		]
	];

value rec find_map f = fun
  [ [] -> None
  | [ x :: xs ] ->
      match f x with
      [ Some y as res -> res
      | None -> find_map f xs
      ]
  ];

value remove_exn l x =
  let rec loop dst = fun
    [ [] -> raise Not_found
    | [ h :: t ] ->
      if x = h
      then dst.tl := t
      else
        let r = { hd = h; tl = [] } in
        (
          dst.tl := inj r;
          loop r t
        )
    ]
  in
  let dummy = dummy_node () in
  (
    loop dummy l;
    dummy.tl
  );


value map2_1 f l1 l2 =
	let rec loop dst src1 src2 =
		match (src1, src2) with
    [ ([], []) -> ()
    | ( [ h1 :: t1 ] , [ h2 :: t2 ] ) ->
      let r = { hd = f h1 h2; tl = [] } in
      (
        dst.tl := inj r;
        loop r t1 t2
      )
    | _ -> ()
    ]
	in
	let dummy = dummy_node () in
  (
    loop dummy l1 l2;
    dummy.tl
  );


value remove_if_exn f l =
  let rec loop dst = fun
    [ [] -> raise Not_found
    | [ h :: t ] ->
      if f h
      then dst.tl := t
      else
        let r = { hd = h; tl = [] } in
        (
          dst.tl := inj r;
          loop r t
        )
    ]
  in
  let dummy = dummy_node () in
  (
    loop dummy l;
    dummy.tl
  );


value remove_assoc_exn x lst = 
  let rec loop dst = fun
    [ [] -> raise Not_found
    | [ ((a,_) as pair) :: t ] ->
      if a = x
      then dst.tl := t
      else
        let r = { hd = pair; tl = [] } in
        (
          dst.tl := inj r;
          loop r t
        )
    ]
  in
  let dummy = dummy_node () in
  (
    loop dummy lst;
    dummy.tl;
  );

value pop_assoc x lst =
  let rec loop dst = fun
    [ [] -> raise Not_found
    | [ ((a,v) as pair) :: t ] ->
      if a = x
      then
      (
        dst.tl := t;
        v
      )
      else
        let r = { hd = pair; tl = [] } in
        (
          dst.tl := inj r;
          loop r t
        )
    ]
  in
  let dummy = dummy_node () in
  (
    let v = loop dummy lst in
    (v,dummy.tl);
  );


value pop_if f lst =
  let rec loop dst = fun
    [ [] -> raise Not_found
    | [ v :: t ] ->
      if f v
      then
      (
        dst.tl := t;
        v
      )
      else
        let r = { hd = v; tl = [] } in
        (
          dst.tl := inj r;
          loop r t
        )
    ]
  in
  let dummy = dummy_node () in
  (
    let v = loop dummy lst in
    (v,dummy.tl);
  );


value replace_assoc k v lst =
  let r = { hd = (k,v); tl = [] } in
  let rec loop dst = fun
    [ [] -> dst.tl := inj r
    | [ (k',_) :: tl ] when k' = k ->
      (
        r.tl := tl;
        dst.tl := inj r;
      )
    | [ h :: tl ] ->
      let r = { hd = h; tl = [] } in
      (
        dst.tl := inj r;
        loop r tl
      )
    ]
  in
  let dummy = dummy_node () in
  (
    loop dummy lst;
    dummy.tl;
  );


value add_assoc k v lst = 
  let rec loop dst = fun
    [ [] -> dst.tl := inj { hd = (k,[v]); tl = [] }
    | [ (k',vls) :: tl ] when k' = k ->
        let r = { hd = (k, [ v :: vls] ); tl = tl } in
        dst.tl := inj r
    | [ h :: tl ] ->
      let r = { hd = h; tl = [] } in
      (
        dst.tl := inj r;
        loop r tl
      )
    ]
  in
  let dummy = dummy_node () in
  (
    loop dummy lst;
    dummy.tl;
  );

value apply_assoc f key lst = 
  let rec loop = fun
    [ [] -> ()
    | [ (k,vl) :: tl ] when k = key -> f vl
    | [ _ :: tl ] -> loop tl
    ]
  in
  loop lst;



value update_assoc k f lst = 
  let rec loop dst = fun
    [ [] -> dst.tl := inj {hd = (k,f None); tl = []}
    | [ (k',v) :: tl ] when k' = k ->
        let r = { hd = (k,f (Some v)); tl = tl} in
        dst.tl := inj r
    | [ h :: tl ] ->
        let r = {hd = h; tl = [] } in
        (
          dst.tl := inj r;
          loop r tl;
        )
    ]
  in
  let dummy = dummy_node () in
  (
    loop dummy lst;
    dummy.tl
  );



(* requires HSet 

(* возвращает элементы первого списка, которых нет во вотором *)
value diff l1 l2 = 
  if l1 = [] || l2 = [] 
  then l1
  else
    let hs = HSet.create (List.length l2) in
    (
      iter (fun el -> HSet.add hs el) l2;
      fold_left (fun res el -> try HSet.remove_exn hs el; res with [ Not_found -> [ el :: res ]]) [] l1
    );

value _union minlen l1 l2 = 
  let hs = HSet.create minlen in
  (
    iter (fun el -> HSet.add hs el) l1;
    fold_left (fun res el -> try HSet.remove_exn hs el; [ el :: res ] with [ Not_found -> res]) [] l2
  );

value union l1 l2 = 
  if l1 = [] || l2 = [] 
  then []
  else
    let l1len = List.length l1
    and l2len = List.length l2
    in
    match l1len < l2len with
    [ True -> _union l1len l1 l2
    | False -> _union l2len l2 l1
    ];

*)

value full_uniq_diff l1 l2 =
  let l2 = ref l2 in
  let res =
    fold_left (fun r e ->
      try
        l2.val := remove_exn !l2 e;
        r
      with [ Not_found -> [ e :: r] ]
    ) [] l1
  in
  (!l2,res);

value split3 lst =
	let rec loop adst bdst cdst = fun
		[ [] -> ()
    | [ (a, b, c) :: t ] ->
			let x = { hd = a; tl = [] }
			and y = { hd = b; tl = [] }
      and z = { hd = c; tl = [] } in
      (
        adst.tl := inj x;
        bdst.tl := inj y;
        cdst.tl := inj z;
        loop x y z t
      )
    ]
	in
	let adummy = dummy_node ()
	and bdummy = dummy_node ()
  and cdummy = dummy_node ()
	in
  (
    loop adummy bdummy cdummy lst;
    (adummy.tl, bdummy.tl, cdummy.tl)
  );

(* возвращает номер элемента в списке удовлетворяющего условию *)
value index_of_func (f:('a -> bool)) (lst:list 'a) =  
  let rec loop i = fun
    [ [] -> None
    | [hd::_] when (f hd) -> Some i
    | [_::tl] -> loop (i+1) tl
    ]
  in loop 0 lst;
  
value index_of (lst:list 'a) (elem:'a) =
  let rec loop i = fun
    [ [] -> None
    | [hd :: _] when hd = elem -> Some i
    | [_ :: tl] -> loop (i + 1) tl
    ]
  in loop 0 lst;


(* combine drop_while and take_while
 * span f l = (take_while f l,drop_while f l)
 *)

(*
value span_nth n l =
  match l with
  [ [] -> ([],[])
  | l -> 
      loop l [] where
        rec loop l lt = 
          match l with
          [ [ h :: tl ] -> 
            match f h with
            [ True -> loop tl [ h :: lt]
            | False -> (rev lt,l)
            ]
          | [] -> (rev lt,l)
          ]
  ];
*)

value span f l = 
  match l with
  [ [] -> ([],[])
  | l -> 
      loop l [] where
        rec loop l lt = 
          match l with
          [ [ h :: tl ] -> 
            match f h with
            [ True -> loop tl [ h :: lt]
            | False -> (rev lt,l)
            ]
          | [] -> (rev lt,l)
          ]
  ];

value nsplit cnt lst = 
  loop 0 [[]] lst 
    where rec loop i res = fun
      [ [] -> res
      | [ hd :: tl ] ->
          let (i,res) = 
            if i < cnt 
            then (i+1,[ [ hd :: List.hd res ] :: List.tl res ])
            else (1,[ [ hd ] :: res ])
          in
          loop i res tl
      ];




(* requires HSet
value has_dublicates lst = 
  let hset = HSet.create (List.length lst) in
  exists (fun el -> if HSet.mem hset el then True else (HSet.add hset el; False)) lst;
*)
