#!/bin/bash
#
# Setup Artifact Loop - Initialize a non-code iterative review loop
#
# Creates a loop directory with state.md, plan.md, and goal-tracker.md.
# Unlike setup-rlcr-loop.sh, this does NOT use git-specific fields
# (base_branch, base_commit, review_started) since artifact loops
# produce non-code deliverables reviewed via summary-only assessment.
#
# Usage:
#   setup-artifact-loop.sh [--plan-file path/to/plan.md] [--max N]
#       [--codex-model MODEL:EFFORT] [--codex-timeout SECONDS]
#       [--full-review-round N] [--skip-quiz]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Source shared library for constants and utility functions
HOOKS_LIB_DIR="$(cd "$SCRIPT_DIR/../hooks/lib" && pwd)"
source "$HOOKS_LIB_DIR/loop-common.sh"

# Source config loader
source "$SCRIPT_DIR/lib/config-loader.sh"

# ========================================
# Defaults
# ========================================

PLAN_FILE=""
MAX_ITERATIONS=42
CODEX_MODEL="$DEFAULT_CODEX_MODEL"
CODEX_EFFORT="$DEFAULT_CODEX_EFFORT"
CODEX_TIMEOUT="${DEFAULT_CODEX_TIMEOUT:-5400}"
FULL_REVIEW_ROUND=5
ASK_CODEX_QUESTION="true"
SKIP_QUIZ="false"
AGENT_TEAMS="false"

# ========================================
# Help
# ========================================

show_help() {
    cat << 'HELP_EOF'
Usage: setup-artifact-loop.sh [OPTIONS] [plan-file]

Initialize a non-code artifact loop for producing file-based deliverables.
Unlike the RLCR loop, this does not use git-based code review.

Options:
  --plan-file <path>        Path to plan file (alternative to positional arg)
  --max <N>                 Maximum iterations before auto-stop (default: 42)
  --codex-model MODEL:EFFORT  Codex model and effort (default: gpt-5.4:high)
  --codex-timeout <seconds> Codex timeout (default: 5400)
  --full-review-round <N>   Full alignment check interval (default: 5)
  --skip-quiz               Skip plan understanding quiz
  --agent-teams             Enable agent teams mode
  -h, --help                Show this help

Examples:
  setup-artifact-loop.sh path/to/plan.md
  setup-artifact-loop.sh --plan-file plan.md --max 10
HELP_EOF
    exit 0
}

# ========================================
# Parse Arguments
# ========================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --plan-file)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --plan-file requires a path" >&2
                exit 1
            fi
            PLAN_FILE="$2"
            shift 2
            ;;
        --max)
            if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --max requires a positive integer" >&2
                exit 1
            fi
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --codex-model)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --codex-model requires MODEL:EFFORT" >&2
                exit 1
            fi
            # Parse MODEL:EFFORT format
            if [[ "$2" == *:* ]]; then
                CODEX_MODEL="${2%%:*}"
                CODEX_EFFORT="${2##*:}"
            else
                CODEX_MODEL="$2"
            fi
            shift 2
            ;;
        --codex-timeout)
            if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --codex-timeout requires a positive integer" >&2
                exit 1
            fi
            CODEX_TIMEOUT="$2"
            shift 2
            ;;
        --full-review-round)
            if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -lt 2 ]]; then
                echo "Error: --full-review-round requires an integer >= 2" >&2
                exit 1
            fi
            FULL_REVIEW_ROUND="$2"
            shift 2
            ;;
        --skip-quiz)
            SKIP_QUIZ="true"
            shift
            ;;
        --agent-teams)
            AGENT_TEAMS="true"
            shift
            ;;
        --*)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
        *)
            # Positional argument: plan file
            if [[ -z "$PLAN_FILE" ]]; then
                PLAN_FILE="$1"
            else
                echo "Error: unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# ========================================
# Validate
# ========================================

if [[ -z "$PLAN_FILE" ]]; then
    echo "Error: plan file is required" >&2
    echo "Usage: setup-artifact-loop.sh [--plan-file] path/to/plan.md" >&2
    exit 1
