param(
    [switch]$Quiet
)

$results = @()

function Test-Tool {
    param([string]$Name, [string[]]$Paths, [string]$VersionCmd)

    foreach ($p in $Paths) {
        if (Test-Path $p) {
            $version = ""
            if ($VersionCmd) {
                try { $version = & cmd.exe /c "`"$p`" $VersionCmd" 2>&1 | Select-Object -First 1 } catch {}
            }
            return @{ Name = $Name; Status = "OK"; Path = $p; Version = $version }
        }
    }

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        $version = ""
        if ($VersionCmd) {
            try { $version = & $cmd.Source $VersionCmd.Split(' ') 2>&1 | Select-Object -First 1 } catch {}
        }
        return @{ Name = $Name; Status = "OK"; Path = $cmd.Source; Version = $version }
    }

    return @{ Name = $Name; Status = "MISSING"; Path = ""; Version = "" }
}

$sdkPath = if ($env:ANDROID_HOME) { $env:ANDROID_HOME }
           elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
           else { "$env:LOCALAPPDATA\Android\Sdk" }

Write-Host "=== Android Development Environment Check ===" -ForegroundColor Cyan
Write-Host ""

# Android SDK
if (Test-Path $sdkPath) {
    Write-Host "[OK]     Android SDK: $sdkPath" -ForegroundColor Green

    # Build tools
    $buildTools = Get-ChildItem "$sdkPath\build-tools" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    if ($buildTools) {
        Write-Host "         Build Tools: $($buildTools.Name -join ', ')" -ForegroundColor Gray
    } else {
        Write-Host "[WARN]   No build tools installed" -ForegroundColor Yellow
    }

    # Platforms
    $platforms = Get-ChildItem "$sdkPath\platforms" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    if ($platforms) {
        Write-Host "         Platforms:   $($platforms.Name -join ', ')" -ForegroundColor Gray
    } else {
        Write-Host "[WARN]   No platforms installed" -ForegroundColor Yellow
    }

    # System images
    $images = Get-ChildItem "$sdkPath\system-images" -Directory -ErrorAction SilentlyContinue
    if ($images) {
        Write-Host "         Images:      $($images.Name -join ', ')" -ForegroundColor Gray
    }
} else {
    Write-Host "[MISSING] Android SDK not found at: $sdkPath" -ForegroundColor Red
    Write-Host "          Set ANDROID_HOME or install SDK" -ForegroundColor Yellow
}

Write-Host ""

# Java
$javaResult = Test-Tool -Name "java" -Paths @() -VersionCmd "-version"
if ($javaResult.Status -eq "OK") {
    Write-Host "[OK]     Java: $($javaResult.Path)" -ForegroundColor Green
    Write-Host "         $($javaResult.Version)" -ForegroundColor Gray
} else {
    Write-Host "[MISSING] Java not found" -ForegroundColor Red
}

if ($env:JAVA_HOME -and (Test-Path $env:JAVA_HOME)) {
    Write-Host "         JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Gray
} else {
    Write-Host "[WARN]   JAVA_HOME not set" -ForegroundColor Yellow
}

Write-Host ""

# Android CLI
$androidResult = Test-Tool -Name "android" -Paths @() -VersionCmd "--version"
if ($androidResult.Status -eq "OK") {
    Write-Host "[OK]     Android CLI: $($androidResult.Path)" -ForegroundColor Green
} else {
    Write-Host "[MISSING] Android CLI not in PATH" -ForegroundColor Yellow
    Write-Host "          Install: curl -fsSL https://dl.google.com/android/cli/latest/windows_x86_64/install.cmd -o `"%TEMP%\i.cmd`" && `"%TEMP%\i.cmd`"" -ForegroundColor Gray
}

# ADB
$adbPaths = @(
    "$sdkPath\platform-tools\adb.exe",
    "$env:USERPROFILE\Downloads\platform-tools-latest-windows\platform-tools\adb.exe"
)
$adbResult = Test-Tool -Name "adb" -Paths $adbPaths -VersionCmd "version"
if ($adbResult.Status -eq "OK") {
    Write-Host "[OK]     ADB: $($adbResult.Path)" -ForegroundColor Green
    # Check for connected devices
    try {
        $devices = & $adbResult.Path devices 2>&1 | Select-String "device$|emulator"
        if ($devices) {
            Write-Host "         Connected devices:" -ForegroundColor Gray
            $devices | ForEach-Object { Write-Host "           $_" -ForegroundColor Gray }
        } else {
            Write-Host "         No devices connected" -ForegroundColor Gray
        }
    } catch {}
} else {
    Write-Host "[MISSING] ADB not found" -ForegroundColor Red
}

# Emulator
$emulatorResult = Test-Tool -Name "emulator" -Paths @("$sdkPath\emulator\emulator.exe")
if ($emulatorResult.Status -eq "OK") {
    Write-Host "[OK]     Emulator: $($emulatorResult.Path)" -ForegroundColor Green
    try {
        $avds = & $emulatorResult.Path -list-avds 2>&1
        if ($avds -and $avds[0] -notmatch "error") {
            Write-Host "         AVDs: $($avds -join ', ')" -ForegroundColor Gray
        }
    } catch {}
} else {
    Write-Host "[MISSING] Emulator not found" -ForegroundColor Yellow
}

# sdkmanager
$sdkmgrPaths = @("$sdkPath\cmdline-tools\latest\bin\sdkmanager.bat")
$sdkmgrResult = Test-Tool -Name "sdkmanager" -Paths $sdkmgrPaths -VersionCmd "--version"
if ($sdkmgrResult.Status -eq "OK") {
    Write-Host "[OK]     SDK Manager: $($sdkmgrResult.Path)" -ForegroundColor Green
} else {
    Write-Host "[MISSING] SDK Manager not found" -ForegroundColor Yellow
}

# Android Studio
$studioPath = "C:\Program Files\Android\Android Studio"
if (Test-Path $studioPath) {
    Write-Host "[OK]     Android Studio: $studioPath" -ForegroundColor Green
} else {
    Write-Host "[INFO]   Android Studio not found at standard path" -ForegroundColor Gray
}

Write-Host ""

# Environment variables
Write-Host "=== Environment Variables ===" -ForegroundColor Cyan
$envVars = @("ANDROID_HOME", "ANDROID_SDK_ROOT", "JAVA_HOME")
foreach ($var in $envVars) {
    $val = [Environment]::GetEnvironmentVariable($var)
    if ($val) {
        Write-Host "[SET]    $var = $val" -ForegroundColor Green
    } else {
        Write-Host "[UNSET]  $var" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Check Complete ===" -ForegroundColor Cyan
