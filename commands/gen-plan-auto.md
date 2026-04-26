---
description: "Generate plan and auto-start RLCR loop"
argument-hint: "--input <path/to/draft.md> --output <path/to/plan.md> [--discussion|--direct] [--max N] [--codex-model MODEL:EFFORT] [--codex-timeout SECONDS] [--track-plan-file] [--push-every-round] [--base-branch BRANCH] [--full-review-round N] [--skip-impl] [--claude-answer-codex] [--agent-teams] [--yolo]"
allowed-tools:
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-gen-plan-io.sh:*)"
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-gen-plan-io.cmd:*)"
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ask-codex.sh:*)"
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ask-codex.cmd:*)"
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-rlcr-loop.sh:*)"
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-rlcr-loop.cmd:*)"
  - "Read"
  - "Glob"
  - "Grep"
  - "Task"
  - "Write"
  - "AskUserQuestion"
---

# Generate Plan and Auto-Start Implementation

Read and execute below with ultrathink.

This is the auto variant of `/humanize:gen-plan`. It runs the full gen-plan workflow and then automatically starts the RLCR implementation loop. Accepts all gen-plan arguments plus RLCR pass-through arguments.

## Argument Partitioning

Parse `$ARGUMENTS` and partition into two groups:

### Gen-plan arguments (passed to gen-plan validation and phases):
- `--input <path>` (required)
- `--output <path>` (required)
- `--discussion` / `--direct`
- `-h` / `--help`

### RLCR pass-through arguments (stored for later, passed to setup-rlcr-loop.sh):
- `--max <N>`
- `--codex-model <MODEL:EFFORT>`
- `--codex-timeout <SECONDS>`
- `--track-plan-file`
- `--push-every-round`
- `--base-branch <BRANCH>`
- `--full-review-round <N>`
- `--skip-impl`
- `--claude-answer-codex`
- `--agent-teams`
- `--yolo`
- `--allow-empty-bitlesson-none`
- `--require-bitlesson-entry-for-none`

**Reject** `--plan-file` and any positional plan path argument — this command owns the plan path via `--output`.

**Reject** `--auto-start-rlcr-if-converged` — this flag is always implicitly enabled in auto mode.

**Reject** `--skip-quiz` — this is always injected automatically.

Store RLCR args as `RLCR_PASS_THROUGH_ARGS` for use in the auto-start step. For valued flags (e.g., `--max 5`), preserve both the flag and its value. Duplicate flags: last value wins.

## Execution

Run the **exact same gen-plan workflow** as defined in `/humanize:gen-plan` (Phases 0 through 7), with these modifications:

### Global Override: AskUserQuestion Recommended-First Rule

**Every** AskUserQuestion call within this auto command MUST:
1. Have the first choice labeled with `(Recommended)` suffix
2. The `(Recommended)` choice must be the one that **continues the pipeline** (not the one that stops/pauses)

This ensures Copilot CLI's autopilot mode auto-selects the forward-moving option at every decision point. Examples:

- Codex availability: `["Continue with Claude-only planning (Recommended)", "Retry with Codex"]`
- Quantitative metrics: `["Treat as optimization trend (Recommended)", "Treat as hard requirement"]`
- Language unification: `["Keep as-is (Recommended)", "Unify to English", "Unify to Chinese"]`
- Claude/Codex disagreement: `["Accept Claude's position (Recommended)", "Accept Codex's position", "Defer"]`
- Pre-RLCR confirmation: `["Yes, start implementation (Recommended)", "No, let me review the plan first"]`

### Phase 0 Override
- Force `AUTO_START_RLCR_IF_CONVERGED=true` regardless of arguments.
- Pass only gen-plan arguments (stripped of RLCR args) to the gen-plan phases.

### Phase 8 Override: Auto-Start with Confirmation

Replace gen-plan Phase 8 Step 5 with the following:

After the plan file is written and reviewed (Steps 1-4 of Phase 8), regardless of convergence status or `--direct`/`--discussion` mode:

1. **Ask for confirmation** using AskUserQuestion:
   ```
   choices: ["Yes, start implementation (Recommended)", "No, let me review the plan first"]
   question: "Plan generated at <OUTPUT_PATH>. Ready to start the RLCR implementation loop?"
   ```

2. **If user selects "Yes, start implementation (Recommended)"**:
   Run:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/setup-rlcr-loop.sh" --skip-quiz --plan-file <OUTPUT_PATH> <RLCR_PASS_THROUGH_ARGS>
   ```
   If the script invocation is not available, fall back to:
   ```
   /humanize:start-rlcr-loop --skip-quiz <OUTPUT_PATH> <RLCR_PASS_THROUGH_ARGS>
   ```

3. **If user selects "No, let me review the plan first"**:
   Report:
   - Path to the generated plan
   - The exact manual command to start implementation later:
     ```
     /humanize:start-rlcr-loop <OUTPUT_PATH> <RLCR_PASS_THROUGH_ARGS>
     ```
   - Stop the command.

### Phase 6 Override: Direct Mode Auto-Start

When `GEN_PLAN_MODE=direct`:
- Set `PLAN_CONVERGENCE_STATUS=direct` (not `partially_converged`)
- Do NOT set `HUMAN_REVIEW_REQUIRED=true` — direct mode in auto still proceeds to the auto-start confirmation
- Skip Steps 2-4 of Phase 6 (no manual review gate in auto mode)

This overrides the standard gen-plan behavior where `--direct` blocks auto-start.

## All Other Phases

All other gen-plan phases (IO Validation, Relevance Check, Codex First-Pass, Claude Candidate Plan, Convergence Loop, Final Plan Generation) execute identically to `/humanize:gen-plan`. Refer to that command's definition for the complete workflow.

## Error Handling

- If gen-plan phases fail → stop with error, do not attempt RLCR start
- If RLCR setup fails → report failure reason and provide the manual command
- If RLCR args are invalid → report which arg is problematic (but validation happens at RLCR setup time, not during gen-plan)
