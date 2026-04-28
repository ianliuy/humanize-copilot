#!/bin/bash
#
# Artifact Loop Stop Hook
#
# Summary-only review for non-code deliverables.
# Sources hooks/lib/loop-common.sh for shared functions:
#   parse_state_file(), detect_review_issues(), end_loop(),
#   MARKER_COMPLETE, MARKER_STOP, EXIT_* constants
#
# Unlike loop-codex-stop-hook.sh, this hook does NOT:
#   - Run `codex review --base` (no git-diff code review)
#   - Use review_started / base_branch / base_commit state fields
#   - Invoke code-simplifier finalize
#
# Instead it:
#   - Runs summary-based Codex review (regular or full-alignment)
#   - On COMPLETE, enters deliverable validation (finalize) directly
#   - Uses [P0-9] severity from review output (same regex)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared library (per BL-20260427-frozen-state-backend: read from state, not re-detect)
source "$SCRIPT_DIR/lib/loop-common.sh"

# ========================================
# Find Active Artifact Loop (session-aware)
# ========================================

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ARTIFACT_LOOP_BASE="$PROJECT_ROOT/.humanize/artifact-loop"

# Read hook input from stdin and extract session ID
HOOK_INPUT=""
HOOK_SESSION_ID=""
if [[ ! -t 0 ]]; then
    HOOK_INPUT=$(cat)
    if [[ -n "$HOOK_INPUT" ]] && command -v jq &>/dev/null; then
        HOOK_SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null) || true
    fi
fi

LOOP_DIR=""
STATE_FILE=""
IN_FINALIZE="false"

# Use shared find_active_loop for session-filtered resolution
if [[ -d "$ARTIFACT_LOOP_BASE" ]]; then
    LOOP_DIR=$(find_active_loop "$ARTIFACT_LOOP_BASE" "$HOOK_SESSION_ID") || true
fi

if [[ -n "$LOOP_DIR" ]]; then
    # Determine state file and finalize status
    if [[ -f "$LOOP_DIR/finalize-state.md" ]]; then
        STATE_FILE="$LOOP_DIR/finalize-state.md"
        IN_FINALIZE="true"
    elif [[ -f "$LOOP_DIR/state.md" ]]; then
        STATE_FILE="$LOOP_DIR/state.md"
    else
        LOOP_DIR=""
    fi
fi

# No active artifact loop — exit silently (allow other hooks to run)
if [[ -z "$LOOP_DIR" ]]; then
    exit 0
fi

# ========================================
# Parse State
# ========================================

if ! parse_state_file "$STATE_FILE"; then
    echo "Error: Failed to parse artifact loop state file: $STATE_FILE" >&2
    exit 1
fi

CURRENT_ROUND="${STATE_CURRENT_ROUND:-0}"
MAX_ITERATIONS="${STATE_MAX_ITERATIONS:-42}"
PLAN_FILE="${STATE_PLAN_FILE:-}"
CODEX_MODEL="${STATE_CODEX_MODEL:-$DEFAULT_CODEX_MODEL}"
CODEX_EFFORT="${STATE_CODEX_EFFORT:-$DEFAULT_CODEX_EFFORT}"
CODEX_TIMEOUT="${STATE_CODEX_TIMEOUT:-5400}"
FULL_REVIEW_ROUND="${STATE_FULL_REVIEW_ROUND:-5}"

# Derive loop timestamp from directory name
LOOP_TIMESTAMP="$(basename "$LOOP_DIR")"

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CACHE_DIR="$HOME/.cache/humanize/artifact-loop-$LOOP_TIMESTAMP"
mkdir -p "$CACHE_DIR"

# ========================================
# Finalize Phase Handler (MUST run before normal review)
# Finalize rounds skip summary check, max-iterations,
# and normal Codex review — go directly to validation.
# ========================================

GOAL_TRACKER_FILE="$LOOP_DIR/goal-tracker.md"

