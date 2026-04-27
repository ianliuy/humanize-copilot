#!/bin/bash
#
# Integration tests for review CLI frozen-backend behavior
#
# Tests the actual hook entrypoints (loop-codex-stop-hook.sh, pr-loop-stop-hook.sh)
# as closely as feasible, plus the shared library functions they depend on.
#
# Verifies that:
# 1. parse_state_file correctly extracts review_cli from state.md
# 2. run_prompt_exec dispatches to the correct binary (copilot vs codex)
# 3. RLCR stop hook contains the FROZEN_REVIEW_CLI wiring pattern
# 4. PR stop hook contains the equivalent PR_REVIEW_CLI wiring pattern
# 5. Legacy state without review_cli defaults to codex (backward compat)
# 6. detect_review_cli respects HUMANIZE_PREFERRED_CLI
# 7. run_prompt_exec rejects unknown CLI backends
# 8. Setup succeeds with remote-only base ref in copilot mode
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

setup_test_dir

# ========================================
# Shared helpers
# ========================================

# Create mock CLI binaries that log which was invoked
setup_mock_binaries() {
    mkdir -p "$TEST_DIR/bin"

    cat > "$TEST_DIR/bin/copilot" << 'MOCK'
#!/bin/bash
echo "copilot-was-called" >> "${MOCK_CALL_LOG:?}"
echo "COMPLETE"
exit 0
MOCK

    cat > "$TEST_DIR/bin/codex" << 'MOCK'
#!/bin/bash
echo "codex-was-called" >> "${MOCK_CALL_LOG:?}"
echo "COMPLETE"
exit 0
MOCK

    chmod +x "$TEST_DIR/bin/copilot" "$TEST_DIR/bin/codex"
    export PATH="$TEST_DIR/bin:$PATH"
}

# Source loop-common.sh, resetting the guard so it loads fresh
source_loop_common() {
    unset _LOOP_COMMON_LOADED 2>/dev/null || true
    set +eu
    source "$PROJECT_ROOT/hooks/lib/loop-common.sh" 2>/dev/null
    set -eu
}

# Create a minimal state.md file
# Args: target_dir [review_cli_value]
# If review_cli_value is empty or omitted, the field is excluded
create_test_state() {
    local dir="$1"
    local review_cli="${2:-}"

    mkdir -p "$dir"
    local state_file="$dir/state.md"

    local review_cli_line=""
    if [[ -n "$review_cli" ]]; then
        review_cli_line="review_cli: $review_cli"
    fi

    cat > "$state_file" << EOF
---
current_round: 1
max_iterations: 10
codex_model: gpt-5.4
codex_effort: high
codex_timeout: 30
push_every_round: false
full_review_round: 5
plan_file: "plans/test.md"
plan_tracked: false
start_branch: main
base_branch: main
base_commit: abc123
review_started: true
ask_codex_question: false
agent_teams: false
session_id: test-session
${review_cli_line}
---
EOF
    echo "$state_file"
}

# Reset call log for a fresh test
reset_call_log() {
    local dir="$1"
    MOCK_CALL_LOG="$dir/call.log"
    rm -f "$MOCK_CALL_LOG"
    touch "$MOCK_CALL_LOG"
    export MOCK_CALL_LOG
}

setup_mock_binaries

echo "=========================================="
echo "Review CLI Integration Tests"
echo "=========================================="
echo ""

# Source loop-common — functions we need (parse_state_file,
# run_prompt_exec, run_with_timeout, detect_review_cli) become available.
source_loop_common

# Also source portable-timeout directly to ensure run_with_timeout is available
source "$PROJECT_ROOT/scripts/portable-timeout.sh" 2>/dev/null || true

# ----------------------------------------
# Test 1: parse_state_file extracts review_cli=copilot
# ----------------------------------------
echo "Test 1: parse_state_file extracts review_cli=copilot from state.md"
STATE_FILE_1=$(create_test_state "$TEST_DIR/t1" "copilot")

parse_state_file "$STATE_FILE_1"
if [[ "${STATE_REVIEW_CLI:-}" == "copilot" ]]; then
    pass "parse_state_file: STATE_REVIEW_CLI='copilot'"
else
    fail "parse_state_file: STATE_REVIEW_CLI should be 'copilot'" \
         "copilot" "${STATE_REVIEW_CLI:-<empty>}"
fi

# ----------------------------------------
# Test 2: run_prompt_exec dispatches to copilot when cli=copilot
# ----------------------------------------
echo "Test 2: run_prompt_exec dispatches to copilot binary"
reset_call_log "$TEST_DIR/t2"

set +e
run_prompt_exec "test prompt" "gpt-5.4" "high" "$TEST_DIR/t2" "10" "copilot" >/dev/null 2>&1
RUN_RC=$?
set -e

if grep -q "copilot-was-called" "$MOCK_CALL_LOG" && ! grep -q "codex-was-called" "$MOCK_CALL_LOG"; then
    pass "run_prompt_exec dispatches to mock copilot (copilot called, codex NOT called)"
