<#
.SYNOPSIS
    Synchronize enhanced Android CLI skill across AI agent platforms.
.DESCRIPTION
    Copies the enhanced SKILL.md and references from Claude's android-cli skill
    to Gemini CLI, Codex, and Antigravity CLI skill directories.
    Supports dry-run mode, automatic backups, and requires explicit approval.
.PARAMETER DryRun
    Show what would change without modifying anything.
.PARAMETER Force
    Skip the approval prompt (for automation).
.PARAMETER SkipBackup
    Skip creating backups before overwriting.
.PARAMETER Targets
    Comma-separated list of targets: gemini, codex, antigravity, or all (default: all).
#>
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$SkipBackup,
    [string]$Targets = "all"
)

$ErrorActionPreference = "Stop"

$sourceDir = "$HOME/.claude/skills/android-cli"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$agentTargets = @{
    gemini = @{
        Name = "Gemini CLI"
        SkillDir = "$HOME/.gemini/skills\android-cli"
        SupportsRefs = $true
    }
    codex = @{
        Name = "Codex"
        SkillDir = "$HOME/.codex/skills\android-cli"
        SupportsRefs = $true
    }
    antigravity = @{
        Name = "Antigravity CLI"
        SkillDir = "$HOME/.gemini/antigravity-cli/skills\android-cli"
        SupportsRefs = $true
    }
}

$selectedTargets = if ($Targets -eq "all") {
    $agentTargets.Keys
} else {
    $Targets -split "," | ForEach-Object { $_.Trim().ToLower() }
}

foreach ($t in $selectedTargets) {
    if (-not $agentTargets.ContainsKey($t)) {
        Write-Error "Unknown target: $t. Valid targets: gemini, codex, antigravity, all"
        exit 1
    }
}

if (-not (Test-Path "$sourceDir\SKILL.md")) {
    Write-Error "Source skill not found at $sourceDir\SKILL.md"
    exit 1
}

$sourceFiles = @("SKILL.md")
if (Test-Path "$sourceDir\references") {
    $refFiles = Get-ChildItem "$sourceDir\references" -File | ForEach-Object { "references\$($_.Name)" }
    $sourceFiles += $refFiles
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Android CLI Skill Sync Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Source: $sourceDir"
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN (no changes)' } else { 'LIVE' })"
Write-Host "Targets: $($selectedTargets -join ', ')"
Write-Host "Files to sync: $($sourceFiles.Count)"
Write-Host ""

$report = @()

foreach ($targetKey in $selectedTargets) {
    $target = $agentTargets[$targetKey]
    $targetDir = $target.SkillDir
    $targetName = $target.Name

    Write-Host "--- $targetName ---" -ForegroundColor Yellow
    Write-Host "  Directory: $targetDir"

    $changes = @()
    $backupDir = $null

    foreach ($relPath in $sourceFiles) {
        $srcFile = Join-Path $sourceDir $relPath
        $dstFile = Join-Path $targetDir $relPath

        if (Test-Path $dstFile) {
            $srcHash = (Get-FileHash $srcFile -Algorithm SHA256).Hash
            $dstHash = (Get-FileHash $dstFile -Algorithm SHA256).Hash

            if ($srcHash -eq $dstHash) {
                Write-Host "  [=] $relPath (identical)" -ForegroundColor DarkGray
            } else {
                $srcSize = (Get-Item $srcFile).Length
                $dstSize = (Get-Item $dstFile).Length
                Write-Host "  [~] $relPath (changed: $dstSize -> $srcSize bytes)" -ForegroundColor Yellow
                $changes += @{ Path = $relPath; Action = "UPDATE"; SrcFile = $srcFile; DstFile = $dstFile }
            }
        } else {
            Write-Host "  [+] $relPath (new)" -ForegroundColor Green
            $changes += @{ Path = $relPath; Action = "ADD"; SrcFile = $srcFile; DstFile = $dstFile }
        }
    }

    if ($changes.Count -eq 0) {
        Write-Host "  No changes needed." -ForegroundColor DarkGray
        $report += [PSCustomObject]@{ Target = $targetName; Status = "UP-TO-DATE"; Changes = 0; BackupDir = "" }
        continue
    }

    Write-Host "`n  $($changes.Count) file(s) to sync." -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "  [DRY RUN] No changes applied." -ForegroundColor Magenta
        $report += [PSCustomObject]@{ Target = $targetName; Status = "DRY-RUN"; Changes = $changes.Count; BackupDir = "" }
        continue
    }

    if (-not $Force) {
        $answer = Read-Host "  Apply changes to $targetName? (yes/no)"
        if ($answer -ne "yes") {
            Write-Host "  Skipped." -ForegroundColor DarkYellow
            $report += [PSCustomObject]@{ Target = $targetName; Status = "SKIPPED"; Changes = 0; BackupDir = "" }
            continue
        }
    }

    if (-not $SkipBackup) {
        $backupDir = Join-Path $targetDir "backup-$timestamp"
        Write-Host "  Creating backup at $backupDir ..."
        foreach ($change in $changes) {
            if ($change.Action -eq "UPDATE") {
                $backupFile = Join-Path $backupDir $change.Path
                $backupParent = Split-Path $backupFile -Parent
                if (-not (Test-Path $backupParent)) {
                    New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
                }
                Copy-Item $change.DstFile $backupFile
            }
        }
    }

    foreach ($change in $changes) {
        $dstParent = Split-Path $change.DstFile -Parent
        if (-not (Test-Path $dstParent)) {
            New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
        }
        Copy-Item $change.SrcFile $change.DstFile -Force
        Write-Host "  Synced: $($change.Path)" -ForegroundColor Green
    }

    $report += [PSCustomObject]@{
        Target = $targetName
        Status = "SYNCED"
        Changes = $changes.Count
        BackupDir = if ($backupDir) { $backupDir } else { "none" }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Sync Report" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$report | Format-Table -AutoSize

if ($DryRun) {
    Write-Host "This was a DRY RUN. Re-run without -DryRun to apply changes." -ForegroundColor Magenta
}