fi

if [[ ! -f "$PLAN_FILE" ]]; then
    echo "Error: plan file not found: $PLAN_FILE" >&2
    exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Check for existing active artifact loop
ARTIFACT_LOOP_DIR="$PROJECT_ROOT/.humanize/artifact-loop"
if [[ -d "$ARTIFACT_LOOP_DIR" ]]; then
    for dir in "$ARTIFACT_LOOP_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        if [[ -f "$dir/state.md" ]]; then
            echo "Error: An artifact loop is already active" >&2
            echo "  Active loop: $dir" >&2
            echo "Only one loop can be active at a time." >&2
            echo "Cancel the artifact loop first." >&2
            exit 1
        fi
    done
fi

# ========================================
# Load Config
# ========================================

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
load_merged_config "$CLAUDE_PLUGIN_ROOT" "$PROJECT_ROOT" 2>/dev/null || true

# ========================================
# Create Loop Directory
# ========================================

TIMESTAMP=$(date -u +%Y-%m-%d_%H-%M-%S)
LOOP_DIR="$PROJECT_ROOT/.humanize/artifact-loop/$TIMESTAMP"
mkdir -p "$LOOP_DIR"

# BitLesson setup
BITLESSON_FILE_REL=".humanize/bitlesson.md"
BITLESSON_FILE="$PROJECT_ROOT/$BITLESSON_FILE_REL"
if [[ ! -f "$BITLESSON_FILE" ]]; then
    mkdir -p "$(dirname "$BITLESSON_FILE")"
    cat > "$BITLESSON_FILE" << 'BITLESSON_EOF'
# BitLesson Knowledge Base

This file is project-specific. Keep entries precise and reusable for future rounds.

## Entry Template (Strict)

Use this exact field order for every entry:

```markdown
## Lesson: <unique-id>
Lesson ID: <BL-YYYYMMDD-short-name>
Scope: <component/subsystem/files>
Problem Description: <specific failure mode with trigger conditions>
Root Cause: <direct technical cause>
Solution: <exact fix that resolved the problem>
Constraints: <limits, assumptions, non-goals>
Validation Evidence: <tests/commands/logs/PR evidence>
Source Rounds: <round numbers where problem appeared and was solved>
```

## Entries

<!-- Add lessons below using the strict template. -->
BITLESSON_EOF
fi

# ========================================
# Write State File (no git-specific fields)
# ========================================

cat > "$LOOP_DIR/state.md" << EOF
---
current_round: 0
max_iterations: $MAX_ITERATIONS
codex_model: $CODEX_MODEL
codex_effort: $CODEX_EFFORT
codex_timeout: $CODEX_TIMEOUT
push_every_round: false
full_review_round: $FULL_REVIEW_ROUND
plan_file: $PLAN_FILE
plan_tracked: false
ask_codex_question: $ASK_CODEX_QUESTION
session_id:
agent_teams: $AGENT_TEAMS
bitlesson_required: true
bitlesson_file: $BITLESSON_FILE_REL
bitlesson_allow_empty_none: true
started_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
---
EOF

# ========================================
# Copy Plan File
# ========================================

cp "$PLAN_FILE" "$LOOP_DIR/plan.md"

# ========================================
# Initialize Goal Tracker
# ========================================

PLAN_CONTENT=$(cat "$PLAN_FILE")

# Extract goal and ACs from plan
GOAL_DESC=$(echo "$PLAN_CONTENT" | sed -n '/^## Goal Description/,/^## /{/^## Goal Description/d;/^## /d;p;}')
AC_SECTION=$(echo "$PLAN_CONTENT" | sed -n '/^## Acceptance Criteria/,/^## /{/^## Acceptance Criteria/d;/^## /d;p;}')

cat > "$LOOP_DIR/goal-tracker.md" << GTEOF
# Goal Tracker

<!--
This file tracks the ultimate goal, acceptance criteria, and plan evolution.
It prevents goal drift by maintaining a persistent anchor across all rounds.

