param(
  [Parameter(Mandatory = $true)]
  [string]$Ref,

  [string]$DatabasePath = $env:NORMAN_KEEPASSXC_DB,
  [string]$CliPath = $env:NORMAN_KEEPASSXC_CLI,
  [string]$KeyFile = $env:NORMAN_KEEPASSXC_KEY_FILE,
  [string]$PasswordEnvVar = "NORMAN_KEEPASSXC_DB_PASSWORD",
  [switch]$NoPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-KeePassCliPath {
  param([string]$CliPath)

  if ($CliPath) {
    return $CliPath
  }

  $command = Get-Command keepassxc-cli -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $defaultWindowsPath = "C:\Users\ntincopa\Downloads\.sync\..apps\PortableApps\KeePassXCPortable\App\KeePassXC\keepassxc-cli.exe"
  if (Test-Path $defaultWindowsPath) {
    return $defaultWindowsPath
  }

  $programFilesPath = "C:\Program Files\KeePassXC\keepassxc-cli.exe"
  if (Test-Path $programFilesPath) {
    return $programFilesPath
  }

  throw "Could not find keepassxc-cli. Set NORMAN_KEEPASSXC_CLI or pass -CliPath."
}

function Resolve-KpReference {
  param([string]$Ref)

  if (-not $Ref.StartsWith("kp:")) {
    throw "Unsupported reference '$Ref'. Expected prefix kp:."
  }

  $rawPath = $Ref.Substring(3).Trim("/")
  if (-not $rawPath) {
    throw "KeePass reference '$Ref' is missing a path."
  }

  $segments = $rawPath.Split("/", [System.StringSplitOptions]::RemoveEmptyEntries)
  if ($segments.Length -eq 1) {
    return @{
      EntryPath = $segments[0]
      Attribute = "Password"
    }
  }

  $leaf = $segments[$segments.Length - 1]
  $parent = ($segments[0..($segments.Length - 2)] -join "/")

  switch -Regex ($leaf) {
    "^(?i:title)$" {
      return @{
        EntryPath = $parent
        Attribute = "Title"
      }
    }
    "^(?i:pass|password)$" {
      return @{
        EntryPath = $parent
        Attribute = "Password"
      }
    }
    "^(?i:user|username)$" {
      return @{
        EntryPath = $parent
        Attribute = "UserName"
      }
    }
    "^(?i:url)$" {
      return @{
        EntryPath = $parent
        Attribute = "URL"
      }
    }
    "^(?i:notes)$" {
      return @{
        EntryPath = $parent
        Attribute = "Notes"
      }
    }
    default {
      return @{
        EntryPath = $parent
        Attribute = $leaf
      }
    }
  }
}

function Invoke-KeePassShow {
  param(
    [string]$CliPath,
    [string]$DatabasePath,
    [string]$EntryPath,
    [string]$Attribute,
    [string]$KeyFile,
    [bool]$NoPassword,
    [string]$PasswordEnvVar
  )

  if (-not $DatabasePath) {
    throw "DatabasePath is required. Set NORMAN_KEEPASSXC_DB or pass -DatabasePath."
  }

  if (-not (Test-Path $DatabasePath)) {
    throw "Database file not found: $DatabasePath"
  }

  $passwordValue = [Environment]::GetEnvironmentVariable($PasswordEnvVar)
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $CliPath
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.RedirectStandardInput = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $arguments = New-Object System.Collections.Generic.List[string]
  $arguments.Add("show")
  $arguments.Add("-q")
  $arguments.Add("-s")
  if ($KeyFile) {
    $arguments.Add("-k")
    $arguments.Add($KeyFile)
  }
  if ($NoPassword) {
    $arguments.Add("--no-password")
  }
  $arguments.Add($DatabasePath)
  $arguments.Add($EntryPath)
  $arguments.Add("--attributes")
  $arguments.Add($Attribute)

  foreach ($argument in $arguments) {
    [void]$psi.ArgumentList.Add($argument)
  }

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $psi
  [void]$process.Start()

  if (-not $NoPassword) {
    if ([string]::IsNullOrEmpty($passwordValue)) {
      $process.Kill()
      throw "Database password env var '$PasswordEnvVar' is empty. Set it, or use -NoPassword for a keyfile-only database."
    }
    $process.StandardInput.WriteLine($passwordValue)
  }
  $process.StandardInput.Close()

  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()

  if ($process.ExitCode -ne 0) {
    $detail = $stderr.Trim()
    if (-not $detail) {
      $detail = "keepassxc-cli exited with code $($process.ExitCode)."
    }
    throw $detail
  }

  return $stdout.Trim()
}

try {
  $resolvedCliPath = Resolve-KeePassCliPath -CliPath $CliPath
  $resolvedRef = Resolve-KpReference -Ref $Ref
  $value = Invoke-KeePassShow `
    -CliPath $resolvedCliPath `
    -DatabasePath $DatabasePath `
    -EntryPath $resolvedRef.EntryPath `
    -Attribute $resolvedRef.Attribute `
    -KeyFile $KeyFile `
    -NoPassword $NoPassword.IsPresent `
    -PasswordEnvVar $PasswordEnvVar

  [Console]::Out.Write($value)
  exit 0
}
catch {
  [Console]::Error.WriteLine($_.Exception.Message)
  exit 1
}
