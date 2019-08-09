package rasterizer.model;

import haxe.DynamicAccess;
import rasterizer.model.StringFilter;

using StringTools;
using Lambda;

typedef SymbolOptions = 
{
    var scale : Float;
    var animated : Bool;
}


class Pack {

    public var files(get, null) : Array<String>;

    public var scale(default, null) : Float;

    public var animated(default, null) : Bool;

    public var packmode(default, null) : String;

    public var maxTextureSize(default, null) : Int;

    public var name(default, null) : String;

    public var nomerge(default, null) : Bool;

    public var dir(get, null) : String;
    
    private var __files : Array<String>;

    private var __data : DynamicAccess<Dynamic>;
    
    private var __symbolsFilters : Array<StringFilter>;

    private var __dir : String;
    





    /*
     * packdata - JSON-parsed data for pack
     */
    public function new(packname : String, packdata : DynamicAccess<Dynamic>, allfiles : Array<String>) {                
        this.name = packname;                        
        this.animated = getBool(packdata, "animated", true);        
        this.scale = getFloat(packdata, "scale", 1.0);

        if (packdata.exists("dir")) {
            __dir = packdata["dir"];
        }

        // Флаги для respacker
        packmode = packdata["pack-mode"];
        if (packmode != null && packmode != "sep" && packmode != "fsep" && packmode != "group") {
            throw new openfl.errors.Error("Pack mode must be sep, fsep or group (default)");
        } else if (packmode == null) {
            packmode = "group";
        }        
        
        maxTextureSize = getInt(packdata, "max-tx-size", 2048);                            
        nomerge = getBool(packdata, "no-merge", false);        
        // конец флагов для резпакера
        
        __data = packdata;
        __filterFiles(allfiles);
        __buildSymbolsFilters();     
    }


    /*
     *
     */
    private function get_dir() : String {
        if (__dir == null || __dir == "") {
            return name;
        }
        return __dir;
    }

    /*
     *
     */
    private inline function getBool(data : DynamicAccess<Dynamic>, name : String, dval : Bool) : Bool {
        if (!data.exists(name)) {
            return dval;            
        }

        var val = data.get(name);
        if (val == null) {
            return dval;
        }

        if (Std.is(val, Bool)) {
            return (val : Bool);
        }

        if (Std.is(val, String)) {
            return (val : String).toLowerCase() == "true";
        }

        return dval;
    }

    /*
     *
     */
    private inline function getFloat(data : DynamicAccess<Dynamic>, name : String, dval : Float) : Float {
        if (!data.exists(name)) {
            return dval;            
        }

        var val = data.get(name);
        if (val == null) {
            return dval;
        }

        if (Std.is(val, Float)) {
            return (val : Float);
        }

        if (Std.is(val, String)) {
            var v : Null<Float> = Std.parseFloat(val);
            return v == null ? dval : v;
        }

        return dval;
    }


    /*
     *
     */
    private inline function getInt(data : DynamicAccess<Dynamic>, name : String, dval : Int) : Int {
        if (!data.exists(name)) {
            return dval;            
        }

        var val = data.get(name);
        if (val == null) {
            return dval;
        }

        if (Std.is(val, Int)) {
            return (val : Int);
        }

        if (Std.is(val, String)) {
            var v : Null<Int> = Std.parseInt(val);
            return v == null ? dval : v;
        }

        return dval;
    }


    /*
     * Строит список используемых файлов и помещает его в __files
     */
    private function __filterFiles(files : Array<String>) {
        var filter = new StringFilter(__data.get("include"), __data.get("exclude"));
        #if (haxe_ver < "4.0.0")
        __files = files.filter(function (f) return filter.includes(f));
        #else
        __files = files.filter(f -> filter.includes(f));        
        #end
    }

    /*
     *
     */
    private function __buildSymbolsFilters() : Void {
        if (!__data.exists("symbols")) {
            return;
        }

        var symbols = __data.get("symbols");
        if (symbols == null || !Std.is(symbols, Array) || (symbols : Array<Dynamic>).length == 0) {
            throw new openfl.errors.Error("Symbols must be a non-zero-length array");
        }

        
        __symbolsFilters = [];
        for (entry in (symbols : Array<DynamicAccess<Dynamic>>)) {                    
            __symbolsFilters.push(new StringFilter(entry.get("include"), entry.get("exclude")));
        }

    }


    /* 
     *
     */
    public function symbolOptions(symbol : String) : SymbolOptions {
        
        if (__symbolsFilters == null) {
            return { animated : animated, scale : scale };
        }

        var symbols : Array<DynamicAccess<Dynamic>> = cast __data.get("symbols");
        var options = { animated : animated, scale : scale };
        for (i in 0...__symbolsFilters.length) {
            if (__symbolsFilters[i].includes(symbol)) {
                
                var anim = symbols[i]["animated"];
                if (anim != null) {
                    if (anim == "true") {
                        options.animated = true;
                    } else if (anim == "false") {
                        options.animated = false;
                    }
                }

                

                var scale = symbols[i]["scale"];
                if (scale != null) {
                    options.scale = Std.parseFloat(scale);
                }

                return options;
            }
        }

        // не использовать символ
        return null;
    }



    /*
     *
     */
    private function get_files() {
        return __files;
    }

}

