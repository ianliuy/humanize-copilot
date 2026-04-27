#!/bin/bash
# Tests for model-router.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
source "$PROJECT_ROOT/scripts/lib/model-router.sh"

SAFE_BASE_PATH="/usr/bin:/bin:/usr/sbin:/sbin"

# Source loop-common.sh for detect_review_cli tests
source "$PROJECT_ROOT/hooks/lib/loop-common.sh"

echo "=========================================="
echo "Model Router Tests"
echo "=========================================="
echo ""

create_mock_binary() {
    local bin_dir="$1"
    local binary_name="$2"

    mkdir -p "$bin_dir"
    cat > "$bin_dir/$binary_name" <<EOF
#!/bin/bash
exit 0
EOF
    chmod +x "$bin_dir/$binary_name"
}

create_mock_copilot() {
    local bin_dir="$1"
    mkdir -p "$bin_dir"
    cat > "$bin_dir/copilot" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$bin_dir/copilot"
}

# ========================================
# Test 1: gpt-5.3-codex routes to codex
# ========================================
echo "--- Test 1: gpt-5.3-codex routes to codex ---"
echo ""

result=""
exit_code=0
result=$(detect_provider "gpt-5.3-codex" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "codex" ]]; then
    pass "detect_provider: gpt-5.3-codex returns codex"
else
    fail "detect_provider: gpt-5.3-codex returns codex" "exit 0 + codex" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 2: gpt-4o routes to codex
# ========================================
echo ""
echo "--- Test 2: gpt-4o routes to codex ---"
echo ""

result=""
exit_code=0
result=$(detect_provider "gpt-4o" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "codex" ]]; then
    pass "detect_provider: gpt-4o returns codex"
else
    fail "detect_provider: gpt-4o returns codex" "exit 0 + codex" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 2a: o3-mini routes to codex
# ========================================
echo ""
echo "--- Test 2a: o3-mini routes to codex ---"
echo ""

result=""
exit_code=0
result=$(detect_provider "o3-mini" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "codex" ]]; then
    pass "detect_provider: o3-mini returns codex"
else
    fail "detect_provider: o3-mini returns codex" "exit 0 + codex" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 2b: o1-pro routes to codex
# ========================================
echo ""
echo "--- Test 2b: o1-pro routes to codex ---"
echo ""

result=""
exit_code=0
result=$(detect_provider "o1-pro" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "codex" ]]; then
    pass "detect_provider: o1-pro returns codex"
else
    fail "detect_provider: o1-pro returns codex" "exit 0 + codex" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 3: o4-mini routes to codex
# ========================================
echo ""
echo "--- Test 3: o4-mini routes to codex ---"
echo ""

result=""
exit_code=0
result=$(detect_provider "o4-mini" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "codex" ]]; then
    pass "detect_provider: o4-mini returns codex"
else
    fail "detect_provider: o4-mini returns codex" "exit 0 + codex" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 4: haiku routes to claude
# ========================================
echo ""
echo "--- Test 4: haiku routes to claude ---"
echo ""

result=""
exit_code=0
result=$(detect_provider "haiku" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "claude" ]]; then
    pass "detect_provider: haiku returns claude"
else
    fail "detect_provider: haiku returns claude" "exit 0 + claude" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 5: sonnet routes to claude
# ========================================
echo ""
echo "--- Test 5: sonnet routes to claude ---"
echo ""

result=""
exit_code=0
result=$(detect_provider "sonnet" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "claude" ]]; then
    pass "detect_provider: sonnet returns claude"
else
    fail "detect_provider: sonnet returns claude" "exit 0 + claude" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 6: opus routes to claude
# ========================================
echo ""
echo "--- Test 6: opus routes to claude ---"
echo ""

result=""
exit_code=0
result=$(detect_provider "opus" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "claude" ]]; then
    pass "detect_provider: opus returns claude"
else
    fail "detect_provider: opus returns claude" "exit 0 + claude" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 7: claude-sonnet-4-6 routes to claude
# ========================================
echo ""
echo "--- Test 7: claude-sonnet-4-6 routes to claude ---"
echo ""

