param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [switch]$Instrumented,

    [string]$TestClass,

    [switch]$Verbose
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
    Write-Error "gradlew.bat not found in $ProjectPath."
    exit 1
}

# Ensure ANDROID_HOME is set
if (-not $env:ANDROID_HOME) {
    $sdkPath = "$env:LOCALAPPDATA\Android\Sdk"
    if (Test-Path $sdkPath) {
        $env:ANDROID_HOME = $sdkPath
    }
}

# Ensure local.properties
$localProps = Join-Path $ProjectPath "local.properties"
if (-not (Test-Path $localProps)) {
    if ($env:ANDROID_HOME) {
        $sdkDir = $env:ANDROID_HOME -replace '\\', '\\\\'
        Set-Content -Path $localProps -Value "sdk.dir=$sdkDir" -Encoding utf8
    }
}

$startTime = Get-Date

if ($Instrumented) {
    Write-Host "=== Running Instrumentation Tests ===" -ForegroundColor Cyan

    # Check for connected device
    $adbPath = if ($env:ANDROID_HOME) { "$env:ANDROID_HOME\platform-tools\adb.exe" } else { "adb" }
    try {
        $devices = & $adbPath devices 2>&1 | Select-String "device$"
        if (-not $devices) {
            Write-Error "No connected device or emulator found. Instrumentation tests require a device."
            exit 1
        }
        Write-Host "Device found: $($devices -join ', ')" -ForegroundColor Gray
    } catch {
        Write-Warning "Could not check for devices. Proceeding anyway..."
    }

    $task = "connectedAndroidTest"
    if ($TestClass) {
        $args = @($task, "-Pandroid.testInstrumentationRunnerArguments.class=$TestClass")
    } else {
        $args = @($task)
    }
} else {
    Write-Host "=== Running Unit Tests ===" -ForegroundColor Cyan

    $task = "test"
    if ($TestClass) {
        $args = @($task, "--tests", $TestClass)
    } else {
        $args = @($task)
    }
}

if ($Verbose) { $args += "--info" }
$args += "--stacktrace"

Write-Host "Running: gradlew $($args -join ' ')" -ForegroundColor Yellow
Write-Host ""

$output = & $gradlew @args 2>&1 | Out-String
$exitCode = $LASTEXITCODE

$elapsed = (Get-Date) - $startTime

Write-Host $output

if ($exitCode -eq 0) {
    Write-Host ""
    Write-Host "ALL TESTS PASSED (${elapsed:mm\:ss})" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "TESTS FAILED (${elapsed:mm\:ss})" -ForegroundColor Red
}

# Show report location
if ($Instrumented) {
    $reportPath = Join-Path $ProjectPath "app\build\reports\androidTests\connected\index.html"
} else {
    $reportPath = Join-Path $ProjectPath "app\build\reports\tests\testDebugUnitTest\index.html"
}

if (Test-Path $reportPath) {
    Write-Host "Test report: $reportPath" -ForegroundColor Cyan
}

exit $exitCode
