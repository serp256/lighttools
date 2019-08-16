#!/bin/sh
rm -rf output-embed

haxelib dev lime /Users/kmd/Devel/GitHub/lime
haxelib dev openfl /Users/kmd/Devel/GitHub/openfl

_build/Main --input ~/Devel/farm/client_haxe/assets/embed --output output-embed --config embed_conf.json ../respacker.native


haxelib dev lime
haxelib dev openfl
