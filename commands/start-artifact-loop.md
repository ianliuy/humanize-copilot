---
description: "Start iterative artifact loop for non-code deliverables"
argument-hint: "[path/to/plan.md | --plan-file path/to/plan.md] [--max N] [--codex-model MODEL:EFFORT] [--codex-timeout SECONDS] [--full-review-round N] [--skip-quiz]"
allowed-tools:
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-artifact-loop.sh:*)"
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-artifact-loop.cmd:*)"
  - "Read"
  - "Task"
  - "AskUserQuestion"
---

# Start Artifact Loop

This command starts an iterative loop for producing non-code file-based deliverables (documents, designs, flow definitions, etc.) with Codex-based review.

Unlike `start-rlcr-loop`, this loop does NOT use git-based code review (`codex review --base`). Instead, it uses summary-based Codex review to assess deliverables against the plan's acceptance criteria.

## Setup

Execute the setup script to initialize the loop:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-artifact-loop.sh" $ARGUMENTS
```

## How It Works

1. You produce deliverable files according to the implementation plan
2. Write a summary of your work to the specified summary file
3. When you try to exit, Codex reviews your summary against the plan
4. If Codex finds issues, you receive feedback and continue
5. If Codex outputs "COMPLETE", the loop enters **Deliverable Validation Phase**
6. Validation checks that all deliverable files exist and meet acceptance criteria
7. When validation passes, the loop ends

## Key Differences from RLCR Loop

| Feature | RLCR Loop | Artifact Loop |
|---------|-----------|---------------|
| Review method | `codex review --base` (git diff) | Summary-based Codex review |
| Finalize phase | Code-simplifier agent | Deliverable validator |
| State fields | Includes base_branch, base_commit, review_started | No git-specific fields |
| Loop directory | `.humanize/rlcr/` | `.humanize/artifact-loop/` |
| Deliverables | Source code files | Any file (docs, images, data) |

## Goal Tracker System

Same goal tracker system as RLCR — prevents goal drift across iterations:

### Structure
- **IMMUTABLE SECTION**: Ultimate Goal and Acceptance Criteria (set in Round 0, never changed)
- **MUTABLE SECTION**: Active Tasks, Completed Items, Deferred Items, Plan Evolution Log

### Task Tag Routing
- `coding` tag → Claude executes directly
- `analyze` tag → Execute via `/humanize:ask-codex`
- `produce` tag → Claude produces non-code deliverable files

## Important Rules

1. **Write summaries**: Always write your work summary to the specified file before exiting
2. **Maintain Goal Tracker**: Keep goal-tracker.md up-to-date with your progress
3. **Produce deliverables**: Create the actual files declared in the plan
4. **No cheating**: Do not try to exit the loop by editing state files

## Stopping the Loop

- Reach the maximum iteration count
- Codex confirms completion with "COMPLETE", followed by successful deliverable validation
