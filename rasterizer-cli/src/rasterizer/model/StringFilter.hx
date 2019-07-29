package rasterizer.model;

import haxe.io.Error;

/*
 * Include/Exclude фильтр.
 * Чисто для оптимизации и уменьшения кол-ва кода
 */
using StringTools;
using Lambda;

class StringFilter {

    /*
     * include - строки, которые надо включить
     * exclude - строки, которые надо отметать
     * Это или строка или массив строк.
     * Если строка начинается и заканчивается '/', то мы из нее делаем EReg
     */

    private var __include : Array<String>;

    private var __include_re : Array<EReg>;

    private var __exclude : Array<String>;

    private var __exclude_re : Array<EReg>;


    /*
     *
     */
    public function new(include : Dynamic, exclude : Dynamic) {
        __include = [];
        __include_re = [];
        __exclude = [];
        __exclude_re = [];

        var i : Array<String> = null;
        if (Std.is(include, Array)) {
            i = cast include;
        } else if (Std.is(include, String)) {
            i = [ (include : String) ];
        } else if (include != null) {
            throw new openfl.errors.Error("include must be a string or an array of srtings");
        }

        var e : Array<String> = null;
        if (Std.is(exclude, Array)) {
            e = cast exclude;
        } else if (Std.is(exclude, String)) {
            e = [ (exclude : String) ];
        } else if (exclude != null) {
            throw new openfl.errors.Error("exclude must be a string or an array of srtings");
        }
        
        if (i != null) {
            for (s in i) {
                s = s.trim();
                if (s.startsWith("/") && s.endsWith("/")) {
                    __include_re.push(new EReg(s.substr(1, s.length - 2),""));
                } else {
                    __include.push(s);
                }
            }
        }

        if (e != null) {
            for (s in e) {
                s = s.trim();
                if (s.startsWith("/") && s.endsWith("/")) {
                    __exclude_re.push(new EReg(s.substr(1, s.length - 2),""));
                } else {
                    __exclude.push(s);
                }
            }            
        }
    }

    /*
     * Тестим value на включение
     */
    public function includes(value : String) : Bool {

        // исключаем файл
        var excl = __exclude_re.exists(re -> re.match(value));
        if (excl || (__exclude.length > 0 && __exclude.indexOf(value) != -1)) {
            return false;
        }            

        // влючаем файл
        var inc = __include_re.exists(re -> re.match(value));
        if (inc || (__include.length > 0 && __include.indexOf(value) != -1)) {
            return true;
        }            

        return false;
    }



}