@echo off
set PAUSE_ERRORS=1
call bat\PathSDK.bat
call bat\SetupSDK.bat
call bat\SetupApplication.bat

set AIR_TARGET=
::set AIR_TARGET=-captive-runtime
set OPTIONS=-tsa none
call bat\Packager.bat

pause