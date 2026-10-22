<#
.SYNOPSIS
    Installs Android AI Engineering System skills to AI assistant directories.

.DESCRIPTION
    Copies skill files to Claude Code, Gemini, and/or Codex skill directories.
    Supports -WhatIf for dry-run previews and -Force to overwrite existing skills.

.PARAMETER Target
    Which AI assistant(s) to install for. Default: Claude.
    Valid values: Claude, Gemini, Codex, All

.PARAMETER SkillsSource
    Path to the skills directory. Default: ../skills relative to this script.

.PARAMETER WhatIf
    Preview what would be installed without making changes.

.PARAMETER Force
    Overwrite existing skill directories.
#>
param(
    [ValidateSet("Claude", "Gemini", "Codex", "All")]
    [string]$Target = "Claude",

    [string]$SkillsSource,

    [switch]$WhatIf,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Resolve skills source directory
if (-not $SkillsSource) {
    $SkillsSource = Join-Path $PSScriptRoot "..\skills"
}
$SkillsSource = Resolve-Path $SkillsSource -ErrorAction Stop

# Define target directories
$targets = @{
    Claude = Join-Path $HOME ".claude\skills"
    Gemini = Join-Path $HOME ".gemini\skills"
    Codex  = Join-Path $HOME ".codex\skills"
}

# Determine which targets to install
$installTargets = @()
if ($Target -eq "All") {
    $installTargets = @("Claude", "Gemini", "Codex")
} else {
    $installTargets = @($Target)
}

Write-Host "`nAndroid AI Engineering System — Skill Installer" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Source: $SkillsSource"

if ($WhatIf) {
    Write-Host "[DRY RUN] No files will be modified.`n" -ForegroundColor Yellow
}

# Get list of skills
$skills = Get-ChildItem -Path $SkillsSource -Directory
Write-Host "Found $($skills.Count) skills to install.`n"

foreach ($targetName in $installTargets) {
    $targetDir = $targets[$targetName]
    Write-Host "--- Installing to $targetName ($targetDir) ---" -ForegroundColor Green

    foreach ($skill in $skills) {
        $destPath = Join-Path $targetDir $skill.Name
        $exists = Test-Path $destPath

        if ($exists -and -not $Force) {
            Write-Host "  SKIP: $($skill.Name) (already exists; use -Force to overwrite)" -ForegroundColor Yellow
            continue
        }

        $action = if ($exists) { "OVERWRITE" } else { "INSTALL" }

        if ($WhatIf) {
            Write-Host "  WOULD $action`: $($skill.Name) -> $destPath" -ForegroundColor DarkGray
        } else {
            if ($exists) {
                Remove-Item -Path $destPath -Recurse -Force -Confirm:$false
            }

            $parentDir = Split-Path $destPath -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }

            Copy-Item -Path $skill.FullName -Destination $destPath -Recurse
            Write-Host "  $action`: $($skill.Name)" -ForegroundColor White
        }
    }
    Write-Host ""
}

$totalFiles = (Get-ChildItem -Path $SkillsSource -Recurse -File).Count
if ($WhatIf) {
    Write-Host "Dry run complete. $($skills.Count) skills ($totalFiles files) would be installed." -ForegroundColor Yellow
} else {
    Write-Host "Installation complete. $($skills.Count) skills ($totalFiles files) installed." -ForegroundColor Green
}