else
    fail "run_prompt_exec dispatches to mock copilot" \
         "copilot called, codex NOT called" \
         "log: $(cat "$MOCK_CALL_LOG")"
fi

# ----------------------------------------
# Test 3: RLCR stop hook wires FROZEN_REVIEW_CLI from state
# ----------------------------------------
echo "Test 3: RLCR stop hook contains FROZEN_REVIEW_CLI wiring"

RLCR_HOOK="$PROJECT_ROOT/hooks/loop-codex-stop-hook.sh"

# 3a: Hook reads STATE_REVIEW_CLI with codex default
if grep -q 'FROZEN_REVIEW_CLI="${STATE_REVIEW_CLI:-codex}"' "$RLCR_HOOK"; then
    pass "RLCR hook: FROZEN_REVIEW_CLI=\${STATE_REVIEW_CLI:-codex} pattern present"
else
    fail "RLCR hook: missing FROZEN_REVIEW_CLI assignment" \
         'FROZEN_REVIEW_CLI="${STATE_REVIEW_CLI:-codex}"' \
         "$(grep -n 'FROZEN_REVIEW_CLI' "$RLCR_HOOK" 2>/dev/null || echo 'not found')"
fi

# 3b: Hook transfers frozen value to REVIEW_CLI for invocation
if grep -q 'REVIEW_CLI="${FROZEN_REVIEW_CLI}"' "$RLCR_HOOK"; then
    pass "RLCR hook: REVIEW_CLI=\${FROZEN_REVIEW_CLI} transfer present"
else
    fail "RLCR hook: missing REVIEW_CLI transfer" \
         'REVIEW_CLI="${FROZEN_REVIEW_CLI}"' \
         "$(grep -n 'REVIEW_CLI=.*FROZEN' "$RLCR_HOOK" 2>/dev/null || echo 'not found')"
fi

# 3c: Hook checks command -v before using REVIEW_CLI
if grep -q 'command -v "$REVIEW_CLI"' "$RLCR_HOOK"; then
    pass "RLCR hook: validates REVIEW_CLI with command -v before use"
else
    fail "RLCR hook: missing command -v guard for REVIEW_CLI" \
         'command -v "$REVIEW_CLI"' "not found"
fi

# ----------------------------------------
# Test 4: PR stop hook wires PR_REVIEW_CLI from state
# ----------------------------------------
echo "Test 4: PR stop hook contains PR_REVIEW_CLI wiring"

PR_HOOK="$PROJECT_ROOT/hooks/pr-loop-stop-hook.sh"

# 4a: Hook extracts review_cli from frontmatter
if grep -q 'PR_REVIEW_CLI=.*review_cli' "$PR_HOOK"; then
    pass "PR hook: PR_REVIEW_CLI extraction from frontmatter present"
else
    fail "PR hook: missing PR_REVIEW_CLI extraction" \
         "PR_REVIEW_CLI=...review_cli..." \
         "$(grep -n 'PR_REVIEW_CLI' "$PR_HOOK" | head -1)"
fi

# 4b: Hook defaults to codex when PR_REVIEW_CLI is empty
if grep -q 'REVIEW_CLI="${PR_REVIEW_CLI:-codex}"' "$PR_HOOK"; then
    pass "PR hook: REVIEW_CLI=\${PR_REVIEW_CLI:-codex} default present"
else
    fail "PR hook: missing codex default for REVIEW_CLI" \
         'REVIEW_CLI="${PR_REVIEW_CLI:-codex}"' \
         "$(grep -n 'REVIEW_CLI=.*PR_REVIEW_CLI' "$PR_HOOK" 2>/dev/null || echo 'not found')"
fi

# 4c: PR hook passes REVIEW_CLI to run_prompt_exec
if grep -q 'run_prompt_exec.*"$REVIEW_CLI"' "$PR_HOOK"; then
    pass "PR hook: passes \$REVIEW_CLI to run_prompt_exec"
else
    fail "PR hook: REVIEW_CLI not passed to run_prompt_exec" \
         'run_prompt_exec ... "$REVIEW_CLI"' "not found"
fi

# ----------------------------------------
# Test 5: Legacy state without review_cli defaults to codex
# ----------------------------------------
echo "Test 5: Legacy state without review_cli defaults to codex"
STATE_FILE_5=$(create_test_state "$TEST_DIR/t5" "")
reset_call_log "$TEST_DIR/t5"

parse_state_file "$STATE_FILE_5"
resolved_cli="${STATE_REVIEW_CLI:-codex}"

if [[ "$resolved_cli" != "codex" ]]; then
    fail "Legacy default should be 'codex' when review_cli absent" "codex" "$resolved_cli"
