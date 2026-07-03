param(
  [string]$RepoRoot,
  [switch]$NoProfileUpdate,
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$toolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$loaderPath = Join-Path $toolDir "repo-shell.ps1"

if (-not (Test-Path -LiteralPath $loaderPath)) {
  throw "Missing repo-shell.ps1 next to installer: $loaderPath"
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  if (-not [string]::IsNullOrWhiteSpace($env:KEYFLOW_REPO_ROOT)) {
    $RepoRoot = $env:KEYFLOW_REPO_ROOT
  }
  else {
    $RepoRoot = Join-Path $HOME ".sync\GitHub\ntinco"
  }
}

if (-not (Test-Path -LiteralPath $RepoRoot)) {
  New-Item -ItemType Directory -Path $RepoRoot -Force | Out-Null
}

$resolvedRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
[Environment]::SetEnvironmentVariable("KEYFLOW_REPO_ROOT", $resolvedRoot, "User")
$env:KEYFLOW_REPO_ROOT = $resolvedRoot

if (-not $NoProfileUpdate.IsPresent) {
  $profilePath = $PROFILE.CurrentUserCurrentHost
  $profileDir = Split-Path -Parent $profilePath

  if (-not (Test-Path -LiteralPath $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
  }

  if (-not (Test-Path -LiteralPath $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
  }

  $begin = "# BEGIN keyflow repo shell"
  $end = "# END keyflow repo shell"
  $block = @"
$begin
. "$loaderPath"
$end
"@

  $profileContent = Get-Content -LiteralPath $profilePath -Raw
  if ($profileContent -match [regex]::Escape($begin)) {
    if ($Force.IsPresent) {
      $pattern = "(?s)" + [regex]::Escape($begin) + ".*?" + [regex]::Escape($end)
      $profileContent = [regex]::Replace($profileContent, $pattern, $block)
      Set-Content -LiteralPath $profilePath -Value $profileContent -Encoding UTF8
    }
  }
  else {
    Add-Content -LiteralPath $profilePath -Value "`n$block" -Encoding UTF8
  }
}

. $loaderPath

Write-Host "Repo shell installed."
Write-Host "KEYFLOW_REPO_ROOT = $resolvedRoot"
Write-Host "Available commands: repo, code-repo, repo-status, repo-fetch, repo-root, Set-KeyflowRepoRoot"
Write-Host "Try: repo"