result=""
exit_code=0
result=$(detect_provider "claude-sonnet-4-6" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "claude" ]]; then
    pass "detect_provider: claude-sonnet-4-6 returns claude"
else
    fail "detect_provider: claude-sonnet-4-6 returns claude" "exit 0 + claude" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 8: claude-3-OPUS-20240229 routes to claude
# ========================================
echo ""
echo "--- Test 8: claude-3-OPUS-20240229 routes to claude ---"
echo ""

result=""
exit_code=0
result=$(detect_provider "claude-3-OPUS-20240229" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "claude" ]]; then
    pass "detect_provider: claude-3-OPUS-20240229 returns claude"
else
    fail "detect_provider: claude-3-OPUS-20240229 returns claude" "exit 0 + claude" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 9: unknown model exits non-zero
# ========================================
echo ""
echo "--- Test 9: unknown model exits non-zero ---"
echo ""

exit_code=0
stderr_out=""
stderr_out=$(detect_provider "unknown-xyz" 2>&1 >/dev/null) || exit_code=$?

if [[ $exit_code -ne 0 ]] && echo "$stderr_out" | grep -qiE "unknown|error"; then
    pass "detect_provider: unknown model exits non-zero with error"
else
    fail "detect_provider: unknown model exits non-zero with error" "non-zero exit + error message" "exit=$exit_code, stderr=$stderr_out"
fi

# ========================================
# Test 10: empty model exits non-zero
# ========================================
echo ""
echo "--- Test 10: empty model exits non-zero ---"
echo ""

exit_code=0
stderr_out=""
stderr_out=$(detect_provider "" 2>&1 >/dev/null) || exit_code=$?

if [[ $exit_code -ne 0 ]] && echo "$stderr_out" | grep -qiE "non-empty|error"; then
    pass "detect_provider: empty model exits non-zero with error"
else
    fail "detect_provider: empty model exits non-zero with error" "non-zero exit + error message" "exit=$exit_code, stderr=$stderr_out"
fi

# ========================================
# Test 10: codex dependency succeeds when codex is in PATH
# ========================================
echo ""
echo "--- Test 10: codex dependency succeeds with mock binary ---"
echo ""

setup_test_dir
BIN_DIR="$TEST_DIR/bin"
create_mock_binary "$BIN_DIR" "codex"

if PATH="$BIN_DIR:$SAFE_BASE_PATH" check_provider_dependency "codex" >/dev/null 2>&1; then
    pass "check_provider_dependency: codex succeeds when mock codex is in PATH"
else
    fail "check_provider_dependency: codex succeeds when mock codex is in PATH" "exit 0" "non-zero exit"
fi

# ========================================
# Test 11: codex dependency fails when codex is not in PATH
# ========================================
echo ""
echo "--- Test 11: codex dependency fails without codex ---"
echo ""

exit_code=0
stderr_out=""
stderr_out=$(PATH="$SAFE_BASE_PATH" check_provider_dependency "codex" 2>&1 >/dev/null) || exit_code=$?

if [[ $exit_code -ne 0 ]] && echo "$stderr_out" | grep -qi "codex"; then
    pass "check_provider_dependency: codex fails when codex is missing"
else
    fail "check_provider_dependency: codex fails when codex is missing" "non-zero exit + codex in stderr" "exit=$exit_code, stderr=$stderr_out"
fi

# ========================================
# Test 12: claude dependency succeeds when claude is in PATH
# ========================================
echo ""
echo "--- Test 12: claude dependency succeeds with mock binary ---"
echo ""

setup_test_dir
BIN_DIR="$TEST_DIR/bin"
create_mock_binary "$BIN_DIR" "claude"

if PATH="$BIN_DIR:$SAFE_BASE_PATH" check_provider_dependency "claude" >/dev/null 2>&1; then
    pass "check_provider_dependency: claude succeeds when mock claude is in PATH"
else
    fail "check_provider_dependency: claude succeeds when mock claude is in PATH" "exit 0" "non-zero exit"
fi

# ========================================
# Test 13: claude dependency fails when claude is not in PATH
# ========================================
echo ""
echo "--- Test 13: claude dependency fails without claude ---"
echo ""

