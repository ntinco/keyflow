@echo off
setlocal EnableDelayedExpansion

:: Refresh environment variables from registry for the current cmd.exe session.
:: Based on the Chocolatey RefreshEnv pattern. Use from cmd.exe, not PowerShell.

echo Refreshing environment variables from registry for cmd.exe...

call :GetRegEnv "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" > "%TEMP%\_keyflow_env.cmd"
call :GetRegEnv "HKCU\Environment" >> "%TEMP%\_keyflow_env.cmd"
call :SetFromReg "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" Path Path_HKLM >> "%TEMP%\_keyflow_env.cmd"
call :SetFromReg "HKCU\Environment" Path Path_HKCU >> "%TEMP%\_keyflow_env.cmd"
echo set "Path=%%Path_HKLM%%;%%Path_HKCU%%" >> "%TEMP%\_keyflow_env.cmd"

set "OriginalUserName=%USERNAME%"
set "OriginalArchitecture=%PROCESSOR_ARCHITECTURE%"
call "%TEMP%\_keyflow_env.cmd"
del /f /q "%TEMP%\_keyflow_env.cmd" 2>nul
set "USERNAME=%OriginalUserName%"
set "PROCESSOR_ARCHITECTURE=%OriginalArchitecture%"

echo Finished.
endlocal & set "Path=%Path%"
exit /b 0

:SetFromReg
"%WinDir%\System32\Reg" QUERY "%~1" /v "%~2" > "%TEMP%\_keyflow_envset.tmp" 2>NUL
for /f "usebackq skip=2 tokens=2,*" %%A IN ("%TEMP%\_keyflow_envset.tmp") do echo set "%~3=%%B"
del /f /q "%TEMP%\_keyflow_envset.tmp" 2>nul
exit /b 0

:GetRegEnv
"%WinDir%\System32\Reg" QUERY "%~1" > "%TEMP%\_keyflow_envget.tmp" 2>NUL
for /f "usebackq skip=2" %%A IN ("%TEMP%\_keyflow_envget.tmp") do if /I not "%%~A"=="Path" call :SetFromReg "%~1" "%%~A" "%%~A"
del /f /q "%TEMP%\_keyflow_envget.tmp" 2>nul
exit /b 0
