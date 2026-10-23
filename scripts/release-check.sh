#!/usr/bin/env bash
set -euo pipefail

# Release Validation Script
# Runs all checks needed before a release

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "======================================"
echo "  Release Validation"
echo "  $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "======================================"
echo ""

# --- VERSION file ---
echo "--- Version Check ---"
if [ -f "$REPO_ROOT/VERSION" ]; then
  VERSION=$(cat "$REPO_ROOT/VERSION" | tr -d '[:space:]')
  if echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    pass "VERSION file: $VERSION"
  else
    fail "VERSION file has invalid format: '$VERSION'"
  fi
else
  fail "VERSION file missing"
fi

# --- Required files ---
echo ""
echo "--- Required Files ---"
for f in README.md LICENSE SECURITY.md CONTRIBUTING.md CHANGELOG.md .gitignore .env.example; do
  if [ -f "$REPO_ROOT/$f" ]; then
    pass "$f exists"
  else
    fail "$f missing"
  fi
done

# --- Skills ---
echo ""
echo "--- Skill Validation ---"
SKILL_COUNT=$(ls -d "$REPO_ROOT/skills"/*/ 2>/dev/null | wc -l)
if [ "$SKILL_COUNT" -eq 14 ]; then
  pass "14 skills present"
else
  fail "Expected 14 skills, found $SKILL_COUNT"
fi

for dir in "$REPO_ROOT/skills"/*/; do
  skill=$(basename "$dir")
  if [ ! -f "$dir/SKILL.md" ]; then
    fail "Missing SKILL.md in $skill"
  fi
  if [ ! -d "$dir/references" ]; then
    fail "Missing references/ in $skill"
  fi
done
pass "All skills have SKILL.md and references/"

# --- CI Workflows ---
echo ""
echo "--- CI Workflows ---"
WORKFLOW_COUNT=$(ls "$REPO_ROOT/.github/workflows/"*.yml 2>/dev/null | wc -l)
if [ "$WORKFLOW_COUNT" -ge 6 ]; then
  pass "$WORKFLOW_COUNT CI workflows present"
else
  fail "Expected at least 6 workflows, found $WORKFLOW_COUNT"
fi

# --- Privacy ---
echo ""
echo "--- Privacy Scan ---"
if grep -rq 'C:\\Users\\' "$REPO_ROOT" --include='*.md' --include='*.ts' --include='*.kt' --include='*.yml' --include='*.ps1' 2>/dev/null; then
  fail "Hardcoded Windows user paths found"
else
  pass "No hardcoded user paths"
fi

if grep -rq 'demopass123\|dev-secret-change-me' "$REPO_ROOT/skills" "$REPO_ROOT/scripts" "$REPO_ROOT/examples" --include='*.ts' --include='*.kt' --include='*.yml' --include='*.ps1' 2>/dev/null; then
  fail "Hardcoded credentials found"
else
  pass "No hardcoded credentials"
fi

# --- Excluded content ---
echo ""
echo "--- Excluded Content ---"
BAD_FILES=$(find "$REPO_ROOT" -not -path '*/.git/*' \( -name '*.apk' -o -name '*.aab' -o -name '*.jks' -o -name '.env' -o -name 'bugreport-*.zip' \) 2>/dev/null || true)
if [ -z "$BAD_FILES" ]; then
  pass "No build artifacts, keystores, .env files, or bugreports"
else
  fail "Excluded files found: $BAD_FILES"
fi

NODE_MODULES=$(find "$REPO_ROOT" -type d -name 'node_modules' -not -path '*/.git/*' 2>/dev/null || true)
if [ -z "$NODE_MODULES" ]; then
  pass "No node_modules directories"
else
  fail "node_modules found: $NODE_MODULES"
fi

# --- Summary ---
echo ""
echo "======================================"
echo "  Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
  echo "  RELEASE READY"
else
  echo "  NOT READY — fix $FAIL issue(s)"
fi
echo "======================================"

if [ "$FAIL" -gt 0 ]; then exit 1; fi
