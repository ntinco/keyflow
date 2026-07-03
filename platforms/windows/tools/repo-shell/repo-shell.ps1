Set-StrictMode -Version Latest

function global:Get-KeyflowRepoRoot {
  $configured = $env:KEYFLOW_REPO_ROOT
  if (-not [string]::IsNullOrWhiteSpace($configured)) {
    return $configured
  }

  $legacy = $env:GITHUB_REPO_ROOT
  if (-not [string]::IsNullOrWhiteSpace($legacy)) {
    return $legacy
  }

  $defaultUserRoot = Join-Path $HOME ".sync\GitHub\ntinco"
  if (Test-Path -LiteralPath $defaultUserRoot) {
    return $defaultUserRoot
  }

  return (Join-Path $HOME ".sync\GitHub")
}

function global:Set-KeyflowRepoRoot {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [switch]$Create
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    if ($Create.IsPresent) {
      New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    else {
      throw "Repo root not found: $Path. Re-run with -Create to create it."
    }
  }

  $resolved = (Resolve-Path -LiteralPath $Path).Path
  [Environment]::SetEnvironmentVariable("KEYFLOW_REPO_ROOT", $resolved, "User")
  $env:KEYFLOW_REPO_ROOT = $resolved
  Write-Host "KEYFLOW_REPO_ROOT = $resolved"
}

function global:Get-KeyflowRepoList {
  $root = Get-KeyflowRepoRoot
  if (-not (Test-Path -LiteralPath $root)) {
    throw "Repo root not found: $root. Set it with Set-KeyflowRepoRoot <path> -Create."
  }

  $result = New-Object System.Collections.Generic.List[object]
  $children = Get-ChildItem -LiteralPath $root -Directory -ErrorAction Stop

  foreach ($child in $children) {
    $gitPath = Join-Path $child.FullName ".git"
    if (Test-Path -LiteralPath $gitPath) {
      $result.Add([pscustomobject]@{
        Name = $child.Name
        DisplayName = $child.Name
        FullName = $child.FullName
      }) | Out-Null
      continue
    }

    $nestedChildren = Get-ChildItem -LiteralPath $child.FullName -Directory -ErrorAction SilentlyContinue
    foreach ($nested in $nestedChildren) {
      $nestedGitPath = Join-Path $nested.FullName ".git"
      if (Test-Path -LiteralPath $nestedGitPath) {
        $result.Add([pscustomobject]@{
          Name = $nested.Name
          DisplayName = "$($child.Name)/$($nested.Name)"
          FullName = $nested.FullName
        }) | Out-Null
      }
    }
  }

  return $result | Sort-Object DisplayName
}

function global:Find-KeyflowRepo {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $repos = @(Get-KeyflowRepoList)
  $exact = @($repos | Where-Object { $_.Name -eq $Name -or $_.DisplayName -eq $Name })
  if ($exact.Count -eq 1) {
    return $exact[0]
  }

  $matches = @($repos | Where-Object { $_.Name -like "*$Name*" -or $_.DisplayName -like "*$Name*" })
  if ($matches.Count -eq 1) {
    return $matches[0]
  }

  if ($matches.Count -gt 1) {
    Write-Host "Multiple matches:"
    $matches | Select-Object -ExpandProperty DisplayName
    return $null
  }

  Write-Host "Repo not found: $Name"
  return $null
}

function global:repo {
  param([string]$Name)

  if ([string]::IsNullOrWhiteSpace($Name)) {
    Get-KeyflowRepoList | Select-Object -ExpandProperty DisplayName
    return
  }

  $match = Find-KeyflowRepo -Name $Name
  if ($null -eq $match) {
    return
  }

  Set-Location -LiteralPath $match.FullName
}

function global:code-repo {
  param([string]$Name)

  if ([string]::IsNullOrWhiteSpace($Name)) {
    repo
    return
  }

  $match = Find-KeyflowRepo -Name $Name
  if ($null -eq $match) {
    return
  }

  Set-Location -LiteralPath $match.FullName
  $code = Get-Command code -ErrorAction SilentlyContinue
  if ($null -eq $code) {
    throw "VS Code CLI not found. Install 'code' in PATH from VS Code Command Palette: Shell Command: Install 'code' command in PATH."
  }

  & $code.Source .
}

function global:repo-status {
  $repos = @(Get-KeyflowRepoList)
  foreach ($item in $repos) {
    Push-Location $item.FullName
    try {
      Write-Host ""
      Write-Host "== $($item.DisplayName) =="
      git status -sb
    }
    finally {
      Pop-Location
    }
  }
}

function global:repo-fetch {
  $repos = @(Get-KeyflowRepoList)
  foreach ($item in $repos) {
    Push-Location $item.FullName
    try {
      Write-Host ""
      Write-Host "== $($item.DisplayName) =="
      git fetch --prune
    }
    finally {
      Pop-Location
    }
  }
}

function global:repo-root {
  Get-KeyflowRepoRoot
}
