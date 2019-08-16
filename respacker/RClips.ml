
open RBase;


value make_clip_commands () = 
  for i = 0 to DynArray.length items - 1 do
    match DynArray.get items i with
    [ {item_id=id;item=`clip frames;_} when not (is_simple_clip frames) ->
      (
      
        let fframe = DynArray.get frames 0 in
        let pchildren = ref (DynArray.copy fframe.children) in
        for f = 1 to DynArray.length frames - 1 do
          let frame = DynArray.get frames f in
          let commands = DynArray.create () in
          let len = DynArray.length frame.children in 
          (
            for c = 0 to len - 1 do
              match DynArray.get frame.children c with
              [ `chld ((id,name,pos,mask) as child) ->
                try
                  let pidx = DynArray.index_of (fun [ `chld (id',_,pos,_) -> id' = id | _ -> assert False ]) !pchildren  in
                  match DynArray.get !pchildren pidx with
                  [ `chld (_,_,pos',_) ->
                    let changes = if pidx <> 0 then [ `move c ] else [] in
                    let changes = if pos.x <> pos'.x then [ `posX pos.x :: changes ] else changes in
                    let changes = if pos.y <> pos'.y then [ `posY pos.y :: changes ] else changes in
                    (
                      DynArray.delete !pchildren pidx;
                      match changes with
                      [ [] -> ()
                      | changes -> DynArray.add commands (ClpChange (pidx + c,changes)) 
                      ]
                    )
                  | _ -> assert False
                  ]
                with [   Not_found ->  DynArray.add commands (ClpPlace (c, (id, name, pos, mask) ))  ]
              | _ -> prerr_endline "boxes not supported in clips yeat"
              ]
            done;
            (* еще удалить надо *)
            let clen = DynArray.length !pchildren in
            if clen > 0 
            then
              DynArray.add commands (ClpClear len clen)
            else ();
            frame.commands := Some commands;
            pchildren.val := DynArray.copy frame.children;
          )
        done;
      )
    | _ -> ()
    ]
  done;
