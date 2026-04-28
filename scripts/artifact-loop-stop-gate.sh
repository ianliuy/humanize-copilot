#!/bin/bash
#
# Artifact Loop Stop Gate
#
# Wraps hooks/artifact-loop-stop-hook.sh for non-hook environments.
# Parallel to rlcr-stop-gate.sh but routes to the artifact loop hook.
#
# Exit codes:
#   0   - Gate allowed (loop complete or no active artifact loop)
#   10  - Gate blocked (follow returned reason/instructions)
#   20  - Wrapper/runtime error
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HUMANIZE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
HOOK_SCRIPT="$HUMANIZE_ROOT/hooks/artifact-loop-stop-hook.sh"

if [[ ! -f "$HOOK_SCRIPT" ]]; then
    echo "Error: Artifact loop stop hook not found: $HOOK_SCRIPT" >&2
    exit 20
fi

# Run the hook
export PROJECT_ROOT
HOOK_OUTPUT=""
HOOK_EXIT=0
HOOK_OUTPUT=$(bash "$HOOK_SCRIPT" 2>&1) || HOOK_EXIT=$?

if [[ $HOOK_EXIT -ne 0 ]]; then
    echo "Error: Artifact loop stop hook exited with code $HOOK_EXIT" >&2
    echo "$HOOK_OUTPUT" >&2
    exit 20
fi

# Parse hook output for decision
if echo "$HOOK_OUTPUT" | grep -q '"decision".*"block"'; then
    # Blocked — extract reason and show to user
    echo "BLOCK: Artifact loop review blocked" >&2
    echo "$HOOK_OUTPUT"
    exit 10
elif echo "$HOOK_OUTPUT" | grep -q '"decision".*"finalize"'; then
    # Finalize phase — show prompt and block for finalize work
    echo "BLOCK: Entering Deliverable Validation Phase" >&2
    echo "$HOOK_OUTPUT"
    exit 10
elif echo "$HOOK_OUTPUT" | grep -q '"decision".*"continue"'; then
    # Continue — Codex found issues
    echo "BLOCK: Codex found issues to address" >&2
    echo "$HOOK_OUTPUT"
    exit 10
else
    # No block — loop complete or no active loop
    echo "$HOOK_OUTPUT"
    exit 0
fi