if [[ "$IN_FINALIZE" == "true" ]]; then
    FINALIZE_SUMMARY="$LOOP_DIR/finalize-summary.md"
    if [[ ! -f "$FINALIZE_SUMMARY" || ! -s "$FINALIZE_SUMMARY" ]]; then
        jq -n \
            --arg reason "Finalize summary missing. Write deliverable validation results to $FINALIZE_SUMMARY" \
            --arg msg "Write your deliverable validation summary to $FINALIZE_SUMMARY" \
            '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
        exit 0
    fi

    # Run deliverable validator review through Codex
    FINALIZE_TEMPLATE="$CLAUDE_PLUGIN_ROOT/prompt-template/artifact-loop/finalize-deliverable-prompt.md"
    if [[ -f "$FINALIZE_TEMPLATE" ]]; then
        VALIDATOR_PROMPT=$(cat "$FINALIZE_TEMPLATE")
        VALIDATOR_PROMPT="${VALIDATOR_PROMPT//\{\{PLAN_FILE\}\}/$PLAN_FILE}"
        VALIDATOR_PROMPT="${VALIDATOR_PROMPT//\{\{GOAL_TRACKER_FILE\}\}/$GOAL_TRACKER_FILE}"
        VALIDATOR_PROMPT="${VALIDATOR_PROMPT//\{\{FINALIZE_SUMMARY_FILE\}\}/$FINALIZE_SUMMARY}"

        # Append finalize summary using safe substitution
        FINALIZE_CONTENT=$(cat "$FINALIZE_SUMMARY")
        VALIDATOR_PROMPT="${VALIDATOR_PROMPT}

--- Finalize Summary ---
${FINALIZE_CONTENT}
--- End Finalize Summary ---"

        VALIDATOR_LOG="$CACHE_DIR/finalize-validator.log"
        VALIDATOR_RESULT="$LOOP_DIR/finalize-review-result.md"

        echo "Running deliverable validation review..." >&2
        REVIEW_CLI="${STATE_REVIEW_CLI:-codex}"
        REVIEW_EXIT=0
        run_prompt_exec "$VALIDATOR_PROMPT" "$CODEX_MODEL" "$CODEX_EFFORT" \
            "$PROJECT_ROOT" "$CODEX_TIMEOUT" "$REVIEW_CLI" \
            > "$VALIDATOR_LOG" 2>&1 || REVIEW_EXIT=$?
        if [[ $REVIEW_EXIT -ne 0 ]]; then
            echo "Warning: Deliverable validator CLI returned exit $REVIEW_EXIT" >&2
        fi

        if [[ -f "$VALIDATOR_LOG" && -s "$VALIDATOR_LOG" ]]; then
            VALIDATOR_CONTENT=$(cat "$VALIDATOR_LOG")
            echo "$VALIDATOR_CONTENT" > "$VALIDATOR_RESULT"

            # Check for [P0-9] issues using shared detect_review_issues
            REVIEW_ISSUES=""
            DETECT_EXIT=0
            cp "$VALIDATOR_LOG" "$CACHE_DIR/round-${CURRENT_ROUND}-codex-review.log" 2>/dev/null || true
            REVIEW_ISSUES=$(detect_review_issues "$CURRENT_ROUND") || DETECT_EXIT=$?
            if [[ "$DETECT_EXIT" -eq 0 ]] && [[ -n "$REVIEW_ISSUES" ]]; then
                echo "Deliverable validator found issues. Continue fixing." >&2
                jq -n \
                    --arg reason "Deliverable validator found [P0-9] issues in finalize review." \
                    --arg msg "$VALIDATOR_CONTENT" \
                    '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
                exit 0
            fi

            # Check for COMPLETE marker
            VALIDATOR_LAST=$(echo "$VALIDATOR_CONTENT" | sed '/^[[:space:]]*$/d' | tail -1 | tr -d '[:space:]')
            if [[ "$VALIDATOR_LAST" == "$MARKER_COMPLETE" ]]; then
                echo "Deliverable validation passed. Ending artifact loop." >&2
                end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_COMPLETE"
                exit 0
            fi
        fi

        # Validator didn't produce clear result
        jq -n \
            --arg reason "Deliverable validator did not produce a clear COMPLETE. Review and retry." \
            --arg msg "Validator result unclear. Check $VALIDATOR_RESULT and retry." \
            '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
        exit 0
    fi

    # No finalize template — just complete
    end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_COMPLETE"
    exit 0
fi

# ========================================
# Check Summary File (non-finalize only)
# ========================================

