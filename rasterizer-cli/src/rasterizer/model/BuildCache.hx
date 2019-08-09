package rasterizer.model;

import sys.FileSystem;
import sys.io.File;
import haxe.DynamicAccess;

using Lambda;

/*
 * Чтобы не растеризовать все символы каждый раз, мы храним кеш в формате JSON
 * Есть два ключа:
 * files :
 * {
 *      "filename" : { crc : "sdfsdf", pack  : "packname" }
 * }
 * 
 * packs :
 * {
 *      "packname" : <настройки пака, как в основном конфиге>
 * }
 * 
 * Если что-то меняется в настройках пака, то перерастеризовываем весь пак,
 * елсли просто изменился файл или его нет, то растеризуем один файл.
 * 
 * 
 * 
 */
class BuildCache {

    /*
     * Каталог с swf файлами для растеризации
     */
    private var __indir : String; 


    /*
     * Был ли загружен кеш или нет
     */
    private var __loaded : Bool;

    /*
     *
     */
    private var __cacheFile : String;


    /*
     *
     */
    private var __data : DynamicAccess<DynamicAccess<Dynamic>>;

    
    /*
     * Кешируем контрольные суммы, чтобы лишний раз не пересчитывать
     */
    private var __crc : Map<String, Int>;


    /*
     * 
     */
    public function new(indir : String, cacheFile : String) {
        
        __indir = indir;
        __cacheFile = cacheFile;
        __loaded = false;
        __crc = new Map();
        
        var cacheFile = FileSystem.absolutePath(cacheFile);

        if (FileSystem.exists(cacheFile)) {
            
            if (FileSystem.isDirectory(cacheFile)) {
                throw new openfl.errors.Error("Cache file is not a file");
            }

            __data = haxe.Json.parse(File.getContent(__cacheFile));

            if (!__data.exists("files") || !__data.exists("packs")) {
                throw new openfl.errors.Error("Invalid cache file");
            }
            __loaded = true;
        
        } else {
            __data = {"files" : {}, "packs" : {} };

        }
    }


    /*
     *
     */
    public function shouldRebuildPack(pack : Pack) : Bool {
        // пока что не стал реализовывать
        return false;   

        // if (!__loaded) {
        //     return true;
        // }
        
        // var entry = __data["packs"][pack];
        // if (entry == null) {
        //     return true;
        // }


        

    }

    /*
     *
     */
    private function __stringArraysEqual(ar1 : Array<String>, ar2 : Array<String>) {
        if (ar1 == null && ar2 == null) {
            return true;            
        }

        if (ar1 == null || ar2 == null) {
            return false;
        }

        if (ar1.length != ar2.length) {
            return false;
        }

        for (i in 0...ar1.length) {
            if (ar1[i] != ar2[i]) {
                return false;
            }
        }

        return true;
    }


    /*
     * Нужно ли растеризовать файл.
     * Это нужно в следующих случаях
     * - файл ни разу не процессился (нет кеш-файла или нет записи в кеше)
     * - изменился сам файл
     * - файл переместился в другой пак
     */
    public function shouldRebuildFile(fname : String, packname : String) : Bool {
        
        if (!__loaded) {
            return true;
        }

        var entry : DynamicAccess<Dynamic> = __data["files"][fname];
        if (entry == null) {
            return true;
        }

        if (entry["pack"] != packname) {
            return true;
        }

        var crc = 0;
        if (__crc.exists(fname)) {
            crc = __crc[fname];
        } else {
            crc = haxe.crypto.Crc32.make(File.getBytes(fname));
            __crc[fname] = crc;
        }

        if (crc != entry["crc"]) {
            return true;
        }
        
        return false;
    }


    /*
     *
     */
    public function updatePack(pack : Pack) {
        __data["packs"][pack.name] = @:privateAccess pack.__data;
    }


    /*
     *
     */
    public function updateFile(fname : String , packname : String, crc : Int) {
        __data["files"][fname] = { "crc" : crc, "pack" : packname };
    }

    
    /*
     *
     */
    public function save() {
        var str = haxe.Json.stringify(__data, null, "    ");
        if (__loaded) {
            FileSystem.deleteFile(__cacheFile);
        }
        File.saveContent(__cacheFile, str);
    }

    


}











