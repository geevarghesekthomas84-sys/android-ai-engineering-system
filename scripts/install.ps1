<#
.SYNOPSIS
    Installs, upgrades, backs up, or uninstalls Android AI Engineering System skills.

.DESCRIPTION
    Manages skill files for Claude Code, Gemini CLI, and Codex skill directories.
    Supports dry-run preview, backup before overwrite, upgrade, and uninstall.

.EXAMPLE
    ./install.ps1 -WhatIf                      # Preview install to Claude
    ./install.ps1 -Target All                   # Install to Claude + Gemini + Codex
    ./install.ps1 -Action Upgrade -Force        # Upgrade with backup, overwrite all
    ./install.ps1 -Action Backup                # Backup current skills only
    ./install.ps1 -Action Uninstall -Target All # Remove skills from all targets
#>
param(
    [ValidateSet("Install", "Upgrade", "Backup", "Uninstall")]
    [string]$Action = "Install",

    [ValidateSet("Claude", "Gemini", "Codex", "All")]
    [string]$Target = "Claude",

    [string]$SkillsSource,
    [string]$BackupDir,
    [switch]$WhatIf,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not $SkillsSource) {
    $SkillsSource = Join-Path $PSScriptRoot "..\skills"
}
if (Test-Path $SkillsSource) {
    $SkillsSource = Resolve-Path $SkillsSource
}

if (-not $BackupDir) {
    $BackupDir = Join-Path $HOME ".android-ai-backup"
}

$targets = @{
    Claude = Join-Path $HOME ".claude/skills"
    Gemini = Join-Path $HOME ".gemini/skills"
    Codex  = Join-Path $HOME ".codex/skills"
}

if ($Target -eq "All") {
    $installTargets = @("Claude", "Gemini", "Codex")
} else {
    $installTargets = @($Target)
}

$knownSkills = @(
    "ai-integration-engineer", "android-cli", "android-frontend-engineer",
    "android-security-engineer", "android-security-lab-builder", "android-testing-engineer",
    "android-ui-ux-design", "app-performance-engineer", "app-product-architect",
    "backend-api-engineer", "database-offline-sync", "devops-release-engineer",
    "firebase-supabase-engineer", "fullstack-web-engineer"
)

Write-Host ""
Write-Host "Android AI Engineering System - Skill Manager" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "Action: $Action | Target: $Target"
if ($WhatIf) { Write-Host "[DRY RUN] No files will be modified." -ForegroundColor Yellow }
Write-Host ""

function Backup-Skills {
    param([string]$TName, [string]$TDir)

    if (-not (Test-Path $TDir)) {
        Write-Host "  No existing skills for $TName" -ForegroundColor DarkGray
        return
    }

    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $dest = Join-Path $BackupDir "$TName-$ts"

    if ($WhatIf) {
        Write-Host "  WOULD BACKUP: $TDir -> $dest" -ForegroundColor DarkGray
        return
    }

    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    Copy-Item -Path $TDir -Destination $dest -Recurse
    $cnt = @(Get-ChildItem -Path $dest -Recurse -File).Count
    Write-Host "  BACKED UP $TName - $cnt files -> $dest" -ForegroundColor Green
}

switch ($Action) {
    "Backup" {
        foreach ($tgt in $installTargets) {
            Write-Host "--- Backing up $tgt ---" -ForegroundColor Green
            Backup-Skills -TName $tgt -TDir $targets[$tgt]
        }
    }

    "Uninstall" {
        foreach ($tgt in $installTargets) {
            $tDir = $targets[$tgt]
            Write-Host "--- Uninstalling from $tgt ---" -ForegroundColor Green
            Backup-Skills -TName $tgt -TDir $tDir

            foreach ($sn in $knownSkills) {
                $sp = Join-Path $tDir $sn
                if (Test-Path $sp) {
                    if ($WhatIf) {
                        Write-Host "  WOULD REMOVE: $sn" -ForegroundColor DarkGray
                    } else {
                        Remove-Item -Path $sp -Recurse -Force -Confirm:$false
                        Write-Host "  REMOVED: $sn" -ForegroundColor Red
                    }
                }
            }
            Write-Host ""
        }
        if (-not $WhatIf) {
            Write-Host "Uninstall complete. Backups saved to: $BackupDir" -ForegroundColor Green
        }
    }

    default {
        # Install or Upgrade
        if (-not (Test-Path $SkillsSource)) {
            Write-Host "ERROR: Skills source not found: $SkillsSource" -ForegroundColor Red
            exit 1
        }

        $skills = Get-ChildItem -Path $SkillsSource -Directory
        Write-Host "Source: $SkillsSource"
        $sc = $skills.Count
        Write-Host "Found $sc skills."
        Write-Host ""

        foreach ($tgt in $installTargets) {
            $tDir = $targets[$tgt]
            Write-Host "--- $Action to $tgt [$tDir] ---" -ForegroundColor Green

            if ($Action -eq "Upgrade") {
                Backup-Skills -TName $tgt -TDir $tDir
            }

            foreach ($skill in $skills) {
                $destPath = Join-Path $tDir $skill.Name
                $exists = Test-Path $destPath

                if ($exists -and -not $Force -and $Action -eq "Install") {
                    Write-Host "  SKIP: $($skill.Name) - exists. Use -Force or -Action Upgrade" -ForegroundColor Yellow
                    continue
                }

                if ($exists) { $label = "OVERWRITE" } else { $label = "INSTALL" }

                if ($WhatIf) {
                    Write-Host "  WOULD ${label}: $($skill.Name)" -ForegroundColor DarkGray
                } else {
                    if ($exists) {
                        Remove-Item -Path $destPath -Recurse -Force -Confirm:$false
                    }
                    $parentDir = Split-Path $destPath -Parent
                    if (-not (Test-Path $parentDir)) {
                        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                    }
                    Copy-Item -Path $skill.FullName -Destination $destPath -Recurse
                    Write-Host "  ${label}: $($skill.Name)" -ForegroundColor White
                }
            }
            Write-Host ""
        }

        $totalFiles = @(Get-ChildItem -Path $SkillsSource -Recurse -File).Count
        if ($WhatIf) {
            Write-Host "Dry run complete. $sc skills, $totalFiles files." -ForegroundColor Yellow
        } else {
            Write-Host "$Action complete. $sc skills, $totalFiles files." -ForegroundColor Green
        }
    }
}

Write-Host ""
