#!/bin/sh
rm -rf output-extern
_build/Main-debug --input ~/Devel/farm/docroot/swfs/ --output output-extern --config extern_conf.json ../respacker.native
