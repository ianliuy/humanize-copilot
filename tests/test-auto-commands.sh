#!/usr/bin/env bash
#
# Structural tests for gen-idea-auto and gen-plan-auto commands.
#
# Verifies:
# - Windows .cmd shim exists for validate-gen-idea-io
# - commands/*.md frontmatter lists both .sh and .cmd for every required script
# - gen-plan-auto rejects --skip-quiz and --plan-file as documented
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== Auto Commands Tests ==="

# ----------------------------------------------------------------------
# 1. validate-gen-idea-io.cmd exists
# ----------------------------------------------------------------------

echo "--- validate-gen-idea-io .cmd shim ---"

if [[ -f "$REPO_ROOT/scripts/validate-gen-idea-io.cmd" ]]; then
    pass "validate-gen-idea-io.cmd exists"
else
    fail "validate-gen-idea-io.cmd missing"
fi

# ----------------------------------------------------------------------
# 2. gen-idea.md frontmatter has both .sh and .cmd for validate-gen-idea-io
# ----------------------------------------------------------------------

echo "--- gen-idea frontmatter dual-spelling ---"

GEN_IDEA="$REPO_ROOT/commands/gen-idea.md"

if grep -qE 'validate-gen-idea-io\.sh' "$GEN_IDEA"; then
    pass "gen-idea.md has validate-gen-idea-io.sh"
else
    fail "gen-idea.md missing validate-gen-idea-io.sh in allowed-tools"
fi

if grep -qE 'validate-gen-idea-io\.cmd' "$GEN_IDEA"; then
    pass "gen-idea.md has validate-gen-idea-io.cmd"
else
    fail "gen-idea.md missing validate-gen-idea-io.cmd in allowed-tools"
fi

# ----------------------------------------------------------------------
# 3. gen-plan-auto.md frontmatter has required tools (both .sh and .cmd)
# ----------------------------------------------------------------------

echo "--- gen-plan-auto frontmatter required tools ---"

GEN_PLAN_AUTO="$REPO_ROOT/commands/gen-plan-auto.md"

for script in validate-gen-plan-io ask-codex setup-rlcr-loop; do
    if grep -qE "${script}\.sh" "$GEN_PLAN_AUTO"; then
        pass "gen-plan-auto.md has ${script}.sh"
    else
        fail "gen-plan-auto.md missing ${script}.sh in allowed-tools"
    fi
    if grep -qE "${script}\.cmd" "$GEN_PLAN_AUTO"; then
        pass "gen-plan-auto.md has ${script}.cmd"
    else
        fail "gen-plan-auto.md missing ${script}.cmd in allowed-tools"
    fi
done

# ----------------------------------------------------------------------
# 4. gen-idea-auto.md frontmatter has all required tools (both .sh and .cmd)
# ----------------------------------------------------------------------

echo "--- gen-idea-auto frontmatter required tools ---"

GEN_IDEA_AUTO="$REPO_ROOT/commands/gen-idea-auto.md"

for script in validate-gen-idea-io validate-gen-plan-io ask-codex setup-rlcr-loop; do
    if grep -qE "${script}\.sh" "$GEN_IDEA_AUTO"; then
        pass "gen-idea-auto.md has ${script}.sh"
    else
        fail "gen-idea-auto.md missing ${script}.sh in allowed-tools"
    fi
    if grep -qE "${script}\.cmd" "$GEN_IDEA_AUTO"; then
        pass "gen-idea-auto.md has ${script}.cmd"
    else
        fail "gen-idea-auto.md missing ${script}.cmd in allowed-tools"
    fi
done

# ----------------------------------------------------------------------
# 5. gen-plan-auto rejects --skip-quiz
# ----------------------------------------------------------------------

echo "--- gen-plan-auto --skip-quiz rejection ---"

if grep -qi 'reject.*--skip-quiz\|--skip-quiz.*reject\|Reject.*--skip-quiz' "$GEN_PLAN_AUTO"; then
    pass "gen-plan-auto.md documents rejecting --skip-quiz"
else
    fail "gen-plan-auto.md does not mention rejecting --skip-quiz"
fi

# ----------------------------------------------------------------------
# 6. gen-plan-auto rejects --plan-file
# ----------------------------------------------------------------------

echo "--- gen-plan-auto --plan-file rejection ---"

if grep -qi 'reject.*--plan-file\|--plan-file.*reject\|Reject.*--plan-file' "$GEN_PLAN_AUTO"; then
    pass "gen-plan-auto.md documents rejecting --plan-file"
else
    fail "gen-plan-auto.md does not mention rejecting --plan-file"
fi

# ----------------------------------------------------------------------
# 7. gen-plan-auto documents all RLCR pass-through args
# ----------------------------------------------------------------------

echo "--- gen-plan-auto RLCR pass-through args ---"

