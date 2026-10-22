param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$BuildType = "Debug",

    [switch]$Clean,

    [switch]$Install
)

$ErrorActionPreference = "Stop"

# Validate project path
if (-not (Test-Path $ProjectPath)) {
    Write-Error "Project path does not exist: $ProjectPath"
    exit 1
}

$ProjectPath = Resolve-Path $ProjectPath

# Check for Gradle wrapper
$gradlew = Join-Path $ProjectPath "gradlew.bat"
if (-not (Test-Path $gradlew)) {
    Write-Error "gradlew.bat not found in $ProjectPath. Is this an Android project?"
    exit 1
}

# Check for build.gradle
$buildGradle = Join-Path $ProjectPath "app\build.gradle.kts"
if (-not (Test-Path $buildGradle)) {
    $buildGradle = Join-Path $ProjectPath "app\build.gradle"
    if (-not (Test-Path $buildGradle)) {
        Write-Error "No build.gradle.kts or build.gradle found in app module."
        exit 1
    }
}

# Ensure ANDROID_HOME is set
if (-not $env:ANDROID_HOME) {
    $sdkPath = "$env:LOCALAPPDATA\Android\Sdk"
    if (Test-Path $sdkPath) {
        $env:ANDROID_HOME = $sdkPath
        Write-Host "Set ANDROID_HOME=$sdkPath" -ForegroundColor Yellow
    } else {
        Write-Error "ANDROID_HOME not set and SDK not found at default location."
        exit 1
    }
}

# Ensure local.properties exists
$localProps = Join-Path $ProjectPath "local.properties"
if (-not (Test-Path $localProps)) {
    $sdkDir = $env:ANDROID_HOME -replace '\\', '\\\\'
    Set-Content -Path $localProps -Value "sdk.dir=$sdkDir" -Encoding utf8
    Write-Host "Created local.properties with sdk.dir" -ForegroundColor Yellow
}

Write-Host "=== Building $BuildType APK ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectPath"
Write-Host ""

$startTime = Get-Date

# Clean if requested
if ($Clean) {
    Write-Host "Cleaning..." -ForegroundColor Yellow
    $cleanResult = & $gradlew clean 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Clean failed:" -ForegroundColor Red
        Write-Host $cleanResult
        exit 1
    }
    Write-Host "Clean complete." -ForegroundColor Green
}

# Build
$task = "assemble$BuildType"
Write-Host "Running: gradlew $task" -ForegroundColor Yellow
$buildOutput = & $gradlew $task --stacktrace 2>&1 | Out-String

if ($LASTEXITCODE -ne 0) {
    Write-Host "BUILD FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host $buildOutput
    exit 1
}

$elapsed = (Get-Date) - $startTime
Write-Host ""
Write-Host "BUILD SUCCESSFUL (${elapsed:mm\:ss})" -ForegroundColor Green

# Find APK
$apkDir = Join-Path $ProjectPath "app\build\outputs\apk\$($BuildType.ToLower())"
$apk = Get-ChildItem $apkDir -Filter "*.apk" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($apk) {
    $sizeMB = [math]::Round($apk.Length / 1MB, 2)
    Write-Host "APK: $($apk.FullName) ($sizeMB MB)" -ForegroundColor Green

    if ($Install) {
        Write-Host ""
        Write-Host "Installing APK..." -ForegroundColor Yellow
        $adbPath = "$env:ANDROID_HOME\platform-tools\adb.exe"
        if (-not (Test-Path $adbPath)) {
            $adbCmd = Get-Command adb -ErrorAction SilentlyContinue
            if ($adbCmd) { $adbPath = $adbCmd.Source }
            else { Write-Warning "ADB not found. Cannot install."; exit 0 }
        }

        $installOutput = & $adbPath install -r $apk.FullName 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Installed successfully." -ForegroundColor Green
        } else {
            Write-Host "Install failed:" -ForegroundColor Red
            Write-Host $installOutput
        }
    }
} else {
    Write-Host "APK not found in expected location: $apkDir" -ForegroundColor Yellow
    Write-Host "Check build output above for the actual APK path."
}
