# validate-v3-skills.ps1
# Validates all v3.0 Android AI Engineering System skills
# Run: powershell -ExecutionPolicy Bypass -File validate-v3-skills.ps1

$ErrorActionPreference = 'Continue'
$skillsDir = "$env:USERPROFILE\.claude\skills"
$passed = 0
$failed = 0
$warnings = 0

$v3Skills = @(
    'android-cli',
    'android-ui-ux-design',
    'android-frontend-engineer',
    'android-testing-engineer',
    'app-performance-engineer',
    'backend-api-engineer',
    'database-offline-sync',
    'firebase-supabase-engineer',
    'android-security-engineer',
    'android-security-lab-builder',
    'devops-release-engineer',
    'ai-integration-engineer',
    'app-product-architect',
    'fullstack-web-engineer'
)

$expectedRefs = @{
    'android-cli' = 12
    'android-ui-ux-design' = 7
    'android-frontend-engineer' = 7
    'android-testing-engineer' = 7
    'app-performance-engineer' = 6
    'backend-api-engineer' = 7
    'database-offline-sync' = 7
    'firebase-supabase-engineer' = 7
    'android-security-engineer' = 7
    'android-security-lab-builder' = 7
    'devops-release-engineer' = 7
    'ai-integration-engineer' = 7
    'app-product-architect' = 7
    'fullstack-web-engineer' = 7
}

Write-Host ""
Write-Host "=== Android AI Engineering System v3.0 Skill Validation ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Skills directory: $skillsDir"
Write-Host ""

foreach ($skill in $v3Skills) {
    $skillPath = Join-Path $skillsDir $skill
    $skillMd = Join-Path $skillPath 'SKILL.md'
    $refsDir = Join-Path $skillPath 'references'

    Write-Host "--- $skill ---" -ForegroundColor Yellow

    if (-not (Test-Path $skillMd)) {
        Write-Host "  FAIL: SKILL.md not found" -ForegroundColor Red
        $failed++
        continue
    }

    $content = Get-Content $skillMd -Raw
    if ($content -match '(?s)^---\r?\n(.+?)\r?\n---') {
        Write-Host "  PASS: Valid YAML frontmatter" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "  FAIL: No valid frontmatter" -ForegroundColor Red
        $failed++
    }

    if (Test-Path $refsDir) {
        $refCount = (Get-ChildItem $refsDir -File).Count
        $expected = $expectedRefs[$skill]
        if ($refCount -ge $expected) {
            Write-Host "  PASS: $refCount references (expected $expected)" -ForegroundColor Green
            $passed++
        }
        else {
            Write-Host "  WARN: $refCount references (expected $expected)" -ForegroundColor DarkYellow
            $warnings++
        }
    }
    else {
        if ($skill -ne 'android-cli') {
            Write-Host "  FAIL: No references/ directory" -ForegroundColor Red
            $failed++
        }
    }

    $emptyFiles = Get-ChildItem $skillPath -Recurse -File | Where-Object { $_.Length -eq 0 }
    if ($emptyFiles.Count -gt 0) {
        Write-Host "  WARN: $($emptyFiles.Count) empty files" -ForegroundColor DarkYellow
        $warnings++
    }
    else {
        Write-Host "  PASS: No empty files" -ForegroundColor Green
        $passed++
    }
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Skills validated: $($v3Skills.Count)"
Write-Host "Passed: $passed" -ForegroundColor Green

if ($failed -gt 0) {
    Write-Host "Failed: $failed" -ForegroundColor Red
}
else {
    Write-Host "Failed: $failed" -ForegroundColor Green
}

if ($warnings -gt 0) {
    Write-Host "Warnings: $warnings" -ForegroundColor DarkYellow
}
else {
    Write-Host "Warnings: $warnings" -ForegroundColor Green
}

if ($failed -eq 0) {
    Write-Host ""
    Write-Host "All skills VALIDATED." -ForegroundColor Green
    exit 0
}
else {
    Write-Host ""
    Write-Host "Validation FAILED - $failed issues found." -ForegroundColor Red
    exit 1
}