exit_code=0
stderr_out=""
stderr_out=$(PATH="$SAFE_BASE_PATH" check_provider_dependency "claude" 2>&1 >/dev/null) || exit_code=$?

if [[ $exit_code -ne 0 ]] && echo "$stderr_out" | grep -qi "claude"; then
    pass "check_provider_dependency: claude fails when claude is missing"
else
    fail "check_provider_dependency: claude fails when claude is missing" "non-zero exit + claude in stderr" "exit=$exit_code, stderr=$stderr_out"
fi

# ========================================
# Test 14: xhigh maps to high for claude
# ========================================
echo ""
echo "--- Test 14: xhigh maps to high for claude ---"
echo ""

setup_test_dir
result=""
stderr_out=""
exit_code=0
result=$(map_effort "xhigh" "claude" 2> "$TEST_DIR/map-effort-stderr.txt") || exit_code=$?
stderr_out="$(cat "$TEST_DIR/map-effort-stderr.txt")"

if [[ $exit_code -eq 0 ]] && [[ "$result" == "high" ]] && echo "$stderr_out" | grep -qiE "mapping effort|xhigh|high"; then
    pass "map_effort: xhigh maps to high for claude with info log"
else
    fail "map_effort: xhigh maps to high for claude with info log" "exit 0 + high + info log" "exit=$exit_code, output=$result, stderr=$stderr_out"
fi

# ========================================
# Test 15: high passes through for codex
# ========================================
echo ""
echo "--- Test 15: high passes through for codex ---"
echo ""

result=""
exit_code=0
result=$(map_effort "high" "codex" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "high" ]]; then
    pass "map_effort: high passes through for codex"
else
    fail "map_effort: high passes through for codex" "exit 0 + high" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 16: xhigh passes through for codex
# ========================================
echo ""
echo "--- Test 16: xhigh passes through for codex ---"
echo ""

result=""
exit_code=0
result=$(map_effort "xhigh" "codex" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "xhigh" ]]; then
    pass "map_effort: xhigh passes through for codex"
else
    fail "map_effort: xhigh passes through for codex" "exit 0 + xhigh" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 17: medium passes through for claude
# ========================================
echo ""
echo "--- Test 17: medium passes through for claude ---"
echo ""

result=""
exit_code=0
result=$(map_effort "medium" "claude" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "medium" ]]; then
    pass "map_effort: medium passes through for claude"
else
    fail "map_effort: medium passes through for claude" "exit 0 + medium" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 18: low passes through for claude
# ========================================
echo ""
echo "--- Test 18: low passes through for claude ---"
echo ""

result=""
exit_code=0
result=$(map_effort "low" "claude" 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "low" ]]; then
    pass "map_effort: low passes through for claude"
else
    fail "map_effort: low passes through for claude" "exit 0 + low" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 19: unknown claude effort exits non-zero
# ========================================
echo ""
echo "--- Test 19: unknown claude effort exits non-zero ---"
echo ""

exit_code=0
stderr_out=""
stderr_out=$(map_effort "ultra" "claude" 2>&1 >/dev/null) || exit_code=$?

if [[ $exit_code -ne 0 ]] && echo "$stderr_out" | grep -qiE "unknown effort|error"; then
    pass "map_effort: unknown claude effort exits non-zero with error"
else
    fail "map_effort: unknown claude effort exits non-zero with error" "non-zero exit + error message" "exit=$exit_code, stderr=$stderr_out"
fi

# ========================================
# Test 20: unknown codex effort exits non-zero
# ========================================
echo ""
echo "--- Test 20: unknown codex effort exits non-zero ---"
echo ""

exit_code=0
stderr_out=""
stderr_out=$(map_effort "ultra" "codex" 2>&1 >/dev/null) || exit_code=$?

if [[ $exit_code -ne 0 ]] && echo "$stderr_out" | grep -qiE "unknown effort|error"; then
    pass "map_effort: unknown codex effort exits non-zero with error"
else
    fail "map_effort: unknown codex effort exits non-zero with error" "non-zero exit + error message" "exit=$exit_code, stderr=$stderr_out"
