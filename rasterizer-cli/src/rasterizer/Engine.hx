package rasterizer;

import sys.FileSystem;
import sys.io.File;
import format.swf.instance.MovieClip;
import haxe.macro.Expr.Error;
import openfl.display.BitmapData;
import format.swf.instance.Bitmap;
import format.swf.tags.TagDefineSprite;
import format.swf.tags.TagSymbolClass;
import format.swf.SWFRoot;
import format.SWF;

import rasterizer.model.SWFClass;
import rasterizer.model.Pack;
import rasterizer.flatten.IFlatten;
import rasterizer.flatten.FlattenImage;
import rasterizer.flatten.FlattenMovieClip;
import rasterizer.flatten.FlattenSprite;
import rasterizer.export.IExporter;
import rasterizer.export.FlattenExporter;

import rasterizer.model.BuildCache;

import haxe.io.Path;


@:access(format.swf.instance.MovieClip)

class Engine {
    

    public var outputDir(default, null) : Path;

    public var inputDir(default, null)  : Path;        

    public var buildCache(default, null) : BuildCache;


    /*
     * Добавить опции растеризации
     */    
    public function new(inputDir : String, outputDir : String, cacheFile : String) {
        this.outputDir = new Path(outputDir);
        this.inputDir = new Path(inputDir);
        buildCache = new BuildCache(inputDir, cacheFile);
    }


    
    /*
     * 
     */
    public function exportPack(pack : Pack) {
        var opath = Path.join([ outputDir.toString(), pack.dir ]);
        
        // флаг, показывающий, что надо все файлы пака растеризовать заново
        var rebuildPack = false;

        if (FileSystem.exists(opath) && !FileSystem.isDirectory(opath)) {
            Main.exitWithError("Output path exists and it's not a directory");
        } 
        
        if (!FileSystem.exists(opath)) {
            rebuildPack = true;
            FileSystem.createDirectory(opath);
        } else {
            rebuildPack = buildCache.shouldRebuildPack(pack);
        }

        if (rebuildPack) {
            Main.clearDirectory(opath);
        }

        buildCache.updatePack(pack);

        for (file in pack.files) {                
            
            if (rebuildPack || buildCache.shouldRebuildFile(file, pack.name)) {
            
               var ipath = Path.join([ inputDir.toString(), file ]);
               var bytes = File.getBytes(ipath);
               var crc = haxe.crypto.Crc32.make(bytes);
               var swf = new SWFRoot(bytes);
               
               trace(file);
               
               for (className in swf.symbols.keys()) {    
                   var tagId = swf.symbols.get(className);
                   var opts = pack.symbolOptions(className);
                   if (opts == null) {
                       continue;
                   }
                   trace('Exporting symbol $className');
                   exportSymbol(swf, className, tagId, opts.animated, opts.scale, pack.preserveTagMasks, new haxe.io.Path(opath));
                }

                buildCache.updateFile(file, pack.name, crc);
                
            }                            
        }
    }



    /*
     *
     */
    public function exportSymbol(swf : SWFRoot, className : String, tagId : Int, animated : Bool, scale : Float, preserveTagMasks : Bool, dir : Path) : Void {
        var symbol = swf.getCharacter(tagId);        
        var cls = new SWFClass(swf, symbol, className, null);                
        var instance = cls.createInstance();
        var flatten : IFlatten;
        
        if (Std.is(instance, MovieClip)) {            
            var instance : MovieClip = cast instance;
            MovieClipExt.recStop(instance);
            if (instance.totalFrames == 1 || !animated) {
                flatten = new FlattenSprite();
                var flatten : FlattenSprite = cast flatten;
                flatten.swf = swf;
            } else {
                flatten = new FlattenMovieClip();
                var flatten : FlattenMovieClip = cast flatten;                
                flatten.preserveTagMasks = preserveTagMasks;
                flatten.swf = swf;                
            }
        } else {            
            flatten = new FlattenImage(Math.ceil(instance.width), Math.ceil(instance.height), true, 0x00000000);
        }
        
        flatten.fromDisplayObject(instance, scale,symbol);
        var exporter = new FlattenExporter();        
        exporter.setPath(dir).export(flatten, className);        
        flatten.dispose();                
    }

}


























