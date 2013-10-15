class box ?(isVertical=True) width height =
  object(self)
    inherit Sprite.c as super;
    value mutable realW = 0.;
    value mutable realH = 0.; 
    value gap = 5.;
    value mutable maxH = 0.;

    method addElement (child: DisplayObject.c) = 
      (
        super#addChild child;
        if child#width +. realW <= width then
          (
            child#setPos realW realH;
            realW := realW +. child#width;
            maxH := match maxH > child#height with [True -> maxH | False -> child#height];
          )
        else
          (
            realW := 0.;
            realH := realH +. maxH;
            child#setPos realW realH;
            realW := realW +. child#width;
            maxH := child#height;
          );
      );
  end;

value draw indir (font, fontFamily, fontWeight, fontSize) suffix =
  let stage width height=
    object(self)
      inherit Stage.c width height as super;
      value bgColor = 0xcccccc;
      method frameRate = 30;
      value box = new box width height;
      initializer (
        LightCommon.set_resources_suffix suffix;
        BitmapFont.register (Printf.sprintf "fonts/%s.fnt" font);
        TLF.default_font_family.val := fontFamily;
        TLF.default_font_size.val := fontSize; 
        
        let lib = LightLib.load indir in 
        let symbols = LightLib.symbols lib in
        let l = ExtLib.List.of_enum symbols in
        let l = ExtLib.List.sort l in
        let symbols = ExtLib.List.enum l in

        (
          Enum.iter (fun cls ->
            (
              let element = new Sprite.c in
                let ((w,h), label) = TLF.create (TLF.p ~fontWeight ~color: 0xffffff ~halign: `center ~valign:`center [`text cls]) in
                let symbol = LightLib.get_symbol lib cls in
                let color = `Color 0x777777 in
                let quad = Quad.create (match symbol#width > w with [True -> symbol#width|False->w]) (symbol#height+.h) ~color in
                (
                  element#addChild quad;
                  element#addChild label;
                  element#addChild symbol;
                  symbol#setY h;
                  box#addElement (element#asDisplayObject);
                )
            )
          ) symbols;
        );
        let scroll = new Scroll.c ~_content: (box#asDisplayObject) width height in
        self#addChild scroll;
      );
    end
  in Lightning.init stage;


