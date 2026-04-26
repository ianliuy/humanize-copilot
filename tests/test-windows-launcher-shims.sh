#!/bin/bash
#
# Structural test for the Windows .cmd launcher shims.
#
# Runs on any POSIX host (no cmd.exe required). Verifies:
# - hooks/*.cmd exists for every hooks.json entry (8 files, 1:1 with .sh basenames).
# - scripts/*.cmd exists for every scripts/*.sh entry referenced by commands/*.md
#   allowed-tools (7 files, 1:1).
# - Each .cmd carries the expected launcher template lines (find_bash probe order,
#   bash invocation form, exit-code propagation, missing-bash stderr text).
# - hooks/hooks.json carries a "windows" override on every entry pointing at the
#   sibling .cmd, and the override path resolves to a real file.
# - commands/*.md allowed-tools accept BOTH .sh and .cmd spellings for every
#   referenced scripts/<name>.sh.
#
# Argv-fidelity, stdin-fidelity, and exit-code propagation behavior are exercised
# end-to-end in the Windows CI job (.github/workflows/windows-launcher-smoke.yml),
# not here.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "${GREEN}PASS${NC}: $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

assert_file_exists() {
    if [[ -f "$1" ]]; then pass "exists: $1"; else fail "missing: $1"; fi
}

assert_grep() {
    local file="$1" pattern="$2" desc="$3"
    if grep -qE "$pattern" "$file"; then pass "$desc ($file)"; else fail "$desc ($file)"; fi
}

# ----------------------------------------------------------------------
# 1. Every hook entry in hooks/hooks.json has a sibling .cmd file.
# ----------------------------------------------------------------------

echo "--- Hook launcher pairing ---"

mapfile -t HOOK_SH_PATHS < <(jq -r '.hooks | to_entries[] | .value[] | .hooks[]? | .command' "$PROJECT_ROOT/hooks/hooks.json" | tr -d '\r' | grep -E '/hooks/[^/]+\.sh$')

