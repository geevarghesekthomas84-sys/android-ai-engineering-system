param(
    [string]$Serial
)

$ErrorActionPreference = "SilentlyContinue"

# Find ADB
$adbPath = $null
$searchPaths = @(
    "$env:ANDROID_HOME\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:USERPROFILE\Downloads\platform-tools-latest-windows\platform-tools\adb.exe"
)

foreach ($p in $searchPaths) {
    if (Test-Path $p) { $adbPath = $p; break }
}

if (-not $adbPath) {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { $adbPath = $cmd.Source }
    else {
        Write-Error "ADB not found. Install platform-tools or set ANDROID_HOME."
        exit 1
    }
}

$adbArgs = @()
if ($Serial) { $adbArgs = @("-s", $Serial) }

function Invoke-Adb {
    param([string[]]$Args)
    $allArgs = $adbArgs + $Args
    & $adbPath @allArgs 2>&1 | Out-String
}

function Get-DeviceProp {
    param([string]$Prop)
    $val = Invoke-Adb @("shell", "getprop", $Prop)
    return $val.Trim()
}

Write-Host "=== Device Inspector ===" -ForegroundColor Cyan
Write-Host "ADB: $adbPath"
Write-Host ""

# List devices
Write-Host "Connected Devices:" -ForegroundColor Yellow
$deviceList = Invoke-Adb @("devices", "-l")
Write-Host $deviceList

if (-not $Serial) {
    $deviceLines = ($deviceList -split "`n") | Where-Object { $_ -match "device\s" -and $_ -notmatch "^List" }
    if ($deviceLines.Count -eq 0) {
        Write-Host "No devices connected." -ForegroundColor Red
        exit 0
    }
    if ($deviceLines.Count -gt 1) {
        Write-Host "Multiple devices found. Use -Serial to specify one." -ForegroundColor Yellow
    }
}

Write-Host "--- Device Info ---" -ForegroundColor Yellow
$props = @(
    @("Android Version", "ro.build.version.release"),
    @("API Level", "ro.build.version.sdk"),
    @("Device Model", "ro.product.model"),
    @("Manufacturer", "ro.product.manufacturer"),
    @("Brand", "ro.product.brand"),
    @("Hardware", "ro.hardware"),
    @("Build ID", "ro.build.display.id"),
    @("Security Patch", "ro.build.version.security_patch"),
    @("ABI", "ro.product.cpu.abi")
)

foreach ($prop in $props) {
    $val = Get-DeviceProp $prop[1]
    if ($val) {
        Write-Host ("{0,-20} {1}" -f "$($prop[0]):", $val)
    }
}

Write-Host ""
Write-Host "--- Screen ---" -ForegroundColor Yellow
$size = Invoke-Adb @("shell", "wm", "size")
$density = Invoke-Adb @("shell", "wm", "density")
Write-Host "Resolution: $($size.Trim())"
Write-Host "Density:    $($density.Trim())"

Write-Host ""
Write-Host "--- Storage ---" -ForegroundColor Yellow
$storage = Invoke-Adb @("shell", "df", "-h", "/data")
Write-Host $storage.Trim()

Write-Host ""
Write-Host "--- Battery ---" -ForegroundColor Yellow
$battery = Invoke-Adb @("shell", "dumpsys", "battery")
$level = ($battery -split "`n" | Select-String "level:" | Select-Object -First 1).ToString().Trim()
$status = ($battery -split "`n" | Select-String "status:" | Select-Object -First 1).ToString().Trim()
if ($level) { Write-Host "  $level" }
if ($status) { Write-Host "  $status" }

Write-Host ""
Write-Host "--- Running Activity ---" -ForegroundColor Yellow
$topActivity = Invoke-Adb @("shell", "dumpsys", "activity", "top")
$resumedLine = ($topActivity -split "`n" | Select-String "ACTIVITY" | Select-Object -First 1)
if ($resumedLine) { Write-Host "  $($resumedLine.ToString().Trim())" }

Write-Host ""
Write-Host "=== Inspection Complete ===" -ForegroundColor Cyan