for arg in "--max" "--codex-model" "--codex-timeout" "--track-plan-file" "--push-every-round" "--base-branch" "--full-review-round" "--skip-impl" "--claude-answer-codex" "--agent-teams" "--yolo"; do
    if grep -q -- "$arg" "$REPO_ROOT/commands/gen-plan-auto.md"; then
        pass "gen-plan-auto documents $arg"
    else
        fail "gen-plan-auto missing $arg"
    fi
done

# ----------------------------------------------------------------------
# 8. gen-idea-auto documents --plan-output
# ----------------------------------------------------------------------

echo "--- gen-idea-auto --plan-output ---"

if grep -q -- "--plan-output" "$REPO_ROOT/commands/gen-idea-auto.md"; then
    pass "gen-idea-auto documents --plan-output"
else
    fail "gen-idea-auto missing --plan-output"
fi

# ----------------------------------------------------------------------
# 9. gen-idea-auto creates session dir
# ----------------------------------------------------------------------

echo "--- gen-idea-auto session dir ---"

if grep -q "idea-plan-auto" "$REPO_ROOT/commands/gen-idea-auto.md"; then
    pass "gen-idea-auto references session dir"
else
    fail "gen-idea-auto missing session dir reference"
fi

# ----------------------------------------------------------------------
# 10. gen-plan-auto Recommended-First rule
# ----------------------------------------------------------------------

echo "--- gen-plan-auto Recommended-First rule ---"

if grep -q "Recommended" "$REPO_ROOT/commands/gen-plan-auto.md"; then
    pass "gen-plan-auto has Recommended-First rule"
else
    fail "gen-plan-auto missing Recommended-First rule"
fi

# ======================================================================
# Behavioral tests — actually execute scripts and check exit codes
# ======================================================================

echo "--- Behavioral: validate-gen-idea-io ---"

# Behavioral test: validate-gen-idea-io.sh rejects missing input
echo "=== Behavioral: validate-gen-idea-io rejects empty input ==="
exit_code=0
result=$(bash "$REPO_ROOT/scripts/validate-gen-idea-io.sh" 2>&1) || exit_code=$?
if [[ "${exit_code}" -eq 1 ]] || [[ "$result" == *"MISSING_IDEA"* ]]; then
    pass "validate-gen-idea-io rejects empty input (exit $exit_code)"
else
    fail "validate-gen-idea-io should reject empty input (got exit $exit_code)"
fi

# Behavioral test: validate-gen-idea-io.sh rejects invalid --n
echo "=== Behavioral: validate-gen-idea-io rejects --n 0 ==="
exit_code=0
result=$(bash "$REPO_ROOT/scripts/validate-gen-idea-io.sh" --n 0 "test idea" 2>&1) || exit_code=$?
if [[ "${exit_code}" -eq 6 ]] || [[ "$result" == *"N_OUT_OF_RANGE"* ]]; then
    pass "validate-gen-idea-io rejects --n 0 (exit $exit_code)"
else
    fail "validate-gen-idea-io should reject --n 0 (got exit $exit_code)"
fi

# Behavioral test: validate-gen-idea-io.sh accepts valid inline idea
echo "=== Behavioral: validate-gen-idea-io accepts valid inline idea ==="
exit_code=0
result=$(bash "$REPO_ROOT/scripts/validate-gen-idea-io.sh" "test idea for auto commands" 2>&1) || exit_code=$?
if [[ "${exit_code}" -eq 0 ]] && [[ "$result" == *"VALIDATION_SUCCESS"* ]]; then
    pass "validate-gen-idea-io accepts valid inline idea"
else
    fail "validate-gen-idea-io should accept valid inline idea (exit $exit_code)"
fi

# Behavioral test: validate-gen-idea-io.sh output path handling
echo "=== Behavioral: validate-gen-idea-io handles output path ==="
exit_code=0
_test_output="/tmp/humanize-test-existing-$(date +%s).md"
result=$(bash "$REPO_ROOT/scripts/validate-gen-idea-io.sh" "test" --output "$_test_output" 2>&1) || exit_code=$?
if [[ "${exit_code}" -eq 0 ]] || [[ "${exit_code}" -eq 4 ]]; then
    pass "validate-gen-idea-io handles output path (exit $exit_code)"
else
    fail "validate-gen-idea-io output path handling (exit $exit_code)"
fi
# Clean up temp files from behavioral tests
rm -f "$_test_output" 2>/dev/null || true

echo ""
echo "=== Auto Command Behavioral Harness Tests ==="

# Create a temp harness directory
HARNESS_DIR=$(mktemp -d)
trap "rm -rf '$HARNESS_DIR'" EXIT