SUMMARY_FILE="$LOOP_DIR/round-${CURRENT_ROUND}-summary.md"

if [[ ! -f "$SUMMARY_FILE" || ! -s "$SUMMARY_FILE" ]]; then
    echo "========================================" >&2
    echo "BLOCKED: Summary file missing or empty" >&2
    echo "Write your work summary to: $SUMMARY_FILE" >&2
    echo "========================================" >&2

    # Return block instruction
    jq -n \
        --arg reason "Summary file missing or empty. Write your summary to $SUMMARY_FILE before trying to exit." \
        --arg step "Write summary, then try again" \
        '{"decision": "block", "reason": $reason, "next_step": $step}'
    exit 0
fi

# ========================================
# Max Iterations Check
# ========================================

if [[ $CURRENT_ROUND -ge $MAX_ITERATIONS ]]; then
    echo "Max iterations reached ($MAX_ITERATIONS). Ending loop." >&2
    end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_MAXITER"
    exit 0
fi

# ========================================
# Build Review Prompt
# ========================================

SUMMARY_CONTENT=$(cat "$SUMMARY_FILE")
REVIEW_RESULT_FILE="$LOOP_DIR/round-${CURRENT_ROUND}-review-result.md"

# Determine review type (full alignment at configured intervals)
FULL_ALIGNMENT_CHECK="false"
if [[ $FULL_REVIEW_ROUND -gt 0 ]] && [[ $(( (CURRENT_ROUND + 1) % FULL_REVIEW_ROUND )) -eq 0 ]]; then
    FULL_ALIGNMENT_CHECK="true"
fi

# Select review template
if [[ "$FULL_ALIGNMENT_CHECK" == "true" ]]; then
    REVIEW_TEMPLATE="$CLAUDE_PLUGIN_ROOT/prompt-template/artifact-loop/full-alignment-review.md"
else
    REVIEW_TEMPLATE="$CLAUDE_PLUGIN_ROOT/prompt-template/artifact-loop/regular-review.md"
fi

if [[ ! -f "$REVIEW_TEMPLATE" ]]; then
    echo "Error: Review template not found: $REVIEW_TEMPLATE" >&2
    exit 1
fi

# Build review prompt with variable substitution
PROMPT_FILE="$LOOP_DIR/round-${CURRENT_ROUND}-prompt.md"
DOCS_PATH="$PROJECT_ROOT/docs"
COMPLETED_ITERATIONS=$((CURRENT_ROUND + 1))
PREV_ROUND=$((CURRENT_ROUND - 1))
PREV_PREV_ROUND=$((CURRENT_ROUND - 2))

# Read template and substitute variables
# Use split-and-concat for SUMMARY_CONTENT (may contain & and \) per BL-20260428-bash-patsub-replacement
REVIEW_PROMPT=$(cat "$REVIEW_TEMPLATE")
REVIEW_PROMPT="${REVIEW_PROMPT//\{\{CURRENT_ROUND\}\}/$CURRENT_ROUND}"

# Safe substitution for untrusted content (summary may contain &, \, $)
_placeholder="{{SUMMARY_CONTENT}}"
_before="${REVIEW_PROMPT%%"$_placeholder"*}"
_after="${REVIEW_PROMPT#*"$_placeholder"}"
REVIEW_PROMPT="${_before}${SUMMARY_CONTENT}${_after}"

REVIEW_PROMPT="${REVIEW_PROMPT//\{\{PLAN_FILE\}\}/$PLAN_FILE}"
REVIEW_PROMPT="${REVIEW_PROMPT//\{\{PROMPT_FILE\}\}/$PROMPT_FILE}"
REVIEW_PROMPT="${REVIEW_PROMPT//\{\{REVIEW_RESULT_FILE\}\}/$REVIEW_RESULT_FILE}"
REVIEW_PROMPT="${REVIEW_PROMPT//\{\{GOAL_TRACKER_FILE\}\}/$GOAL_TRACKER_FILE}"
REVIEW_PROMPT="${REVIEW_PROMPT//\{\{DOCS_PATH\}\}/$DOCS_PATH}"
REVIEW_PROMPT="${REVIEW_PROMPT//\{\{LOOP_TIMESTAMP\}\}/$LOOP_TIMESTAMP}"
REVIEW_PROMPT="${REVIEW_PROMPT//\{\{COMPLETED_ITERATIONS\}\}/$COMPLETED_ITERATIONS}"
REVIEW_PROMPT="${REVIEW_PROMPT//\{\{PREV_ROUND\}\}/$PREV_ROUND}"
REVIEW_PROMPT="${REVIEW_PROMPT//\{\{PREV_PREV_ROUND\}\}/$PREV_PREV_ROUND}"