if (( ${#HOOK_SH_PATHS[@]} != 8 )); then
    fail "expected 8 hook entries in hooks/hooks.json, found ${#HOOK_SH_PATHS[@]}"
else
    pass "8 hook entries in hooks/hooks.json"
fi

for sh_path in "${HOOK_SH_PATHS[@]}"; do
    name=$(basename "$sh_path" .sh)
    assert_file_exists "$PROJECT_ROOT/hooks/${name}.sh"
    assert_file_exists "$PROJECT_ROOT/hooks/${name}.cmd"
done

# ----------------------------------------------------------------------
# 2. hooks.json windows override per entry, pointing at a real .cmd.
# ----------------------------------------------------------------------

echo "--- hooks.json windows override ---"

mapfile -t HOOK_WIN_PATHS < <(jq -r '.hooks | to_entries[] | .value[] | .hooks[]? | .windows // empty' "$PROJECT_ROOT/hooks/hooks.json" | tr -d '\r')

if (( ${#HOOK_WIN_PATHS[@]} != 8 )); then
    fail "expected 8 windows overrides in hooks/hooks.json, found ${#HOOK_WIN_PATHS[@]}"
else
    pass "8 windows overrides in hooks/hooks.json"
fi

for win_path in "${HOOK_WIN_PATHS[@]}"; do
    expanded="${win_path/\$\{CLAUDE_PLUGIN_ROOT\}/$PROJECT_ROOT}"
    assert_file_exists "$expanded"
done

# ----------------------------------------------------------------------
# 3. scripts/*.cmd exists for every scripts/*.sh referenced by commands/*.md.
# ----------------------------------------------------------------------

echo "--- Script launcher pairing ---"

mapfile -t SCRIPT_SH_NAMES < <(grep -rhE 'Bash\(\$\{CLAUDE_PLUGIN_ROOT\}/scripts/[a-z-]+\.sh' "$PROJECT_ROOT/commands/" \
    | grep -oE 'scripts/[a-z-]+\.sh' \
    | sort -u)

if (( ${#SCRIPT_SH_NAMES[@]} == 0 )); then
    fail "no scripts/*.sh references found in commands/*.md"
fi

for script_path in "${SCRIPT_SH_NAMES[@]}"; do
    name=$(basename "$script_path" .sh)
    assert_file_exists "$PROJECT_ROOT/scripts/${name}.sh"
    assert_file_exists "$PROJECT_ROOT/scripts/${name}.cmd"
done

# ----------------------------------------------------------------------
# 4. commands/*.md allowed-tools accept both .sh and .cmd spellings.
# ----------------------------------------------------------------------

echo "--- commands/*.md dual-spelling ---"

for script_path in "${SCRIPT_SH_NAMES[@]}"; do
    name=$(basename "$script_path" .sh)
    sh_re="Bash\(\\\$\{CLAUDE_PLUGIN_ROOT\}/scripts/${name}\.sh"
    cmd_re="Bash\(\\\$\{CLAUDE_PLUGIN_ROOT\}/scripts/${name}\.cmd"

    sh_files=$(grep -rlE "$sh_re" "$PROJECT_ROOT/commands/" || true)
    cmd_files=$(grep -rlE "$cmd_re" "$PROJECT_ROOT/commands/" || true)

    if [[ -z "$sh_files" ]]; then
        fail "no .sh allowed-tools entry for $name (unexpected; was discovered above)"
        continue
    fi

    while IFS= read -r f; do
        if grep -qE "$cmd_re" "$f"; then
            pass "$f accepts both .sh and .cmd for $name"
        else
            fail "$f has .sh but no .cmd allowed-tools entry for $name"
        fi
    done <<< "$sh_files"
done

# ----------------------------------------------------------------------
# 5. Each .cmd carries the expected launcher template lines.
# ----------------------------------------------------------------------

echo "--- Launcher template structure ---"

for cmd_file in "$PROJECT_ROOT/hooks/"*.cmd "$PROJECT_ROOT/scripts/"*.cmd; do
    [[ -f "$cmd_file" ]] || continue
    name=$(basename "$cmd_file" .cmd)
    assert_grep "$cmd_file" '^@echo off' "@echo off header"
    assert_grep "$cmd_file" '^setlocal[[:space:]]*$' "setlocal without delayed expansion"
    assert_grep "$cmd_file" "^\"%BASH%\" -- \"%~dp0${name}\\.sh\" %\\*$" "bash invokes sibling .sh by basename"
    assert_grep "$cmd_file" '^exit /b %errorlevel%$' "exit-code propagation"
    assert_grep "$cmd_file" 'where bash 2\^>nul' "find_bash uses where bash"
    assert_grep "$cmd_file" 'C:\\Program Files\\Git\\bin\\bash\.exe' "find_bash probes 64-bit Git Bash"
    assert_grep "$cmd_file" 'C:\\Program Files \(x86\)\\Git\\bin\\bash\.exe' "find_bash probes 32-bit Git Bash"
    assert_grep "$cmd_file" 'Humanize: bash not found\. Install Git for Windows' "stable missing-bash stderr"
    assert_grep "$cmd_file" '^exit /b 127$' "missing-bash exit code is 127"
    if grep -qE 'enabledelayedexpansion' "$cmd_file"; then
        fail "$cmd_file enables delayed expansion (must NOT, per AC-3 negative test)"
    else
        pass "$cmd_file does not enable delayed expansion"
    fi
done

# ----------------------------------------------------------------------
# 6. is_in_humanize_loop_dir handles backslash paths (BL-20260424 fix).
# ----------------------------------------------------------------------

echo "--- BL-20260424 path-normalization fix ---"

# shellcheck source=../hooks/lib/loop-common.sh
source "$PROJECT_ROOT/hooks/lib/loop-common.sh"

if is_in_humanize_loop_dir 'C:\Users\foo\.humanize\rlcr\2026-04-24_01-46-48\round-0-contract.md'; then
    pass "is_in_humanize_loop_dir matches Windows backslash form"
else
    fail "is_in_humanize_loop_dir rejects Windows backslash form (BL-20260424 regressed)"
fi

if is_in_humanize_loop_dir '/c/Users/foo/.humanize/rlcr/2026-04-24_01-46-48/round-0-contract.md'; then
    pass "is_in_humanize_loop_dir matches POSIX form"
else
    fail "is_in_humanize_loop_dir rejects POSIX form (regression)"
fi

if ! is_in_humanize_loop_dir '/some/random/path/file.md'; then
    pass "is_in_humanize_loop_dir rejects non-loop paths"
else
    fail "is_in_humanize_loop_dir accepted non-loop path (regression)"
fi

# ----------------------------------------------------------------------

echo ""
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]] || exit 1
