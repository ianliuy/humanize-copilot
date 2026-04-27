#!/bin/bash
#
# Integration tests for review CLI frozen-backend behavior
#
# Verifies that:
# 1. state.md review_cli=copilot is parsed and dispatches to copilot binary
# 2. PR hook also dispatches correctly via run_prompt_exec
# 3. Legacy state without review_cli defaults to codex
# 4. Setup succeeds with remote-only base ref in copilot mode
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
echo "mock copilot output"
exit 0
MOCK

    cat > "$TEST_DIR/bin/codex" << 'MOCK'
#!/bin/bash
echo "codex-was-called" >> "${MOCK_CALL_LOG:?}"
echo "mock codex output"
exit 0
MOCK

    chmod +x "$TEST_DIR/bin/copilot" "$TEST_DIR/bin/codex"
    export PATH="$TEST_DIR/bin:$PATH"
}

# Source loop-common.sh in a way that suppresses non-fatal warnings
source_loop_common() {
    # loop-common.sh derives PLUGIN_ROOT from its own location and sources
    # config-loader.sh, template-loader.sh, and portable-timeout.sh.
    # We just need to source it from the real project tree.
    (
        # Subshell to avoid polluting caller with strict-mode changes
        set +eu
        source "$PROJECT_ROOT/hooks/lib/loop-common.sh" 2>/dev/null
    ) || true

    # Now source for real in the current shell; the guard variable
    # _LOOP_COMMON_LOADED is set, so the heavy init is skipped on re-source.
    # We need to unset the guard so it loads fresh each test.
    unset _LOOP_COMMON_LOADED
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
${review_cli_line}
---
EOF
    echo "$state_file"
}

setup_mock_binaries

echo "=========================================="
echo "Review CLI Integration Tests"
echo "=========================================="
echo ""

# Source loop-common once — functions we need (parse_state_file,
# run_prompt_exec, run_with_timeout) are now available.
source_loop_common

# Also source portable-timeout directly to ensure run_with_timeout is available
source "$PROJECT_ROOT/scripts/portable-timeout.sh" 2>/dev/null || true

# ----------------------------------------
# Test 1: RLCR hook uses frozen review_cli=copilot
# ----------------------------------------
echo "Test 1: RLCR hook dispatches to copilot when review_cli=copilot"
STATE_FILE_1=$(create_test_state "$TEST_DIR/rlcr1" "copilot")
MOCK_CALL_LOG="$TEST_DIR/rlcr1/call.log"
rm -f "$MOCK_CALL_LOG"
touch "$MOCK_CALL_LOG"
export MOCK_CALL_LOG

# Parse state and verify STATE_REVIEW_CLI
parse_state_file "$STATE_FILE_1"
resolved_cli="${STATE_REVIEW_CLI:-codex}"

if [[ "$resolved_cli" != "copilot" ]]; then
    fail "RLCR: STATE_REVIEW_CLI should be 'copilot'" "copilot" "$resolved_cli"
else
    # Dispatch via run_prompt_exec
    set +e
    run_prompt_exec "test prompt" "gpt-5.4" "high" "$TEST_DIR/rlcr1" "10" "$resolved_cli" >/dev/null 2>&1
    set -e

    if grep -q "copilot-was-called" "$MOCK_CALL_LOG" && ! grep -q "codex-was-called" "$MOCK_CALL_LOG"; then
        pass "RLCR: run_prompt_exec dispatches to mock copilot when review_cli=copilot"
    else
        fail "RLCR: run_prompt_exec dispatches to mock copilot when review_cli=copilot" \
             "copilot called, codex NOT called" \
             "log: $(cat "$MOCK_CALL_LOG")"
    fi
fi

# ----------------------------------------
# Test 2: PR hook uses frozen review_cli=copilot
# ----------------------------------------
echo "Test 2: PR hook dispatches to copilot when review_cli=copilot"
STATE_FILE_2=$(create_test_state "$TEST_DIR/pr1" "copilot")
MOCK_CALL_LOG="$TEST_DIR/pr1/call.log"
rm -f "$MOCK_CALL_LOG"
touch "$MOCK_CALL_LOG"
export MOCK_CALL_LOG

parse_state_file "$STATE_FILE_2"
resolved_cli="${STATE_REVIEW_CLI:-codex}"

