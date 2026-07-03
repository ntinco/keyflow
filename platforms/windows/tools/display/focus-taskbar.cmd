@echo off
setlocal EnableExtensions

set "MODE=%~1"
if "%MODE%"=="" set "MODE=toggle"

if /I "%MODE%"=="/h" goto :usage
if /I "%MODE%"=="/?" goto :usage
if /I "%MODE%"=="--help" goto :usage
if /I not "%MODE%"=="hide" if /I not "%MODE%"=="show" if /I not "%MODE%"=="toggle" goto :usage

set "PS1=%TEMP%\keyflow-taskbar-focus-%RANDOM%.ps1"

> "%PS1%" (
  echo param^(^[ValidateSet^('hide','show','toggle'^)^] [string]$Mode = 'toggle'^)
  echo $ErrorActionPreference = 'Stop'
  echo Add-Type @'
  echo using System;
  echo using System.Runtime.InteropServices;
  echo public static class Win32 {
  echo   [DllImport^("user32.dll"^)] public static extern IntPtr FindWindow^(string lpClassName, string lpWindowName^);
  echo   [DllImport^("user32.dll"^)] public static extern IntPtr FindWindowEx^(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow^);
  echo   [DllImport^("user32.dll"^)] public static extern bool ShowWindow^(IntPtr hWnd, int nCmdShow^);
  echo   [DllImport^("user32.dll"^)] public static extern bool IsWindowVisible^(IntPtr hWnd^);
  echo }
  echo '@
  echo $SW_HIDE = 0
  echo $SW_SHOW = 5
  echo $handles = New-Object 'System.Collections.Generic.List[IntPtr]'
  echo $primary = [Win32]::FindWindow^('Shell_TrayWnd', $null^)
  echo if ^($primary -ne [IntPtr]::Zero^) { $handles.Add^($primary^) }
  echo $child = [IntPtr]::Zero
  echo while ^($true^) {
  echo   $child = [Win32]::FindWindowEx^([IntPtr]::Zero, $child, 'Shell_SecondaryTrayWnd', $null^)
  echo   if ^($child -eq [IntPtr]::Zero^) { break }
  echo   $handles.Add^($child^)
  echo }
  echo if ^($handles.Count -eq 0^) { Write-Host 'Taskbar not found.'; exit 2 }
  echo $visible = $false
  echo foreach ^($h in $handles^) { if ^([Win32]::IsWindowVisible^($h^)^) { $visible = $true; break } }
  echo if ^($Mode -eq 'toggle'^) { if ^($visible^) { $Mode = 'hide' } else { $Mode = 'show' } }
  echo $showCommand = if ^($Mode -eq 'hide'^) { $SW_HIDE } else { $SW_SHOW }
  echo foreach ^($h in $handles^) { [void][Win32]::ShowWindow^($h, $showCommand^) }
  echo Write-Host ^("Taskbar " + $Mode + " applied."^)
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Mode "%MODE%"
set "EXIT_CODE=%ERRORLEVEL%"
if exist "%PS1%" del /q "%PS1%" >nul 2>nul
exit /b %EXIT_CODE%

:usage
echo Usage: focus-taskbar.cmd [hide^|show^|toggle]
echo.
echo Examples:
echo   focus-taskbar.cmd hide
echo   focus-taskbar.cmd show
echo   focus-taskbar.cmd toggle
echo.
echo Notes:
echo   - Hides/shows the Windows taskbar without changing registry settings.
echo   - State can reset if Explorer restarts or Windows restarts.
exit /b 1