RULES:
- IMMUTABLE SECTION: Do not modify after initialization
- MUTABLE SECTION: Update each round, but document all changes
- Every task must be in one of: Active, Completed, or Deferred
- Deferred items require explicit justification
-->

## IMMUTABLE SECTION
<!-- Do not modify after initialization -->

### Ultimate Goal

$GOAL_DESC

### Acceptance Criteria
<!-- Each criterion must be independently verifiable -->
<!-- Claude must extract or define these in Round 0 -->

$AC_SECTION

---

## MUTABLE SECTION
<!-- Update each round with justification for changes -->

### Plan Version: 1 (Updated: Round 0)

#### Plan Evolution Log
<!-- Document any changes to the plan with justification -->
| Round | Change | Reason | Impact on AC |
|-------|--------|--------|--------------|
| 0 | Initial plan | - | - |

#### Active Tasks
<!-- Map each task to its target Acceptance Criterion and routing tag -->
| Task | Target AC | Status | Tag | Owner | Notes |
|------|-----------|--------|-----|-------|-------|
| [To be populated by Claude based on plan] | - | pending | coding or analyze | claude or codex | - |

### Completed and Verified
<!-- Only move tasks here after Codex verification -->
| AC | Task | Completed Round | Verified Round | Evidence |
|----|------|-----------------|----------------|----------|

### Explicitly Deferred
<!-- Items here require strong justification -->
| Task | Original AC | Deferred Since | Justification | When to Reconsider |
|------|-------------|----------------|---------------|-------------------|

### Open Issues
<!-- Issues discovered during implementation -->
| Issue | Discovered Round | Blocking AC | Resolution Path |
|-------|-----------------|-------------|-----------------|
GTEOF

# ========================================
# Create Round 0 Prompt
# ========================================

ROUND_0_SUMMARY="$LOOP_DIR/round-0-summary.md"

cat > "$LOOP_DIR/round-0-prompt.md" << R0EOF
# Round 0 - Artifact Loop

## Implementation Plan

Read @$PLAN_FILE for the full plan.

## Task Routing
- \`coding\` tasks: Execute directly
- \`analyze\` tasks: Execute via /humanize:ask-codex
- \`produce\` tasks: Produce deliverable files directly

## Goal Tracker
Initialize @$LOOP_DIR/goal-tracker.md with tasks from the plan.

## After Completing Work
1. Commit changes
2. Write summary to $ROUND_0_SUMMARY
3. Run: bash "\${CLAUDE_PLUGIN_ROOT}/scripts/artifact-loop-stop-gate.sh"
   Handle exit code: 0 = done, 10 = blocked (continue), 20 = error
R0EOF

# ========================================
# Output
# ========================================

echo "=== start-artifact-loop activated ==="
echo "Plan File: $PLAN_FILE ($(wc -l < "$PLAN_FILE") lines)"
echo "Max Iterations: $MAX_ITERATIONS"
echo "Codex Model: $CODEX_MODEL"
echo "Codex Effort: $CODEX_EFFORT"
echo "Codex Timeout: ${CODEX_TIMEOUT}s"
echo "Full Review Round: $FULL_REVIEW_ROUND (Full Alignment Checks at rounds $((FULL_REVIEW_ROUND - 1)), $((FULL_REVIEW_ROUND * 2 - 1)), $((FULL_REVIEW_ROUND * 3 - 1)), ...)"
echo "Ask User for Codex Questions: $ASK_CODEX_QUESTION"
echo "Agent Teams: $AGENT_TEAMS"
echo "Loop Directory: $LOOP_DIR"

echo "The loop is now active. After each round:"
echo "1. Commit changes and write summary"
echo "2. Run: bash \"${CLAUDE_PLUGIN_ROOT}/scripts/artifact-loop-stop-gate.sh\""
echo "3. If blocked (exit 10), read feedback and continue"
echo "4. If Codex outputs \"COMPLETE\", enters Deliverable Validation Phase"
echo "5. When validation passes, loop ends"
echo ""
echo "To cancel: /humanize:cancel-rlcr-loop"
