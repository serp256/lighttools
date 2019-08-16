#!/bin/sh

haxelib dev lime /Users/kmd/Devel/GitHub/lime
haxelib dev openfl /Users/kmd/Devel/GitHub/openfl

haxe build.hxml

haxelib dev lime
haxelib dev openfl