# Goal tracker update section (safe — controlled content, no untrusted data)
GOAL_TRACKER_UPDATE_SECTION="Goal Tracker Update

Update @$GOAL_TRACKER_FILE:
- Move completed tasks from Active to Completed
- Update task status for in-progress items
- Add any new issues discovered
- Log plan evolution if the plan changed"
REVIEW_PROMPT="${REVIEW_PROMPT//\{\{GOAL_TRACKER_UPDATE_SECTION\}\}/$GOAL_TRACKER_UPDATE_SECTION}"

# Save review prompt for audit trail
REVIEW_PROMPT_FILE="$LOOP_DIR/round-${CURRENT_ROUND}-review-prompt.md"
echo "$REVIEW_PROMPT" > "$REVIEW_PROMPT_FILE"

# ========================================
# Run Codex Review (summary-based only)
# ========================================

echo "Running Codex summary review for artifact loop (round $CURRENT_ROUND)..." >&2

# Run review through shared CLI helper
CODEX_LOG="$CACHE_DIR/round-${CURRENT_ROUND}-codex-review.log"
REVIEW_CLI="${STATE_REVIEW_CLI:-codex}"
REVIEW_EXIT=0
run_prompt_exec "$REVIEW_PROMPT" "$CODEX_MODEL" "$CODEX_EFFORT" \
    "$PROJECT_ROOT" "$CODEX_TIMEOUT" "$REVIEW_CLI" \
    > "$CODEX_LOG" 2>&1 || REVIEW_EXIT=$?
if [[ $REVIEW_EXIT -ne 0 ]]; then
    echo "Warning: Review CLI returned exit $REVIEW_EXIT" >&2
fi
if [[ ! -f "$CODEX_LOG" || ! -s "$CODEX_LOG" ]]; then
    echo "Error: Review CLI produced no output (exit $REVIEW_EXIT)" >&2
    jq -n \
        --arg reason "Review CLI failed with exit $REVIEW_EXIT and produced no output." \
        --arg msg "Check $CODEX_LOG for details. Retry the stop gate." \
        '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
    exit 0
fi

# ========================================
# Parse Review Output
# ========================================

if [[ ! -f "$CODEX_LOG" || ! -s "$CODEX_LOG" ]]; then
    echo "Error: Codex review produced no output" >&2
    jq -n \
        --arg reason "Codex review produced no output. Retry." \
        --arg step "Try running the stop gate again" \
        '{"decision": "block", "reason": $reason, "next_step": $step}'
    exit 0
fi

REVIEW_CONTENT=$(cat "$CODEX_LOG")

# Save review result
echo "$REVIEW_CONTENT" > "$REVIEW_RESULT_FILE"

# Extract last non-empty line for marker detection
LAST_LINE_TRIMMED=$(echo "$REVIEW_CONTENT" | sed '/^[[:space:]]*$/d' | tail -1 | tr -d '[:space:]')

# ========================================
# Decision Logic
# ========================================

# Check for [P0-9] severity issues using shared detect_review_issues from loop-common.sh
if [[ -f "$REVIEW_RESULT_FILE" ]]; then
    REVIEW_ISSUES=""
    DETECT_EXIT=0
    # Copy review result to the location detect_review_issues expects
    cp "$REVIEW_RESULT_FILE" "$CACHE_DIR/round-${CURRENT_ROUND}-codex-review.log" 2>/dev/null || true
    REVIEW_ISSUES=$(detect_review_issues "$CURRENT_ROUND") || DETECT_EXIT=$?
    if [[ "$DETECT_EXIT" -eq 0 ]] && [[ -n "$REVIEW_ISSUES" ]]; then
        echo "Codex review found [P0-9] issues. Continuing artifact loop..." >&2
        LAST_LINE_TRIMMED=""
    fi