fi

# ========================================
# Test 21: detect_review_cli returns copilot when both on PATH
# ========================================
echo ""
echo "--- Test 21: detect_review_cli returns copilot when both on PATH ---"
echo ""

setup_test_dir
BIN_DIR="$TEST_DIR/bin"
create_mock_copilot "$BIN_DIR"
create_mock_binary "$BIN_DIR" "codex"

result=""
exit_code=0
result=$(PATH="$BIN_DIR:$SAFE_BASE_PATH" detect_review_cli 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "copilot" ]]; then
    pass "detect_review_cli: both on PATH returns copilot"
else
    fail "detect_review_cli: both on PATH returns copilot" "exit 0 + copilot" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 22: detect_review_cli returns copilot when only copilot on PATH
# ========================================
echo ""
echo "--- Test 22: detect_review_cli returns copilot when only copilot ---"
echo ""

setup_test_dir
BIN_DIR="$TEST_DIR/bin"
create_mock_copilot "$BIN_DIR"

result=""
exit_code=0
result=$(PATH="$BIN_DIR:$SAFE_BASE_PATH" detect_review_cli 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "copilot" ]]; then
    pass "detect_review_cli: only copilot returns copilot"
else
    fail "detect_review_cli: only copilot returns copilot" "exit 0 + copilot" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 23: detect_review_cli returns codex when only codex on PATH
# ========================================
echo ""
echo "--- Test 23: detect_review_cli returns codex when only codex ---"
echo ""

setup_test_dir
BIN_DIR="$TEST_DIR/bin"
create_mock_binary "$BIN_DIR" "codex"

result=""
exit_code=0
result=$(PATH="$BIN_DIR:$SAFE_BASE_PATH" detect_review_cli 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "codex" ]]; then
    pass "detect_review_cli: only codex returns codex"
else
    fail "detect_review_cli: only codex returns codex" "exit 0 + codex" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 24: detect_review_cli returns error when neither on PATH
# ========================================
echo ""
echo "--- Test 24: detect_review_cli errors when neither on PATH ---"
echo ""

exit_code=0
stderr_out=""
stderr_out=$(PATH="$SAFE_BASE_PATH" detect_review_cli 2>&1 >/dev/null) || exit_code=$?

if [[ $exit_code -ne 0 ]] && echo "$stderr_out" | grep -qi "neither"; then
    pass "detect_review_cli: neither on PATH exits non-zero with error"
else
    fail "detect_review_cli: neither on PATH exits non-zero with error" "non-zero exit + error message" "exit=$exit_code, stderr=$stderr_out"
fi

# ========================================
# Test 25: HUMANIZE_PREFERRED_CLI=codex with both installed returns codex
# ========================================
echo ""
echo "--- Test 25: HUMANIZE_PREFERRED_CLI=codex overrides auto ---"
echo ""

setup_test_dir
BIN_DIR="$TEST_DIR/bin"
create_mock_copilot "$BIN_DIR"
create_mock_binary "$BIN_DIR" "codex"

result=""
exit_code=0
result=$(PATH="$BIN_DIR:$SAFE_BASE_PATH" HUMANIZE_PREFERRED_CLI=codex detect_review_cli 2>/dev/null) || exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$result" == "codex" ]]; then
    pass "detect_review_cli: HUMANIZE_PREFERRED_CLI=codex returns codex"
else
    fail "detect_review_cli: HUMANIZE_PREFERRED_CLI=codex returns codex" "exit 0 + codex" "exit=$exit_code, output=$result"
fi

# ========================================
# Test 26: HUMANIZE_PREFERRED_CLI=copilot with copilot missing returns error
# ========================================
echo ""
echo "--- Test 26: HUMANIZE_PREFERRED_CLI=copilot but copilot missing ---"
echo ""

setup_test_dir
BIN_DIR="$TEST_DIR/bin"
create_mock_binary "$BIN_DIR" "codex"

