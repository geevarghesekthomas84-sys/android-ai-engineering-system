#!/usr/bin/env bash
set -euo pipefail

# Skill Evaluation Runner — Deterministic Checks
# Runs all automated (non-AI) evaluation cases

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0
WARN=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN: $1"; WARN=$((WARN + 1)); }

echo "=================================="
echo "  Skill Evaluation Framework"
echo "  $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "=================================="
echo ""

# --- STRUCT-001: All 14 skills present ---
echo "--- Structure Checks ---"
SKILL_COUNT=$(ls -d "$REPO_ROOT/skills"/*/ 2>/dev/null | wc -l)
if [ "$SKILL_COUNT" -eq 14 ]; then
  pass "STRUCT-001: All 14 skills present ($SKILL_COUNT)"
else
  fail "STRUCT-001: Expected 14 skills, found $SKILL_COUNT"
fi

# --- STRUCT-002: SKILL.md exists ---
ALL_HAVE_SKILL=true
for dir in "$REPO_ROOT/skills"/*/; do
  skill=$(basename "$dir")
  if [ ! -f "$dir/SKILL.md" ]; then
    fail "STRUCT-002: Missing SKILL.md in $skill"
    ALL_HAVE_SKILL=false
  fi
done
$ALL_HAVE_SKILL && pass "STRUCT-002: All skills have SKILL.md"

# --- STRUCT-003: References directory ---
ALL_HAVE_REFS=true
for dir in "$REPO_ROOT/skills"/*/; do
  skill=$(basename "$dir")
  if [ ! -d "$dir/references" ]; then
    fail "STRUCT-003: Missing references/ in $skill"
    ALL_HAVE_REFS=false
  elif [ "$(find "$dir/references" -name '*.md' -type f | wc -l)" -eq 0 ]; then
    fail "STRUCT-003: Empty references/ in $skill"
    ALL_HAVE_REFS=false
  fi
done
$ALL_HAVE_REFS && pass "STRUCT-003: All skills have populated references/"

# --- STRUCT-004: No empty markdown files ---
EMPTY_FILES=$(find "$REPO_ROOT/skills" -name '*.md' -type f -empty 2>/dev/null)
if [ -z "$EMPTY_FILES" ]; then
  pass "STRUCT-004: No empty markdown files"
else
  fail "STRUCT-004: Empty files found: $EMPTY_FILES"
fi

echo ""

# --- CONTENT-001: SKILL.md has heading ---
echo "--- Content Checks ---"
ALL_HAVE_HEADING=true
for dir in "$REPO_ROOT/skills"/*/; do
  file="$dir/SKILL.md"
  [ ! -f "$file" ] && continue
  if ! head -1 "$file" | grep -q '^#'; then
    warn "CONTENT-001: $(basename "$dir")/SKILL.md missing top heading"
    ALL_HAVE_HEADING=false
  fi
done
$ALL_HAVE_HEADING && pass "CONTENT-001: All SKILL.md files have headings"

echo ""

# --- PRIVACY-001: No hardcoded paths ---
echo "--- Privacy Checks ---"
if grep -rq 'C:\\Users\\' "$REPO_ROOT/skills" "$REPO_ROOT/scripts" "$REPO_ROOT/examples" 2>/dev/null; then
  fail "PRIVACY-001: Hardcoded Windows paths found"
else
  pass "PRIVACY-001: No hardcoded Windows paths"
fi

# --- PRIVACY-002: No hardcoded credentials ---
if grep -rq 'demopass123\|dev-secret-change-me' "$REPO_ROOT/skills" "$REPO_ROOT/scripts" "$REPO_ROOT/examples" --include='*.ts' --include='*.kt' --include='*.yml' --include='*.ps1' 2>/dev/null; then
  fail "PRIVACY-002: Hardcoded credentials found"
else
  pass "PRIVACY-002: No hardcoded credentials in code files"
fi

# --- PRIVACY-003: No real API keys ---
if grep -rqE 'sk-[a-zA-Z0-9]{20,}|AIza[a-zA-Z0-9_-]{35}|ghp_[a-zA-Z0-9]{36}|AKIA[0-9A-Z]{16}' "$REPO_ROOT" --include='*.md' --include='*.ts' --include='*.kt' --include='*.yml' --include='*.json' 2>/dev/null; then
  fail "PRIVACY-003: Potential real API keys found"
else
  pass "PRIVACY-003: No real API keys detected"
fi

# --- PRIVACY-004: No personal emails ---
if grep -rqE '@gmail\.com|@hotmail\.com|@outlook\.com|@yahoo\.com' "$REPO_ROOT/skills" "$REPO_ROOT/scripts" "$REPO_ROOT/examples" "$REPO_ROOT/docs" "$REPO_ROOT/README.md" 2>/dev/null; then
  fail "PRIVACY-004: Personal email addresses found"
else
  pass "PRIVACY-004: No personal email addresses"
fi

echo ""

# --- SAFETY ---
echo "--- Safety Checks ---"
if grep -rq 'rm -rf /' "$REPO_ROOT/scripts" 2>/dev/null; then
  fail "SAFETY-001: Dangerous rm -rf / found in scripts"
else
  pass "SAFETY-001: No dangerous delete patterns"
fi

if grep -rqE 'git push (--force|-f).*(main|master)' "$REPO_ROOT/scripts" 2>/dev/null; then
  fail "SAFETY-002: Force push to main/master in scripts"
else
  pass "SAFETY-002: No force push to main/master"
fi

echo ""
echo "=================================="
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "=================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
