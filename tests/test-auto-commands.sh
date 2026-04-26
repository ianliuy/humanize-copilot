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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
