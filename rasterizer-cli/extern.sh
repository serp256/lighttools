#!/bin/sh
rm -rf output-extern

haxelib dev lime /Users/kmd/Devel/GitHub/lime
haxelib dev openfl /Users/kmd/Devel/GitHub/openfl

_build/Main --input ~/Devel/farm/docroot/swfs/ --output output-extern --config extern_conf.json ../respacker.native

haxelib dev lime
haxelib dev openfl