exit_code=0
stderr_out=""
stderr_out=$(PATH="$BIN_DIR:$SAFE_BASE_PATH" HUMANIZE_PREFERRED_CLI=copilot detect_review_cli 2>&1 >/dev/null) || exit_code=$?

if [[ $exit_code -ne 0 ]] && echo "$stderr_out" | grep -qi "copilot"; then
    pass "detect_review_cli: preferred copilot but missing exits non-zero"
else
    fail "detect_review_cli: preferred copilot but missing exits non-zero" "non-zero exit + copilot in stderr" "exit=$exit_code, stderr=$stderr_out"
fi

# ========================================
# Test 27: run_diff_review truncates large diffs (>64KB)
# ========================================
echo ""
echo "--- Test 27: run_diff_review truncates large diffs >64KB ---"
echo ""

setup_test_dir
LARGE_DIFF_PROJECT="$TEST_DIR/large-diff-project"
init_test_git_repo "$LARGE_DIFF_PROJECT"

# Create a file >64KB (70000 bytes) and commit it
dd if=/dev/zero bs=1 count=70000 2>/dev/null | tr '\0' 'A' > "$LARGE_DIFF_PROJECT/bigfile.txt"
(cd "$LARGE_DIFF_PROJECT" && git add bigfile.txt && git commit -q -m "Add large file")

# Create a mock copilot that just echoes its -p argument length
MOCK_BIN="$TEST_DIR/mock-bin"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/copilot" << 'MOCK_EOF'
#!/bin/bash
# No-op mock copilot — we only care about stderr from run_diff_review
echo "mock review output"
exit 0
MOCK_EOF
chmod +x "$MOCK_BIN/copilot"

stderr_out=""
exit_code=0
# base_ref is HEAD~1, diff will be the big file addition
stderr_out=$(PATH="$MOCK_BIN:$PATH" \
    CLAUDE_PLUGIN_ROOT="$TEST_DIR/no-plugin" \
    run_diff_review "HEAD~1" "gpt-5.4" "high" "$LARGE_DIFF_PROJECT" 30 "copilot" 2>&1 >/dev/null) || exit_code=$?

if echo "$stderr_out" | grep -q "truncating to"; then
    pass "run_diff_review: large diff (>64KB) triggers truncation warning"
else
    fail "run_diff_review: large diff (>64KB) triggers truncation warning" "stderr contains 'truncating to'" "exit=$exit_code, stderr=$stderr_out"
fi

# ========================================
# Test 28: run_diff_review does NOT truncate normal diffs
# ========================================
echo ""
echo "--- Test 28: run_diff_review does NOT truncate normal diffs ---"
echo ""

setup_test_dir
SMALL_DIFF_PROJECT="$TEST_DIR/small-diff-project"
init_test_git_repo "$SMALL_DIFF_PROJECT"

# Create a small file and commit it
echo "small change" > "$SMALL_DIFF_PROJECT/small.txt"
(cd "$SMALL_DIFF_PROJECT" && git add small.txt && git commit -q -m "Add small file")

MOCK_BIN="$TEST_DIR/mock-bin-small"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/copilot" << 'MOCK_EOF'
#!/bin/bash
echo "mock review output"
exit 0
MOCK_EOF
chmod +x "$MOCK_BIN/copilot"

stderr_out=""
exit_code=0
stderr_out=$(PATH="$MOCK_BIN:$PATH" \
    CLAUDE_PLUGIN_ROOT="$TEST_DIR/no-plugin" \
    run_diff_review "HEAD~1" "gpt-5.4" "high" "$SMALL_DIFF_PROJECT" 30 "copilot" 2>&1 >/dev/null) || exit_code=$?

if echo "$stderr_out" | grep -q "truncating"; then
    fail "run_diff_review: normal diff does NOT truncate" "no truncation warning" "stderr=$stderr_out"
else
    pass "run_diff_review: normal diff does NOT truncate"
fi

# ========================================
# Test 29: RLCR state review_cli: copilot is honored
# ========================================
echo ""
echo "--- Test 29: RLCR state review_cli: copilot is honored ---"
echo ""