# Test: gen-plan-auto documents RLCR arg stripping
# The command body must mention stripping/separating RLCR args before gen-plan validation
echo "--- RLCR arg stripping ---"
if grep -q "RLCR pass-through" "$REPO_ROOT/commands/gen-plan-auto.md" && \
   grep -q "stripped\|strip\|partition\|separate" "$REPO_ROOT/commands/gen-plan-auto.md"; then
    pass "gen-plan-auto documents RLCR arg partitioning/stripping"
else
    fail "gen-plan-auto missing RLCR arg stripping documentation"
fi

# Test: gen-plan-auto documents last-value-wins for duplicates
if grep -qi "last.*win\|duplicate.*last\|Duplicate.*last" "$REPO_ROOT/commands/gen-plan-auto.md"; then
    pass "gen-plan-auto documents duplicate flag handling (last value wins)"
else
    fail "gen-plan-auto missing duplicate flag handling"
fi

# Test: gen-plan-auto has "No" branch with manual command
if grep -q 'No.*let me review\|No.*review the plan' "$REPO_ROOT/commands/gen-plan-auto.md" && \
   grep -q 'start-rlcr-loop' "$REPO_ROOT/commands/gen-plan-auto.md"; then
    pass "gen-plan-auto has No branch with manual RLCR command"
else
    fail "gen-plan-auto missing No branch with manual command"
fi

# Test: gen-idea-auto creates session dir under .humanize/idea-plan-auto/
if grep -q 'idea-plan-auto' "$REPO_ROOT/commands/gen-idea-auto.md" && \
   grep -q 'mkdir' "$REPO_ROOT/commands/gen-idea-auto.md"; then
    pass "gen-idea-auto creates session directory"
else
    fail "gen-idea-auto missing session directory creation"
fi

# Test: gen-idea-auto safe cleanup (guards against rm -rf)
if grep -q 'SESSION_DIR_CREATED_BY_US\|created.*by.*this\|created by this invocation' "$REPO_ROOT/commands/gen-idea-auto.md" && \
   grep -qi 'Do not.*rm -rf\|no.*rm -rf\|never.*rm -rf' "$REPO_ROOT/commands/gen-idea-auto.md"; then
    pass "gen-idea-auto uses safe cleanup (documents rm -rf prohibition)"
else
    fail "gen-idea-auto cleanup may be unsafe"
fi

# Test: gen-idea-auto rejects --plan-file
if grep -q '\-\-plan-file.*reject\|Reject.*\-\-plan-file' "$REPO_ROOT/commands/gen-idea-auto.md"; then
    pass "gen-idea-auto rejects --plan-file"
else
    fail "gen-idea-auto missing --plan-file rejection"
fi

# Test: gen-idea-auto has --plan-output arg
if grep -q '\-\-plan-output' "$REPO_ROOT/commands/gen-idea-auto.md"; then
    pass "gen-idea-auto supports --plan-output"
else
    fail "gen-idea-auto missing --plan-output"
fi

# Test: gen-plan-auto AskUserQuestion has Recommended
if grep -q 'Recommended' "$REPO_ROOT/commands/gen-plan-auto.md" && \
   grep -q 'Yes.*start.*implementation.*(Recommended)' "$REPO_ROOT/commands/gen-plan-auto.md"; then
    pass "gen-plan-auto pre-RLCR confirmation has Yes (Recommended)"
else
    fail "gen-plan-auto missing Yes (Recommended) in pre-RLCR"
fi

# Test: validate-gen-idea-io.sh handles --output to non-existent dir
NONEXIST_DIR="/tmp/humanize-test-nonexist-$(date +%s)"
exit_code=0
result=$(bash "$REPO_ROOT/scripts/validate-gen-idea-io.sh" "test idea" --output "$NONEXIST_DIR/idea.md" 2>&1) || exit_code=$?
if [[ "${exit_code}" -eq 3 ]] || [[ "$result" == *"OUTPUT_DIR_NOT_FOUND"* ]]; then
    pass "validate-gen-idea-io rejects non-existent output dir (exit 3)"
else
    fail "validate-gen-idea-io should reject non-existent output dir (got exit ${exit_code})"
fi

# Test: validate-gen-idea-io.sh handles existing output file
EXISTING_FILE="/tmp/humanize-test-existing-$(date +%s).md"
echo "existing" > "$EXISTING_FILE"
exit_code=0
result=$(bash "$REPO_ROOT/scripts/validate-gen-idea-io.sh" "test idea" --output "$EXISTING_FILE" 2>&1) || exit_code=$?
rm -f "$EXISTING_FILE"
if [[ "${exit_code}" -eq 4 ]] || [[ "$result" == *"OUTPUT_EXISTS"* ]]; then
    pass "validate-gen-idea-io rejects existing output file (exit 4)"
else
    fail "validate-gen-idea-io should reject existing output file (got exit ${exit_code})"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
