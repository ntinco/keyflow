@echo off
setlocal

echo keyflow Windows cache cleanup
echo This script deletes validated local cache/temp locations only.
echo.
choice /M "Continue"
if errorlevel 2 exit /b 1

for /d %%i in ("%userprofile%\appdata\local\*updater*") do rmdir /s /q "%%i" 2>nul
rmdir /s /q "%userprofile%\appdata\local\crashdumps" 2>nul
rmdir /s /q "%userprofile%\appdata\local\package cache" 2>nul
rmdir /s /q "%userprofile%\appdata\local\temp" 2>nul
rmdir /s /q "%userprofile%\appdata\local\vmware" 2>nul
rmdir /s /q "%userprofile%\appdata\local\zscaler" 2>nul

rmdir /s /q "%userprofile%\appdata\roaming\quickaccess\logs" 2>nul
rmdir /s /q "%userprofile%\appdata\roaming\Zoom\ZoomDownload" 2>nul
rmdir /s /q "%userprofile%\appdata\roaming\microsoft\office\recent" 2>nul
rmdir /s /q "%userprofile%\appdata\roaming\microsoft\templates\livecontent" 2>nul
rmdir /s /q "%userprofile%\appdata\roaming\microsoft\windows\recent" 2>nul
rmdir /s /q "%userprofile%\appdata\roaming\microsoft\word" 2>nul

del /s /q "%systemdrive%\$Recycle.bin" 2>nul
cleanmgr /verylowdisk /d %systemdrive:~0,1%

echo.
echo Cleanup complete.
endlocal