setup_test_dir
STATE_FILE="$TEST_DIR/state.md"
cat > "$STATE_FILE" <<'STATE_EOF'
---
plan_tracked: true
start_branch: feature
base_branch: main
current_round: 1
max_iterations: 10
review_cli: copilot
review_started: true
---
# Plan
STATE_EOF

# Reset state vars to ensure parse_state_file sets them
STATE_REVIEW_CLI=""
parse_state_file "$STATE_FILE"

if [[ "$STATE_REVIEW_CLI" == "copilot" ]]; then
    pass "parse_state_file: review_cli: copilot sets STATE_REVIEW_CLI=copilot"
else
    fail "parse_state_file: review_cli: copilot sets STATE_REVIEW_CLI=copilot" "copilot" "$STATE_REVIEW_CLI"
fi

# ========================================
# Test 29b: RLCR state review_cli: codex is honored
# ========================================
echo ""
echo "--- Test 29b: RLCR state review_cli: codex is honored ---"
echo ""

cat > "$STATE_FILE" <<'STATE_EOF'
---
plan_tracked: true
start_branch: feature
base_branch: main
current_round: 1
max_iterations: 10
review_cli: codex
review_started: true
---
# Plan
STATE_EOF

STATE_REVIEW_CLI=""
parse_state_file "$STATE_FILE"

if [[ "$STATE_REVIEW_CLI" == "codex" ]]; then
    pass "parse_state_file: review_cli: codex sets STATE_REVIEW_CLI=codex"
else
    fail "parse_state_file: review_cli: codex sets STATE_REVIEW_CLI=codex" "codex" "$STATE_REVIEW_CLI"
fi

# ========================================
# Test 30: Legacy state without review_cli defaults to empty (codex via fallback)
# ========================================
echo ""
echo "--- Test 30: Legacy state without review_cli defaults to empty ---"
echo ""

setup_test_dir
STATE_FILE="$TEST_DIR/legacy-state.md"
cat > "$STATE_FILE" <<'STATE_EOF'
---
plan_tracked: true
start_branch: feature
base_branch: main
current_round: 2
max_iterations: 10
review_started: true
---
# Legacy plan without review_cli field
STATE_EOF

# Put mock copilot on PATH to prove it's NOT auto-detected during parse
BIN_DIR="$TEST_DIR/bin"
create_mock_copilot "$BIN_DIR"

STATE_REVIEW_CLI="stale"
PATH="$BIN_DIR:$SAFE_BASE_PATH" parse_state_file "$STATE_FILE"

if [[ -z "$STATE_REVIEW_CLI" ]]; then
    # Verify the fallback expression resolves to codex
    local_fallback="${STATE_REVIEW_CLI:-codex}"
    if [[ "$local_fallback" == "codex" ]]; then
        pass "parse_state_file: legacy state without review_cli is empty, \${:-codex} resolves to codex"
    else
        fail "parse_state_file: legacy state without review_cli is empty, \${:-codex} resolves to codex" "codex" "$local_fallback"
    fi
else
    fail "parse_state_file: legacy state without review_cli should be empty" "empty" "$STATE_REVIEW_CLI"
fi

# ========================================
# Test 31: HUMANIZE_PREFERRED_CLI=copilot but copilot missing → hard fail
# ========================================
echo ""
echo "--- Test 31: preferred_cli=copilot with copilot missing → hard fail ---"
echo ""

setup_test_dir
BIN_DIR="$TEST_DIR/bin"
# Only codex on PATH, no copilot
create_mock_binary "$BIN_DIR" "codex"

exit_code=0
stderr_out=""
stderr_out=$(PATH="$BIN_DIR:$SAFE_BASE_PATH" HUMANIZE_PREFERRED_CLI=copilot detect_review_cli 2>&1 >/dev/null) || exit_code=$?

if [[ $exit_code -ne 0 ]] && echo "$stderr_out" | grep -qi "copilot"; then
    pass "detect_review_cli: preferred copilot + missing copilot → hard fail (exit $exit_code)"
else
    fail "detect_review_cli: preferred copilot + missing copilot → hard fail" "non-zero exit + copilot error" "exit=$exit_code, stderr=$stderr_out"
fi

