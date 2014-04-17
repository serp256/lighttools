value alphaThreshold = ref None;
value lineThreshold = ref None;
value inp = ref None;

Arg.parse
	[
  	("-at", Arg.Int (fun t -> alphaThreshold.val := Some t), "\talpha threshold (default is 0)");
  	("-lt", Arg.Float (fun t -> lineThreshold.val := Some t), "\tline threshold (default is 5)");
	] (fun fname -> inp.val := Some fname) "Simple contour viewer.\nUsage: cntrview [-at number] [-lt number] filename.";

match !inp with
[ Some inp ->
	match Images.load inp [] with
	[ Images.Rgba32 img ->
		let (w, h) = Rgba32.((img.width, img.height)) in
			(
			  Graphics.open_graph "";
			  Graphics.resize_window (w + 50) (h + 50);
			  Graphics.set_line_width 2;
			  Graphics.set_color Graphics.red;
        Graphics.clear_graph ();

        let imgToDraw = Rgb24.make w h { Color.Rgb.r = 0xff; g = 0xff; b = 0xff; } in
	        (
	          for i = 0 to w - 1 do
	            for j = 0 to h - 1 do
	              let c = Rgba32.get img i j in
	              	if c.Color.Rgba.alpha = 0
	              	then ()
	              	else Color.Rgba.(Color.Rgb.(Rgb24.set imgToDraw i j { r = c.color.r; g = c.color.g; b = c.color.b }))
	            done;
	          done;

	          Graphic_image.draw_image (Images.Rgb24 imgToDraw) 25 25;
	          Rgb24.destroy imgToDraw;
	        );

				let alphaThreshold = !alphaThreshold in
				let lineThreshold = !lineThreshold in
				let contour = Array.of_list (List.map (fun (x, y) -> (x + 25, h - y + 25)) (Contour.gen ?alphaThreshold ?lineThreshold img)) in
					(
						Printf.printf "contour generated, points number: %d\n%!" (Array.length contour);
						Graphics.draw_poly contour;
					);

	      ignore(Graphics.wait_next_event [Graphics.Key_pressed]);
      )
	| _ -> failwith "Something wrong with image: only 32-bit png images permited"
	]
| _ -> failwith "Specify image filename"
];