fi

# STOP marker — circuit breaker
if [[ "$LAST_LINE_TRIMMED" == "$MARKER_STOP" ]]; then
    echo "========================================" >&2
    echo "CIRCUIT BREAKER TRIGGERED" >&2
    echo "Codex detected stagnation in artifact loop (Round $CURRENT_ROUND)." >&2
    echo "========================================" >&2
    end_loop "$LOOP_DIR" "$STATE_FILE" "$EXIT_STOP"
    exit 0
fi

# COMPLETE marker — enter deliverable validation (finalize)
if [[ "$LAST_LINE_TRIMMED" == "$MARKER_COMPLETE" ]]; then
    echo "========================================" >&2
    echo "Codex confirmed all deliverables complete (Round $CURRENT_ROUND)." >&2
    echo "Entering Deliverable Validation Phase..." >&2
    echo "========================================" >&2

    # Load finalize prompt
    FINALIZE_TEMPLATE="$CLAUDE_PLUGIN_ROOT/prompt-template/artifact-loop/finalize-deliverable-prompt.md"
    FINALIZE_SUMMARY_FILE="$LOOP_DIR/finalize-summary.md"
    FINALIZE_PROMPT=""
    if [[ -f "$FINALIZE_TEMPLATE" ]]; then
        FINALIZE_PROMPT=$(cat "$FINALIZE_TEMPLATE")
        FINALIZE_PROMPT="${FINALIZE_PROMPT//\{\{PLAN_FILE\}\}/$PLAN_FILE}"
        FINALIZE_PROMPT="${FINALIZE_PROMPT//\{\{GOAL_TRACKER_FILE\}\}/$GOAL_TRACKER_FILE}"
        FINALIZE_PROMPT="${FINALIZE_PROMPT//\{\{FINALIZE_SUMMARY_FILE\}\}/$FINALIZE_SUMMARY_FILE}"
    fi

    # Rename state for finalize phase
    mv "$STATE_FILE" "$LOOP_DIR/finalize-state.md"

    jq -n \
        --arg reason "All deliverables confirmed complete. Entering Deliverable Validation Phase." \
        --arg msg "$FINALIZE_PROMPT" \
        '{"decision": "block", "reason": $reason, "systemMessage": $msg}'
    exit 0
fi

# No terminal marker — continue with feedback
echo "Codex review has feedback. Continuing artifact loop..." >&2

# Increment round
NEXT_ROUND=$((CURRENT_ROUND + 1))
sed -i "s/^current_round: .*/current_round: $NEXT_ROUND/" "$STATE_FILE"

# Build next round prompt
NEXT_PROMPT_FILE="$LOOP_DIR/round-${NEXT_ROUND}-prompt.md"
NEXT_SUMMARY_FILE="$LOOP_DIR/round-${NEXT_ROUND}-summary.md"

FOOTER_TEMPLATE="$CLAUDE_PLUGIN_ROOT/prompt-template/artifact-loop/next-round-footer.md"
FOOTER=""
if [[ -f "$FOOTER_TEMPLATE" ]]; then
    FOOTER=$(cat "$FOOTER_TEMPLATE")
    FOOTER="${FOOTER//\{\{NEXT_SUMMARY_FILE\}\}/$NEXT_SUMMARY_FILE}"
fi

cat > "$NEXT_PROMPT_FILE" << NEXT_EOF
# Round $NEXT_ROUND - Artifact Loop

## Codex Review Feedback (Round $CURRENT_ROUND)

$REVIEW_CONTENT

## Your Task

Address ALL issues raised in the Codex review above. Then:
1. Update the goal tracker
2. Commit your changes
3. Write your summary to $NEXT_SUMMARY_FILE

$FOOTER
NEXT_EOF

jq -n \
    --arg reason "Codex review found issues. Address them in round $NEXT_ROUND." \
    --arg msg "Read $NEXT_PROMPT_FILE for instructions. Write summary to $NEXT_SUMMARY_FILE. Run artifact-loop-stop-gate.sh when done." \
    '{"decision": "block", "reason": $reason, "systemMessage": $msg}'

exit 0
