#!/bin/sh
rm -rf output-embed
_build/Main-debug --input ~/Devel/farm/client_haxe/assets/embed --output output-embed --config embed_conf.json ../respacker.native