if [[ "$resolved_cli" != "copilot" ]]; then
    fail "PR hook: STATE_REVIEW_CLI should be 'copilot'" "copilot" "$resolved_cli"
else
    set +e
    run_prompt_exec "pr review prompt" "gpt-5.4" "high" "$TEST_DIR/pr1" "10" "$resolved_cli" >/dev/null 2>&1
    set -e

    if grep -q "copilot-was-called" "$MOCK_CALL_LOG" && ! grep -q "codex-was-called" "$MOCK_CALL_LOG"; then
        pass "PR hook: run_prompt_exec dispatches to mock copilot when review_cli=copilot"
    else
        fail "PR hook: run_prompt_exec dispatches to mock copilot when review_cli=copilot" \
             "copilot called, codex NOT called" \
             "log: $(cat "$MOCK_CALL_LOG")"
    fi
fi

# ----------------------------------------
# Test 3: Legacy state without review_cli defaults to codex
# ----------------------------------------
echo "Test 3: Legacy state without review_cli defaults to codex"
STATE_FILE_3=$(create_test_state "$TEST_DIR/legacy1" "")
MOCK_CALL_LOG="$TEST_DIR/legacy1/call.log"
rm -f "$MOCK_CALL_LOG"
touch "$MOCK_CALL_LOG"
export MOCK_CALL_LOG

parse_state_file "$STATE_FILE_3"
resolved_cli="${STATE_REVIEW_CLI:-codex}"

if [[ "$resolved_cli" != "codex" ]]; then
    fail "Legacy: should default to 'codex' when review_cli absent" "codex" "$resolved_cli"
else
    set +e
    run_prompt_exec "legacy prompt" "gpt-5.4" "high" "$TEST_DIR/legacy1" "10" "$resolved_cli" >/dev/null 2>&1
    set -e

    if grep -q "codex-was-called" "$MOCK_CALL_LOG" && ! grep -q "copilot-was-called" "$MOCK_CALL_LOG"; then
        pass "Legacy: run_prompt_exec dispatches to mock codex when review_cli absent"
    else
        fail "Legacy: run_prompt_exec dispatches to mock codex when review_cli absent" \
             "codex called, copilot NOT called" \
             "log: $(cat "$MOCK_CALL_LOG")"
    fi
fi

# ----------------------------------------
# Test 4: Setup succeeds with remote-only base ref in copilot mode
# ----------------------------------------
echo "Test 4: Remote-only base ref resolves correctly in copilot mode"

# Build a repo that has origin/main but no local main branch.
# Strategy: init a bare "remote", clone it (which creates origin/main tracking),
# then create a feature branch and delete local main.
BARE_REMOTE="$TEST_DIR/bare-remote.git"
mkdir -p "$BARE_REMOTE"
git init -q --bare "$BARE_REMOTE"

# Seed the bare repo with one commit via a throwaway clone
SEED_DIR="$TEST_DIR/seed-repo"
git clone -q "$BARE_REMOTE" "$SEED_DIR"
cd "$SEED_DIR"
git config user.email "test@test.com"
git config user.name "Test User"
git config commit.gpgsign false
echo "initial" > file.txt
git add file.txt
git commit -q -m "Initial commit"
# Detect default branch name (may be main or master depending on git config)
DEFAULT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push -q origin "$DEFAULT_BRANCH"
cd "$TEST_DIR"

# Clone again — this is the repo under test
GIT_REPO="$TEST_DIR/remote-ref-repo"
git clone -q "$BARE_REMOTE" "$GIT_REPO"
cd "$GIT_REPO"
git config user.email "test@test.com"
git config user.name "Test User"
git config commit.gpgsign false

# Switch to a feature branch so there is no local default branch checked out
git checkout -q -b feature/test-branch

# Delete local default branch to simulate remote-only ref
git branch -D "$DEFAULT_BRANCH" 2>/dev/null || true
REMOTE_REF="origin/$DEFAULT_BRANCH"

# Verify remote ref is accessible but local branch is not
if git rev-parse --verify "$DEFAULT_BRANCH" >/dev/null 2>&1; then
    fail "Setup: local $DEFAULT_BRANCH should NOT exist" "no local $DEFAULT_BRANCH" "local $DEFAULT_BRANCH found"
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
