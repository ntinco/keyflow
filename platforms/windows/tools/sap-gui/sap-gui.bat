@echo off

"C:\Program Files\SAP\NWBC800\nwbc.exe" ^
 /shortcut=-type=Transaction ^
 -command=%5 ^
 -language=es ^
 -maxgui ^
 -sysname="%3" ^
 -system= ^
 -client=%4 ^
 -user=%1 ^
 -pw="%2" ^
 -reuse=1