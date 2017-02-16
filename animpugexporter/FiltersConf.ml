open ExtLib;

type t = {
  scales: (list (string * float));
  filters:(list (string * string));
  shadows:(list string);
  cannons: (list string);
};

value get = fun
  [ None -> None
  | Some fname ->
      let json = Ojson.from_file fname in
      match json with
      [ `Assoc json -> 
          let cannons = 
            match List.assoc "cannons" json with
            [ `List l -> 
                List.map (fun json -> 
                  match json with
                  [ `String str | `Intlit str -> str
                  | _ -> assert False
                  ]
                ) l
            | _ -> assert False
            ]
          in
          let scales = 
            match List.assoc "scales" json with
            [ `Assoc l -> 
                List.map (fun (name, js) -> 
                  match js with
                  [ `Float f -> (name, f)
                  | `Int i -> (name, float i) 
                  | _ -> assert False
                  ]
                ) l
            | _ -> assert False
            ]
          in
          let shadows = 
            match List.assoc "shadows" json with
            [ `List l -> 
                List.map (fun json -> 
                  match json with
                  [ `String str | `Intlit str -> str
                  | _ -> assert False
                  ]
                ) l
            | _ -> assert False
            ]
          in
          let mobile_shadows = 
            match List.assoc "mobile_shadows" json with
            [ `List l -> 
                List.map (fun json -> 
                  match json with
                  [ `String str | `Intlit str -> str
                  | _ -> assert False
                  ]
                ) l
            | _ -> assert False
            ]
          in
          let shadows = shadows @ mobile_shadows in
          let filters = 
            match List.assoc "filters" json with
            [ `Assoc l -> 
                List.map (fun (name, js) -> 
                  match js with
                  [ `String str -> (name, str)
                  | _ -> assert False
                  ]
                ) l
            | _ -> assert False
            ]
          in
          let mobile_filters = 
            match List.assoc "mobile_filters" json with
            [ `Assoc l -> 
                List.map (fun (name, js) -> 
                  match js with
                  [ `String str -> (name, str)
                  | _ -> assert False
                  ]
                ) l
            | _ -> assert False
            ]
          in
          let filters = 
            List.fold_left (fun res (name, str) -> 
              match List.mem_assoc name res with
              [ False -> [ (name, str) :: res ]
              | _ -> res 
              ]
            ) mobile_filters filters
          in
          Some {scales; filters; shadows; cannons  }
      |  _ -> assert False
      ]
  ];
  
value opt f def = fun
  [ None -> def
  | Some c -> f c
  ];
  
value scales = opt (fun c -> c.scales) [];
value cannons = opt (fun c -> c.cannons) [];
value filters = opt (fun c -> c.filters) [];
value shadows = opt (fun c -> c.shadows) [];

value in_shadows conf fname = 
  List.exists (fun sh -> String.exists fname sh) (shadows conf);

value get_filter conf obj fname =  
  try
    let filter = List.assoc obj (filters conf) in
    match in_shadows conf fname with
    [ True ->  []
    | _ ->  [ filter ]
    ]
  with
  [ Not_found -> [] ];

value get_scale conf obj = 
  try
    let scale = List.assoc obj (scales conf) in
    scale
  with
  [ Not_found -> 1. ];

value test () = 
  (
    let sh = "sh" in
    let filname = "fjadgdsjghds.sh" in
      (
    Printf.printf "name sh %b\n%!" (String.exists filname sh);
    Printf.printf "sh name %b\n%!" (String.exists sh filname);
      );
      assert False;
  );


