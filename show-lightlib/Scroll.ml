type directionLock = [= `LockNone | `LockVertical | `LockHorizontal ];
value backSlideTime = 0.5;
value slideTime = 0.2;

value ev_SCROLL_BEGIN = Ev.gen_id "scrollBegin";
value ev_SCROLL_END = Ev.gen_id "scrollEnd";
module Scale =
  struct
    value scale = ref 1.;
    value fscale f = f;
  end;

class c ?(substrate=True) ?(sensitivity = 25.) ?(afterSlideFactor=3.0) ?_direction ?borderLeft ?borderTop ?borderRight ?borderBottom ?scrollbackLeft ?scrollbackRight ?scrollbackTop ?scrollbackBottom ?_content:(_content:option DisplayObject.c) maskW maskH = 
  object(self)  
  inherit DisplayObject.container as super;

  value mutable scrollbackLeft = match scrollbackLeft with [ Some v -> v | _ -> 0. ];
  value mutable scrollbackRight = match scrollbackRight with [ Some v -> v | _ -> 0. ];
  value mutable scrollbackTop = match scrollbackTop with [ Some v -> v | _ -> 0. ];
  value mutable scrollbackBottom = match scrollbackBottom with [ Some v -> v | _ -> 0. ];
  value mutable _sensitivity = sensitivity;

  method setColor _ = ();
  method color = (`Color 0);
  method setFilters fltz = ();
  method setCacheAsImage cache = ();
  method filters = [];
  method cacheAsImage = False;

  value mutable selfX = 0.;
  value mutable diffX = 0.;
  value mutable selfY = 0.;
  value mutable diffY = 0.;
    
  value mutable c_width = 0.;
  value mutable c_height = 0.;
  value mutable startTimeStamp = 0.;

  value mutable prevX = 0.;
  value mutable prevY = 0.;
  value mutable direction:directionLock = match _direction with [ Some a -> a | _ -> `LockNone ];

  value mutable sY = 0.;
  value mutable timestampY = 0.;

  value mutable ySlideTween = None;
  value mutable twStageAfterY = None;
  value mutable twStageAfterX = None;
  value mutable saveYhalf = False;
  value mutable timestampYhalf = 0.;
  value mutable sYhalf = 0.;
  
  value mutable sX = 0.;
  value mutable timestampX = 0.;

  value mutable xSlideTween = None;
  value mutable saveXhalf = False;
  value mutable timestampXhalf = 0.;
  value mutable sXhalf = 0.;

  value mutable maskW = maskW;
  value mutable maskH = maskH;

  method maskW = maskW;
  method maskH = maskH;

  method setMaskW mw = maskW := mw;
  method setMaskH mh = maskH := mh;

  method setDirectionLock lock = direction := lock;
  value mutable quad = Quad.create 100. 100.;

  value mutable contentContainer : option Sprite.c = None;
  method contentContainer = OPTGET contentContainer;

  value mutable content = None;
  
  method content = content;

  value mutable lock = False;
  method lock () = lock := True;
  method unlock () = lock := False;
  method locked = lock;

  method setContentContainerPos x y =
    let contentContainer = OPTGET contentContainer in
    (
      debug:pos "setContentContainerPos: %f %f" x y;
      debug:pos "left : %f; right : %f; wifth : %f; maskW : %f" scrollbackLeft scrollbackRight contentContainer#width maskW;
      contentContainer#setX (max (maskW -. contentContainer#width +. scrollbackRight) (min ~-.scrollbackLeft x));
      debug:pos "result x : %f" contentContainer#x;
      debug:pos "top : %f; bottom : %f; height : %f; maskH : %f" scrollbackTop scrollbackBottom contentContainer#height maskH;
      contentContainer#setY (max (maskH -. contentContainer#height +. scrollbackBottom) (min ~-.scrollbackTop y));
      debug:pos "result Y : %f" contentContainer#y;
    );

  method setContentContainerX x = (OPTGET contentContainer)#setX x;

  method setContentContainerY y = (OPTGET contentContainer)#setY y;

(*   method setContentContainerX x = self#setContentContainerPos x (OPTGET contentContainer)#y; *)

(*   method setContentContainerY y = self#setContentContainerPos (OPTGET contentContainer)#x y; *)

  method setContent c =
    let contentContainer = OPTGET contentContainer in
    (
      match content with
      [ Some c -> contentContainer#removeChild c
      | _ -> ()
      ];

      contentContainer#addChild c;
      content := Some c;
    );

  method resize ?(resetPos = True) () =
    (* let contentContainer = OPTGET contentContainer in *)
    (
      c_width := 0.;
      c_height := 0.;

      match content with
      [ Some _content ->
        let (w, h) =
          (_content#width, _content#height)
        in
        (
          debug "some content %f %f" w h;

          match borderLeft with [ Some left when left > 0. -> ( if resetPos then _content#setX left else (); c_width := c_width +. left ) | _ -> () ];
          match borderTop with [ Some top when top > 0. -> ( if resetPos then _content#setY top else (); c_height := c_height +. top ) | _ -> () ];
          match borderRight with [ Some right when right > 0. -> ( c_width := c_width +. right ) | _ -> () ];
          match borderBottom with [ Some bottom when bottom > 0. -> ( c_height := c_height +. bottom -. _content#y ) | _ -> () ];

          c_width := c_width -. scrollbackLeft -. scrollbackRight;
          c_height := c_height -. scrollbackTop -. scrollbackBottom;

          c_width  := match w +. c_width  < maskW  with [ True -> maskW  | _ -> w  +. c_width  ];
          c_height := match h +. c_height < maskH with [ True -> maskH | _ -> h +. c_height ];      
        )
      | _ -> ()
      ];

      debug "cw, ch %f %f" c_width c_height;

      if resetPos then
      (
        quad#setX scrollbackLeft;
        quad#setY scrollbackTop;

        self#setContentContainerX ~-.scrollbackLeft;
        self#setContentContainerY ~-.scrollbackTop;
      )
      else ();

      quad#setWidth c_width; 
      quad#setHeight c_height;

      debug "qw qh %f %f" quad#width quad#height;
    (*  debug "w h %f %f" contentContainer#width contentContainer#height;
     *) debug "w h %f %f" self#width self#height;

      self#setMask ~onSelf:True (Rectangle.create 0.0 0.0 maskW maskH);
    );

  method private createContentContainer () = Sprite.create ();

  initializer
    let (cc:Sprite.c) = self#createContentContainer () in
    (
      debug:slide "scroll id %d" (Oo.id self);

      contentContainer := Some cc;

      self#addChild cc;

      c_width := 0.;
      c_height := 0.;

			if substrate then cc#addChild quad else ();
      quad#setAlpha 0.;

      match _content with [ Some c -> cc#addChild c | _ -> () ];
      content := _content;    

      self#resize();

      ignore( self#addEventListener Stage.ev_TOUCH self#touchEvent) ;
    );

  (* value mutable scrollCb : option (unit -> unit) = None; *)
  value mutable scrollEvDispatched = False;
  (* value mutable afterScrollCb : option (unit -> unit) = None; *)

(*   method setScrollCallback cb = scrollCb := Some cb;
  method setAfterScrollCallback cb = afterScrollCb := Some cb; *)

  method private saveTouchInitParams touch =
    let contentContainer = OPTGET contentContainer in
    (
      selfX := contentContainer#x;
      diffX := touch.Touch.globalX -. selfX;
      selfY := contentContainer#y;
      diffY := touch.Touch.globalY -. selfY;
      prevX := 0.;
      prevY := 0.;

      sY := touch.Touch.globalY;
      timestampY := touch.Touch.timestamp;
      match ySlideTween with [ Some tween -> ( debug:zoom "remove slide y tween"; ySlideTween := None; Stage.removeTween tween; ) | _ -> () ];

      sX := touch.Touch.globalX;
      timestampX := touch.Touch.timestamp;
      match xSlideTween with [ Some tween -> ( debug:zoom "remove slide x tween"; xSlideTween := None; Stage.removeTween tween; ) | _ -> () ];    
    );

  value mutable redsptchChld = None;
  value mutable redsptchNow = False;

  method private redispatch htpX htpY event =
    match redsptchChld with
    [ Some child ->
      (
        debug:zoom "redispatching event, child id %d" (Oo.id child);
        redsptchNow := True;

(*         match Stage.touches_of_data event.Ev.data with
        [ Some [ touch ] when touch.Touch.phase = Touch.TouchPhaseBegan -> ()
        | _ -> child#dispatchEvent event
        ]; *)

        child#dispatchEvent event;
        (* child#dispatchEvent {(event) with Ev.bubbles = False}; *)
        redsptchNow := False;
      )
    | None -> ()
    ];

  method! hitTestPoint localPoint isTouch =
  (    
    redsptchChld := super#hitTestPoint localPoint isTouch;
    if redsptchChld = None then None else Some (self :> DisplayObject.c);
  );

  method private cancelTouches touches =
    List.map (fun touch -> Touch.({(touch) with phase = TouchPhaseCancelled})) touches;

  value mutable moved = False;
  value mutable scrollInProgress = False;
  value mutable startX = 0.;
  value mutable startY = 0.;

  method private touchEvent event _ _ =
    let contentContainer = OPTGET contentContainer in
    let () = debug:zoom "scroll touchEvent call, redispatch now %B, lock %B" redsptchNow lock in
    if not redsptchNow then
      match Stage.touches_of_data event.Ev.data with
      [ Some ([ touch :: _ ] as touches) ->
        let () = debug:zoom "touch phase: %s" Touch.(string_of_touchPhase touch.phase) in
        match touch.Touch.phase with
        [   Touch.TouchPhaseBegan ->
            (
              Touch.(self#redispatch touch.globalX touch.globalY event);
              startX := touch.Touch.globalX;
              startY := touch.Touch.globalY;
              moved := False;
              self#saveTouchInitParams touch;
              scrollInProgress := False;
            )
        |   Touch.TouchPhaseMoved ->
          let () = debug:xyu "lock %B" lock in
            if lock then
              Touch.(self#redispatch touch.globalX touch.globalY event)
            else
            (
              debug:sticky "scrollInProgress %B" scrollInProgress;
                if not scrollInProgress then
                (
                  self#dispatchEvent (Ev.create ev_SCROLL_BEGIN ());
                  scrollInProgress := True;                  
                ) else ();

                startTimeStamp := touch.Touch.timestamp;
                if (direction = `LockNone ||  direction = `LockVertical) then 
                (
                  if ( contentContainer#x > ~-.scrollbackLeft ) then 
                    self#setContentContainerX (~-.scrollbackLeft +. (touch.Touch.globalX -. diffX +. scrollbackLeft) /. afterSlideFactor) 
                  else
                    if ( touch.Touch.globalX -. diffX +. contentContainer#width -. scrollbackRight < maskW ) then 
                      let x = contentContainer#width -. maskW -. scrollbackRight in
                        self#setContentContainerX (~-.x +. ( touch.Touch.globalX -. diffX +. x) /. afterSlideFactor )
                    else
                      self#setContentContainerX (touch.Touch.globalX -. diffX); 

                  prevX := touch.Touch.globalX -. touch.Touch.previousGlobalX ;

                  if (touch.Touch.timestamp -. timestampX > 0.075 && saveXhalf = False) then
                  (
                    sXhalf := touch.Touch.globalX;
                    timestampXhalf := touch.Touch.timestamp;
                    saveXhalf := True;
                  ) else ();

                  if ( ( touch.Touch.globalX -. sX) *. prevX < 0.   )  then (* изменилось направление *)
                  (
                    sX := touch.Touch.globalX;
                    timestampX := touch.Touch.timestamp;
                    saveXhalf := False;
                  ) else (
                     if (touch.Touch.timestamp -. timestampX > 0.15) then
                     (
                        sX := sXhalf;
                        timestampX := timestampXhalf;
                        saveXhalf := False;
                     ) else ();
                  );
                  

                )
                else ( prevX := 0. );

                if (direction = `LockNone || direction = `LockHorizontal) then 
                (
                  if ( contentContainer#y > ~-.scrollbackTop ) then 
                    self#setContentContainerY (~-.scrollbackTop +. (touch.Touch.globalY -. diffY +. scrollbackTop) /. afterSlideFactor ) 
                    else 
                      if ( touch.Touch.globalY -. diffY +. contentContainer#height -. scrollbackBottom < maskH ) then
                        let y = contentContainer#height -. maskH -. scrollbackBottom in
                          self#setContentContainerY (~-.y +. ( touch.Touch.globalY -. diffY +. y) /. afterSlideFactor )
                      else
                        self#setContentContainerY (touch.Touch.globalY -. diffY); 

                  prevY := touch.Touch.globalY -. touch.Touch.previousGlobalY ;

                  if (touch.Touch.timestamp -. timestampY > 0.075 && saveYhalf = False) then
                  (
                    sYhalf := touch.Touch.globalY;
                    timestampYhalf := touch.Touch.timestamp;
                    saveYhalf := True;
                  ) else ();

                  if ( ( touch.Touch.globalY -. sY) *. prevY < 0.   )  then
                  (
                    sY := touch.Touch.globalY;
                    timestampY := touch.Touch.timestamp;
                    saveYhalf := False;
                  ) else (
                     if (touch.Touch.timestamp -. timestampY > 0.15) then
                     (
                        sY := sYhalf;
                        timestampY := timestampYhalf;
                        saveYhalf := False;
                     ) else ();
                  );
                  

                )
                else ( prevY := 0. );

                if not moved then
                (
                  (* moved := prevX *. prevX +.  prevY *. prevY > (Scale.fscale 25.0) *. (Scale.fscale 25.0) *. 2.0 ;   *)
                  debug:xyu "%f %f" Scale.scale.val _sensitivity;
                  debug:xyu "%f, %f, %B" (prevX *. prevX +.  prevY *. prevY) ((Scale.fscale _sensitivity) *. (Scale.fscale _sensitivity) *. 2.0) (prevX *. prevX +.  prevY *. prevY > (Scale.fscale _sensitivity) *. (Scale.fscale _sensitivity) *. 2.0);
(*                   moved := prevX *. prevX +.  prevY *. prevY > (Scale.fscale _sensitivity) *. (Scale.fscale _sensitivity) *. 2.0; *)
                  moved := (startX -. touch.Touch.globalX) *. (startX -. touch.Touch.globalX) +. (startY -. touch.Touch.globalY) *. (startY -. touch.Touch.globalY)  > (Scale.fscale _sensitivity) *. (Scale.fscale _sensitivity) *. 2.0;
                  debug:zoom "moved : %B; scrollInProgress : %B" moved scrollInProgress;
                  if moved  then
                      let () = debug:xyu "redispatch canceled touches" in
                        Touch.(self#redispatch touch.globalX touch.globalY { (event) with Ev.data = Stage.data_of_touches (self#cancelTouches touches) })
                  else ();
                )
                else ();
            )
        | _ -> self#touchEndHandler event touch
        ]
      | _ -> ()
      ]
    else ();
      
  method private touchEndHandler ev touch =
    let () = debug:zoom "moved: %B" moved in
    let diffX = 
        match direction with
        [ `LockNone | `LockVertical -> touch.Touch.globalX -. startX 
        | _ -> 0.
        ]
    and diffY =
        match direction with
        [ `LockNone | `LockHorizontal -> touch.Touch.globalY -. startY
        | _ -> 0.
        ]
    in
      (
        debug:xyu "touchEndHandler moved: %B" moved;
        if moved then
          (
            debug:zoom "SLIDE TOUCH";
            self#slideTouch touch;
          )
        else
          (
            debug:zoom "REDISPATCH";
            match (diffX *. diffX +.  diffY *. diffY > (Scale.fscale 25.0) *. (Scale.fscale 25.0) *. 2.) with
            [ True -> 
                (
                  debug:zoom "Not dispatch";
                  Touch.(self#redispatch touch.globalX touch.globalY { (ev) with Ev.data = Stage.data_of_touches (self#cancelTouches (OPTGET (Stage.touches_of_data ev.Ev.data))) });
                  self#dispatchScrollEnd ();
                )
            | _ -> 
              (
                debug:zoom "Dispatch";
                Touch.(self#redispatch touch.globalX touch.globalY ev);
								self#dispatchScrollEnd ();
              )
            ]
          )
      );

  method private cleanTween tween =
    match tween with
    [ Some tw -> Stage.removeTween tw
    | _ -> ()
    ];

  method private dispatchScrollEnd () =
	let () = debug:sticky "scrollInProgress %b" scrollInProgress in
    let () = debug:sticky "twStageAfterY %s" (match twStageAfterY with [ Some _ -> "some" | _ -> "none" ]) in
    let () = debug:sticky "twStageAfterX %s" (match twStageAfterX with [ Some _ -> "some" | _ -> "none" ]) in
    let () = debug:sticky "ySlideTween %s" (match ySlideTween with [ Some _ -> "some" | _ -> "none" ]) in
    let () = debug:sticky "xSlideTween %s" (match xSlideTween with [ Some _ -> "some" | _ -> "none" ]) in
    if scrollInProgress && twStageAfterY = None && twStageAfterX = None && ySlideTween = None && xSlideTween = None then
    (
      scrollInProgress := False;
      self#dispatchEvent (Ev.create ev_SCROLL_END ());
    )
    else ();

  method private afterSlideY () =
    let contentContainer = OPTGET contentContainer in
    (
        if (contentContainer#y > ~-.scrollbackTop) then 
        (
           let tween = Tween.create ~transition:`easeOut backSlideTime
           in
             (
               Stage.addTween tween;
               (* self#setTouchable False; *)
               debug:zoom "create after slide y tween to %f" ~-.scrollbackTop;
               tween#animate ((fun () ->  contentContainer#y), self#setContentContainerY) ~-.scrollbackTop;
               tween#setOnComplete (fun () -> ( debug:zoom "remove after slide y tween"; twStageAfterY := None; self#setTouchable True; Stage.removeTween tween; self#dispatchScrollEnd (); ));
               debug:zoom "twStageAfterY: %s" (match twStageAfterY with [ Some _ -> "some" | _ -> "none"]);
               self#cleanTween twStageAfterY;
               twStageAfterY := Some tween;
             )
        )
        else ();
        if (contentContainer#y +. contentContainer#height -. scrollbackBottom < maskH ) then 
        (
					debug:scroll "AFTER SLIDE Y %f %f %f %f " contentContainer#y contentContainer#height scrollbackBottom maskH ;
           let tween = Tween.create ~transition:`easeOut backSlideTime
           in
             (
               (* self#setTouchable False; *)
               debug:zoom "create after slide y tween to %f" (maskH -. contentContainer#height +. scrollbackBottom);
               Stage.addTween tween;
               tween#animate ((fun () ->  contentContainer#y), self#setContentContainerY) (maskH -. contentContainer#height +. scrollbackBottom);
               tween#setOnComplete (fun () -> ( debug:zoom "remove after slide y tween"; twStageAfterY := None; self#setTouchable True; Stage.removeTween tween; self#dispatchScrollEnd (); ));
               debug:zoom "twStageAfterY: %s" (match twStageAfterY with [ Some _ -> "some" | _ -> "none"]);
               self#cleanTween twStageAfterY;
               twStageAfterY := Some tween;
             );
        )
        else ();
    );

  method private afterSlideX () =
    let contentContainer = OPTGET contentContainer in
    ( 
        if (contentContainer#x > ~-.scrollbackLeft) then 
        (
           let tween = Tween.create ~transition:`easeOut backSlideTime
           in
             (
               Stage.addTween tween;
               (* self#setTouchable False; *)
               debug:zoom "create after slide x tween to %f" ~-.scrollbackLeft;
               tween#animate ((fun () ->  contentContainer#x), self#setContentContainerX) ~-.scrollbackLeft;
               tween#setOnComplete (fun () -> ( debug:zoom "remove after slide x tween"; twStageAfterX := None; self#setTouchable True; Stage.removeTween tween; debug:sticky "slideTouch 4";  self#dispatchScrollEnd (); ));
               debug:zoom "twStageAfterX: %s" (match twStageAfterX with [ Some _ -> "some" | _ -> "none"]);
               self#cleanTween twStageAfterX;
               twStageAfterX := Some tween;
             )
        )
        else ();
        if (contentContainer#x +. contentContainer#width -. scrollbackRight < maskW ) then 
        (
           let tween = Tween.create ~transition:`easeOut backSlideTime
           in
             (
               (* self#setTouchable False; *)
               Stage.addTween tween;
               debug:zoom "create after slide x tween to %f" (maskW -. contentContainer#width +. scrollbackRight);
               tween#animate ((fun () ->  contentContainer#x), self#setContentContainerX) (maskW -. contentContainer#width +. scrollbackRight);
               tween#setOnComplete (fun () -> ( debug:zoom "remove after slide x tween"; twStageAfterX := None; self#setTouchable True; Stage.removeTween tween; debug:sticky "slideTouch 5"; self#dispatchScrollEnd (); ));
               debug:zoom "twStageAfterX: %s" (match twStageAfterX with [ Some _ -> "some" | _ -> "none"]);
               self#cleanTween twStageAfterX;
               twStageAfterX := Some tween;
             );
        )
        else ();
    );

	method private slideTouch touch =
		let contentContainer = OPTGET contentContainer in
		match direction with
		[ `LockHorizontal ->  
			let diffTime = max (touch.Touch.timestamp -. timestampY) 0.05 in      
			let vy = (sY -. touch.Touch.globalY)  /. diffTime /. 2. in
			let vy =
				match abs_float vy > snd (Stage.screenSize ()) with
				[ True -> (snd (Stage.screenSize())) *. vy /. abs_float vy
				| _ -> vy
				]
			in
			match (abs_float vy > (snd (Stage.screenSize ())) /. 40. ) with
			[ True ->
				let (t, ry)  = 
					match (contentContainer#y -. vy > 0.) || (contentContainer#y -. vy +. contentContainer#height < maskH) with 
					[ True -> (0.2, contentContainer#y -. vy /. 30.) 
					| False -> (1., contentContainer#y -. vy)
					] 
				in
				let tween = Tween.create ~transition:`easeOut t in
				(
					(* self#setTouchable False; *)
					Stage.addTween tween;
					debug:zoom "create slide y tween to %f" (max (maskH -. contentContainer#height +. scrollbackBottom) (min ry ~-.scrollbackTop));
					tween#animate ((fun () ->  contentContainer#y), self#setContentContainerY) (max (maskH -. contentContainer#height +. scrollbackBottom) (min ry ~-.scrollbackTop));
					tween#setOnComplete (fun () ->
						(
							debug:zoom "remove slide y tween";
							ySlideTween := None;
							self#afterSlideY ();
							self#setTouchable True;
							Stage.removeTween tween;
							debug:sticky "slideTouch 0";
							self#dispatchScrollEnd ()
						)
					);
					debug:zoom "ySlideTween: %s" (match ySlideTween with [ Some _ -> "some" | _ -> "none"]);
					self#cleanTween ySlideTween;
					ySlideTween := Some tween
				)
			| _ ->
				(
					self#afterSlideY ();
					debug:sticky "slideTouch 1";
					self#dispatchScrollEnd ()
				)
			]
		| `LockVertical ->
			let diffTime = max (touch.Touch.timestamp -. timestampX) 0.05 in
			let vx = (sX -. touch.Touch.globalX)  /. diffTime /. 2. in
			let vx =
				match abs_float vx > fst (Stage.screenSize()) with
				[ True -> (fst (Stage.screenSize ())) *.vx /. abs_float vx
				| _ -> vx ]
			in
			match abs_float vx > (fst (Stage.screenSize ())) /. 40. with
			[ True ->
				let (t, rx)  = 
					match (contentContainer#x -. vx > 0.) || (contentContainer#x -. vx +. contentContainer#width < maskW) with 
					[ True -> (0.2 , (contentContainer#x -. vx /. 30.))
					| False -> (1., contentContainer#x -. vx)
					] 
				in
				let tween = Tween.create ~transition:`easeOut t in
				(
					(* self#setTouchable False; *)
					Stage.addTween tween;
					debug:zoom "create slide x tween to %f" (max (maskW -. contentContainer#width +. scrollbackRight) (min rx ~-.scrollbackLeft));
					tween#animate ((fun () ->  contentContainer#x), self#setContentContainerX) (max (maskW -. contentContainer#width +. scrollbackRight) (min rx ~-.scrollbackLeft));
					tween#setOnComplete (fun () ->
						(
							debug:zoom "remove slide x tween";
							xSlideTween := None;
							self#afterSlideX ();
							self#setTouchable True;
							Stage.removeTween tween;
							debug:sticky "slideTouch 2";
							self#dispatchScrollEnd ()
						)
					);
					debug:zoom "xSlideTween: %s" (match xSlideTween with [ Some _ -> "some" | _ -> "none"]);
					self#cleanTween xSlideTween;
					xSlideTween := Some tween
				)
			| _ ->
				(
					self#afterSlideX ();
					debug:sticky "slideTouch 3";
					self#dispatchScrollEnd ()
				) 
			]
		| `LockNone ->
			(* TODO - make it easy *)
			let diffTimeX = max (touch.Touch.timestamp -. timestampX) 0.05 in
			let vx = (sX -. touch.Touch.globalX) /. diffTimeX /. 2. in
			let vx =
				match abs_float vx > fst (Stage.screenSize()) with
				[ True -> (fst (Stage.screenSize ())) *.vx /. abs_float vx
				| _ -> vx
				]
			in
			let diffTimeY = max (touch.Touch.timestamp -. timestampY) 0.05 in
			let vy = (sY -. touch.Touch.globalY) /. diffTimeY /. 2. in
			let vy =
				match abs_float vy > snd (Stage.screenSize ()) with
				[ True -> (snd (Stage.screenSize ())) *. vy /. abs_float vy
				| _ -> vy
				]
			in
			let cond1 = abs_float vx > (fst (Stage.screenSize ())) /. 40. 
			and cond2 = abs_float vy > (snd (Stage.screenSize ())) /. 40. in
			let (t1, rx)  = 
				if cond1 then 
					match (contentContainer#x -. vx > 0.) || (contentContainer#x -. vx +. contentContainer#width < maskW) with 
					[ True -> (0.2 , (contentContainer#x -. vx /. 30.))
					| False -> (1., contentContainer#x -. vx)
					]
				else (0., 0.)
			in
			let (t2, ry)  = 
				if cond2 then
					match (contentContainer#y -. vy > 0.) || (contentContainer#y -. vy +. contentContainer#height < maskH) with 
					[ True -> (0.2, contentContainer#y -. vy /. 30.) 
					| False -> (1., contentContainer#y -. vy)
					]
				else (0., 0.)
			in
			if cond1 || cond2 then
				let t =
					match (cond1, cond2) with
					[ (True, True) -> min t1 t2
					| (True, False) -> t1
					| _ -> t2
					]
				in
				let tween = Tween.create ~transition:`easeOut t in
				(
					(* self#setTouchable False; *)
					Stage.addTween tween;
					if cond1 then
						tween#animate ((fun () ->  contentContainer#x), self#setContentContainerX) (max (maskW -. contentContainer#width +. scrollbackRight) (min rx ~-.scrollbackLeft))
					else ();
					if cond2 then
						tween#animate ((fun () ->  contentContainer#y), self#setContentContainerY) (max (maskH -. contentContainer#height +. scrollbackBottom) (min ry ~-.scrollbackTop))
					else ();
					tween#setOnComplete (fun () ->
						(
							debug:zoom "remove slide x tween";
							xSlideTween := None;
							ySlideTween := None;
							self#afterSlideX ();
							self#afterSlideY ();
							self#setTouchable True;
							Stage.removeTween tween;
							debug:sticky "slideTouch 2";
							self#dispatchScrollEnd ()
						)
					);
					self#cleanTween xSlideTween;
					self#cleanTween ySlideTween;

					xSlideTween := Some tween
				)
			else 
			(
				self#afterSlideX ();
				self#afterSlideY ();
				debug:sticky "slideTouch 3";
				self#dispatchScrollEnd ()
			)
		];

  end;


value create = new c;
