#!/bin/bash
cd /Volumes/MacHD/Flash/fcsh_jar
cpath=/Users/midius/steampunk/client/ignore/embedViewer
java -Duser.language=en -Duser.region=en -jar FlexShellScript.jar client "mxmlc  -default-frame-rate=30 -sp=/Users/midius/steampunk/client/src  -l+=/Volumes/MacHD/Flash/sdk/4.6_air/frameworks/libs/air  -include-libraries+=$cpath/lib  -static-link-runtime-shared-libraries  -debug=true  -o=$cpath/bin/embedViewer.swf  -define+=CONFIG::debug,true  -benchmark=true  $cpath/src/ViewerMain.as"