# ========================================
# Test 32: HUMANIZE_PREFERRED_CLI=codex but codex missing → hard fail
# ========================================
echo ""
echo "--- Test 32: preferred_cli=codex with codex missing → hard fail ---"
echo ""

setup_test_dir
BIN_DIR="$TEST_DIR/bin"
# Only copilot on PATH, no codex
create_mock_copilot "$BIN_DIR"

exit_code=0
stderr_out=""
stderr_out=$(PATH="$BIN_DIR:$SAFE_BASE_PATH" HUMANIZE_PREFERRED_CLI=codex detect_review_cli 2>&1 >/dev/null) || exit_code=$?

if [[ $exit_code -ne 0 ]] && echo "$stderr_out" | grep -qi "codex"; then
    pass "detect_review_cli: preferred codex + missing codex → hard fail (exit $exit_code)"
else
    fail "detect_review_cli: preferred codex + missing codex → hard fail" "non-zero exit + codex error" "exit=$exit_code, stderr=$stderr_out"
fi

# ========================================
# Test 33: Neither CLI installed → hard fail (regardless of preference)
# ========================================
echo ""
echo "--- Test 33: Neither CLI installed → hard fail ---"
echo ""

exit_code=0
stderr_out=""
stderr_out=$(PATH="$SAFE_BASE_PATH" HUMANIZE_PREFERRED_CLI=auto detect_review_cli 2>&1 >/dev/null) || exit_code=$?

if [[ $exit_code -ne 0 ]] && echo "$stderr_out" | grep -qi "neither"; then
    pass "detect_review_cli: neither installed + auto → hard fail (exit $exit_code)"
else
    fail "detect_review_cli: neither installed + auto → hard fail" "non-zero exit + neither error" "exit=$exit_code, stderr=$stderr_out"
fi

# ========================================
# Test 34: run_diff_review prompt size bounded (copilot backend)
# ========================================
echo ""
echo "--- Test 34: run_diff_review prompt size bounded for copilot ---"
echo ""

setup_test_dir
BOUNDED_PROJECT="$TEST_DIR/bounded-project"
init_test_git_repo "$BOUNDED_PROJECT"

# Create a file >32KB (40000 bytes) and commit
dd if=/dev/zero bs=1 count=40000 2>/dev/null | tr '\0' 'X' > "$BOUNDED_PROJECT/medium.txt"
(cd "$BOUNDED_PROJECT" && git add medium.txt && git commit -q -m "Add medium file")

# Create a mock copilot that captures the -p argument length to a file
MOCK_BIN="$TEST_DIR/mock-bin-bounded"
CAPTURE_FILE="$TEST_DIR/captured_length.txt"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/copilot" << MOCK_EOF
#!/bin/bash
# Capture -p argument length
while [[ \$# -gt 0 ]]; do
    case "\$1" in
        -p) shift; echo "\${#1}" > "$CAPTURE_FILE"; shift ;;
        *) shift ;;
    esac
done
echo "mock review output"
exit 0
MOCK_EOF
chmod +x "$MOCK_BIN/copilot"

exit_code=0
PATH="$MOCK_BIN:$PATH" \
    CLAUDE_PLUGIN_ROOT="$TEST_DIR/no-plugin" \
    run_diff_review "HEAD~1" "gpt-5.4" "high" "$BOUNDED_PROJECT" 30 "copilot" >/dev/null 2>&1 || exit_code=$?

if [[ -f "$CAPTURE_FILE" ]]; then
    captured_len=$(cat "$CAPTURE_FILE")
    # 40KB file diff should be under 64KB + template overhead ≈ ~70KB max
    if [[ $captured_len -le 75000 ]]; then
        pass "run_diff_review: copilot -p argument is bounded ($captured_len bytes ≤ 75000)"
    else
        fail "run_diff_review: copilot -p argument is bounded" "≤ 75000 bytes" "$captured_len bytes"
    fi
else
    fail "run_diff_review: copilot -p argument is bounded" "capture file exists" "capture file not created (exit=$exit_code)"
fi

# ========================================
# Summary
# ========================================

print_test_summary "Model Router Test Summary"