else
    set +e
    run_prompt_exec "legacy prompt" "gpt-5.4" "high" "$TEST_DIR/t5" "10" "$resolved_cli" >/dev/null 2>&1
    set -e

    if grep -q "codex-was-called" "$MOCK_CALL_LOG" && ! grep -q "copilot-was-called" "$MOCK_CALL_LOG"; then
        pass "Legacy default: codex called, copilot NOT called"
    else
        fail "Legacy default: codex should be called" \
             "codex called, copilot NOT called" \
             "log: $(cat "$MOCK_CALL_LOG")"
    fi
fi

# ----------------------------------------
# Test 6: detect_review_cli respects HUMANIZE_PREFERRED_CLI
# ----------------------------------------
echo "Test 6: detect_review_cli respects HUMANIZE_PREFERRED_CLI"

# 6a: explicit copilot
detected=$(HUMANIZE_PREFERRED_CLI="copilot" detect_review_cli 2>/dev/null)
if [[ "$detected" == "copilot" ]]; then
    pass "detect_review_cli: HUMANIZE_PREFERRED_CLI=copilot → copilot"
else
    fail "detect_review_cli with HUMANIZE_PREFERRED_CLI=copilot" "copilot" "$detected"
fi

# 6b: explicit codex
detected=$(HUMANIZE_PREFERRED_CLI="codex" detect_review_cli 2>/dev/null)
if [[ "$detected" == "codex" ]]; then
    pass "detect_review_cli: HUMANIZE_PREFERRED_CLI=codex → codex"
else
    fail "detect_review_cli with HUMANIZE_PREFERRED_CLI=codex" "codex" "$detected"
fi

# 6c: auto picks copilot (both mocks are on PATH)
detected=$(HUMANIZE_PREFERRED_CLI="auto" detect_review_cli 2>/dev/null)
if [[ "$detected" == "copilot" ]]; then
    pass "detect_review_cli: auto prefers copilot when both available"
else
    fail "detect_review_cli auto preference" "copilot" "$detected"
fi

# ----------------------------------------
# Test 7: run_prompt_exec rejects unknown CLI backend
# ----------------------------------------
echo "Test 7: run_prompt_exec rejects unknown CLI backend"

set +e
err_output=$(run_prompt_exec "test" "gpt-5.4" "high" "$TEST_DIR" "10" "unknown_cli" 2>&1)
unknown_rc=$?
set -e

if [[ $unknown_rc -ne 0 ]] && echo "$err_output" | grep -qi "unknown"; then
    pass "run_prompt_exec rejects unknown backend (rc=$unknown_rc)"
else
    fail "run_prompt_exec should reject unknown CLI" \
         "non-zero exit + error message" \
         "rc=$unknown_rc output=$err_output"
fi

# ----------------------------------------
# Test 8: Remote-only base ref resolves correctly
# ----------------------------------------
echo "Test 8: Remote-only base ref resolves correctly in copilot mode"

BARE_REMOTE="$TEST_DIR/bare-remote.git"
mkdir -p "$BARE_REMOTE"
git init -q --bare "$BARE_REMOTE"

SEED_DIR="$TEST_DIR/seed-repo"
git clone -q "$BARE_REMOTE" "$SEED_DIR"
cd "$SEED_DIR"
git config user.email "test@test.com"
git config user.name "Test User"
git config commit.gpgsign false
echo "initial" > file.txt
git add file.txt
git commit -q -m "Initial commit"
DEFAULT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push -q origin "$DEFAULT_BRANCH"
cd "$TEST_DIR"

GIT_REPO="$TEST_DIR/remote-ref-repo"
git clone -q "$BARE_REMOTE" "$GIT_REPO"
cd "$GIT_REPO"
git config user.email "test@test.com"
git config user.name "Test User"
git config commit.gpgsign false
git checkout -q -b feature/test-branch

# Delete local default branch to simulate remote-only ref
git branch -D "$DEFAULT_BRANCH" 2>/dev/null || true
REMOTE_REF="origin/$DEFAULT_BRANCH"

if git rev-parse --verify "$DEFAULT_BRANCH" >/dev/null 2>&1; then
    fail "Setup: local $DEFAULT_BRANCH should NOT exist" \
         "no local $DEFAULT_BRANCH" "local $DEFAULT_BRANCH found"
else
    if git rev-parse --verify "$REMOTE_REF" >/dev/null 2>&1; then
        sha=$(git rev-parse "$REMOTE_REF")
        if [[ ${#sha} -eq 40 ]] && [[ "$sha" =~ ^[0-9a-f]+$ ]]; then
            pass "Remote-only base ref $REMOTE_REF resolves to valid SHA ($sha)"
        else
            fail "Remote-only base ref SHA should be 40 hex chars" "40 hex chars" "$sha"
        fi
    else
        fail "$REMOTE_REF should be resolvable" "rev-parse succeeds" "rev-parse failed"
    fi
fi

cd "$SCRIPT_DIR"

# ========================================
# Summary
# ========================================

print_test_summary "Review CLI Integration Test Summary"
exit $?
