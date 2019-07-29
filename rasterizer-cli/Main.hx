import haxe.Template;
import rasterizer.Engine;
import sys.io.File;
import format.SWF;
import tink.Cli;
import sys.FileSystem;
import haxe.io.Path;
import haxe.Json;
import haxe.DynamicAccess;
import rasterizer.model.Pack;

using Lambda;
using StringTools;

/*
 * rasterizer --input <input dir> --output  <output dir>  [--config config] <path-to-respacker>
 */

/*    

        Формат конфига

        "include" : [ "/^take_ra_/" ], // Влючить файлы, которые попадают под регулярку
        "exclude" : [ "take_ra_haha.swf"],    // Убрать из списка файл 
        "animated" : false,
        "scale" : 1.0
        "pack-mode" : "separate",
        "max-tx-size" : 2048,
        "no-merge" : true,

        // если нет sybols, то юзаем все символы, а если есть, то 
        // основываемся на этих данных. 
        // no-merge флаг относится к паку и не может быть переопределен для отдельного символа

        "symbols" : 
            [
                {
                    "include" : [sdsdsd],
                    "exclude" : [asdfasdfasdf],
                    "animated" : true,
                    "scale"   : 45.0
                }
            ]
*/

class Main {
    

    /*
     * Каталог с swf файлами
     */
    public var input:String;

    /*
     * Директория, где будет папка rasterized, packed и скрипт с упаковщиком
     */    
    public var output:String;


    /*
     * Имя конфига. По умолчанию берется файл rasterizer.json в input dir.
     * Можно задать абсолютный путь или путь, относительно CWD
     */
    @:flag("config")
    public var configFile:String;



    /*
     * Список всех файлов
     */
    private var __allFiles : Array<String>;


    /*
     * Список использованных файлов. 
     * Если из всех файлов вычесть использованные файлы, то останется список файлов, к которым надо применить default pack (если такой указан)
     */
    private var __usedFiles : Map<String, Int>;


    /*
     *
     */
    private var __config : DynamicAccess<Dynamic>; // распарсенный JSON конфиг


    /*
     *
     */
    private var __defaultSectionName : String = null;


    /*
     *
     */
    private var __engine : Engine = null;


    /*
     * Разделитель для директорий
     */
    private var __backslash : Bool = false;


    /*
     * Паки, которые мы запроцессили. Юзаем для срипта резпакера
     */
    private var __processedPacks : Array<Pack>;


    @:defaultCommand
    public function run(rest : Dynamic) {        
        
        __allFiles = [];
        __usedFiles = new Map();
        __processedPacks = [];

        __checkCLIArgs();
        __readConfigFile();
        __readAllFiles();

        __engine = new Engine(input, Path.join([ output, "rasterized", "default" ]));

        // процессим паки
        for (packname in __config.keys()) {
            packname = packname.trim();
            
            if (packname.toLowerCase() == "default") {
                __defaultSectionName = packname;
                continue;
            }

            __processPack(packname, __config[packname]);
        }


        // процессим дефолтный пак
        if (__defaultSectionName != null) {
            __processDefaultPack();
        }

        var template = new Template(haxe.Resource.getString("packerScriptTemplate"));
        
        var packs = [];        
        for (pack in __processedPacks) {
            var p = { "name" : pack.name, "max_tx_size" : pack.maxTextureSize, "mode" : pack.packmode, "merge" : "" };
            if (pack.nomerge) {
                Reflect.setField(p, "merge", "-no-merge");
            }
            packs.push({ "pack" : p });            
        }

        var contents = template.execute( {'PACKS' : packs, 'RESPACKER' : rest });
        File.saveContent(Path.join([ output, "packer.sh" ]), contents);
    }


    /*
     *
     */
    private function __processPack(packname : String, packdata : DynamicAccess<Dynamic>) {
        trace('Processing pack ${packname}');
        var pack = new Pack(packname, packdata, __allFiles);
        for (file in pack.files) {
            __usedFiles[file] = 1; // нужны, чтобы определить к каким файлам в конце применить default профиль
        }

        __engine.exportPack(pack);
        __processedPacks.push(pack);
    }


    /*
     *
     */
    private function __processDefaultPack() {
        var packdata : DynamicAccess<Dynamic> = __config[__defaultSectionName];        
        var include = __allFiles.filter(file -> !__usedFiles.exists(file));
        packdata["include"] = include;
        __processPack(__defaultSectionName, packdata);
    }


    /*
     *
     */
    private inline function __checkCLIArgs() {
         
        if (input == null) {
            exitWithError("Input dir must be specified");            
        }        

        if (!FileSystem.exists(input)) {
            exitWithError("Input dir doesn't exists");            
        }

        if (!FileSystem.isDirectory(input)) {
            exitWithError("Input dir isn't a directory");            
        }

        if (configFile == null) {
            configFile = Path.join([input, "rasterizer.json"]);
        }
        
        if (!FileSystem.exists(configFile) || FileSystem.isDirectory(configFile)) {
            exitWithError("Config file not exists or not a file");        
        }

        if (output == null) {
            output = "./";
        }

        if (FileSystem.exists(output) && !FileSystem.isDirectory(output)) {
            exitWithError("Output directory error: file with the same name already exists");            
        }

        if (!FileSystem.exists(output)) {
            FileSystem.createDirectory(output);
        }
    }

    /*
     *
     */
    public static inline function exitWithError(msg : String, code : Int = -1) {
        trace(msg);
        Sys.exit(code);
    }


    /*
     *
     */
    private inline function __readConfigFile() {
        try {            
            __config = Json.parse(File.getContent(configFile));
        } catch (e : Dynamic) {
            trace("Failed to read config file: " + e);
            Sys.exit(-1);            
        }
    }


    /*
     *
     */
    private inline function __readAllFiles() {
        try {                        
            for (entry in FileSystem.readDirectory(input).filter(e -> e.endsWith(".swf") && !FileSystem.isDirectory(Path.join([input, e]))) ) {
                trace('Read entry $entry');
                __allFiles.push(entry);
            }
        } catch (e : Dynamic) {
            exitWithError("Failed to read input directory: " + e);               
        }
    }


    /*
     * Рекурсивно удаляет директорию.
     * DANGER!
     */
    public static function removeDirectory(dir : String) {
        throw new openfl.errors.Error("Not implemented");
    }

    /*
     * Удаляет содержимое директории
     * DANGER!
     */
    public static function clearDirectory(dir : String) {
        throw new openfl.errors.Error("Not implemented");
    }


    /*
     * Entry point. Parse arguments and proceed.
     */
    public static function main() {        
        Cli.process(Sys.args(), new Main()).handle(Cli.exit);
    }



    public function new() {}
}























