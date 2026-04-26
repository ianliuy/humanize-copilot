---
description: "Generate idea, plan, and auto-start RLCR loop — full pipeline"
argument-hint: "<idea-text-or-path> [--n <int>] [--output <idea-path>] [--plan-output <plan-path>] [--discussion|--direct] [--max N] [--codex-model MODEL:EFFORT] [--codex-timeout SECONDS] [--track-plan-file] [--push-every-round] [--base-branch BRANCH] [--full-review-round N] [--skip-impl] [--claude-answer-codex] [--agent-teams] [--yolo]"
allowed-tools:
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-gen-idea-io.sh:*)"
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-gen-idea-io.cmd:*)"
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

# Generate Idea, Plan, and Auto-Start Implementation

Read and execute below with ultrathink.

This is the full auto pipeline: idea → plan → RLCR loop. It chains `/humanize:gen-idea` into `/humanize:gen-plan-auto` in a single command. Accepts gen-idea arguments, an optional `--plan-output` path, gen-plan mode flags, and RLCR pass-through arguments.

## Global Rule: AskUserQuestion Recommended-First

**Every** AskUserQuestion call within this auto command (including those inherited from gen-idea and gen-plan-auto phases) MUST:
1. Have the first choice labeled with `(Recommended)` suffix
2. The `(Recommended)` choice must be the one that **continues the pipeline** (not the one that stops/pauses)

This ensures Copilot CLI's autopilot mode auto-selects the forward-moving option at every decision point, enabling fully unattended execution.

## Argument Partitioning

Parse `$ARGUMENTS` and partition into three groups:

### Gen-idea arguments:
- First positional: `<idea-text-or-path>` (required — inline text or path to `.md` file)
- `--n <int>` (number of exploration directions, default 6)
- `--output <path>` (idea draft output path — overrides session dir default)
- `-h` / `--help`

### Gen-plan mode arguments:
- `--discussion` / `--direct`
- `--plan-output <path>` (plan file output path — overrides session dir default)

### RLCR pass-through arguments (stored for gen-plan-auto):
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

**Reject** `--plan-file`, `--auto-start-rlcr-if-converged`, `--skip-quiz`, `--input` — these are managed internally.

Store gen-plan mode args + RLCR args as `PLAN_AND_RLCR_ARGS` for the gen-plan-auto step.

## Phase 1: Session Slug, Argument Parsing, and Directory Setup

1. **Parse and validate arguments**: Reject immediately if `<idea-text-or-path>` is missing or empty (fail before any file/directory creation).

2. **Determine the session slug**:
   - If `<idea-text-or-path>` is a file path: slug = filename without `.md` extension
   - If inline text: slug = first 40 chars, lowercased, non-alphanumeric replaced with hyphens, trimmed

3. **Compute default output paths**:
   - Default idea output: `.humanize/idea-plan-auto/<slug>/idea.md` (unless `--output` was provided)
   - Default plan output: `.humanize/idea-plan-auto/<slug>/plan.md` (unless `--plan-output` was provided)

4. **Create the session directory** so that `--output` points to an existing parent when passed to the validator:
   ```bash
   SESSION_DIR=".humanize/idea-plan-auto/<slug>"
   SESSION_DIR_CREATED_BY_US=false
   if [[ ! -d "$SESSION_DIR" ]]; then
       mkdir -p "$SESSION_DIR/"
       SESSION_DIR_CREATED_BY_US=true
   fi
   ```

> **Why create before validation?** The validator checks that the output directory exists (`OUTPUT_DIR_NOT_FOUND`). When `--output` is explicit, the validator does NOT auto-create the parent directory. Creating the empty directory here is safe — no output files are written until validation passes. "Fail before file creation" means "fail before writing output files", not "fail before creating empty directories".

## Phase 2: Validate Input

Execute IO validation (the session directory already exists from Phase 1):
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-gen-idea-io.sh" <idea-text-or-path> --n <N> --output <idea-output-path>
```

**If validation fails**: Clean up the session directory only if THIS invocation created it AND it is still empty (no files from a prior session):
```bash
if [[ "$SESSION_DIR_CREATED_BY_US" == "true" ]] && find "$SESSION_DIR" -maxdepth 0 -empty | grep -q .; then
    rmdir "$SESSION_DIR"
fi
```
Do not use `rm -rf` — the directory may contain data from a prior session. Do not proceed further.

**If validation succeeds**: Continue with the session directory already in place.

Then execute the full gen-idea workflow as defined in `/humanize:gen-idea` (Phases 0-4: Parse Input, IO Validation, Direction Generation, Parallel Exploration, Synthesis and Write).

**If gen-idea fails at any phase**: Stop with clear error. Do not proceed to gen-plan. Report what went wrong.

**If gen-idea succeeds**: The idea draft is written to `<idea-output-path>`. Continue to Phase 3.

## Phase 3: Chain to Gen-Plan-Auto

After gen-idea completes successfully, immediately chain into the gen-plan-auto workflow:

Build the gen-plan-auto arguments:
```
--input <idea-output-path> --output <plan-output-path> <PLAN_AND_RLCR_ARGS>
```

Execute the full `/humanize:gen-plan-auto` workflow (which internally runs gen-plan phases + auto-start RLCR with confirmation).

**If gen-plan-auto fails**: Stop with error. Report the idea draft path so the user can manually continue:
```
Idea draft saved to: <idea-output-path>
To continue manually:
  /humanize:gen-plan --input <idea-output-path> --output <plan-output-path>
```

## Phase 4: Report

After the full pipeline completes (or stops at any point), report:
- Session directory: `.humanize/idea-plan-auto/<slug>/`
- Idea draft path (if generated)
- Plan path (if generated)
- RLCR status (if started)
- Any errors and manual recovery commands

## Error Handling

- Phase 2 (gen-idea) failure → stop, report error + no partial files beyond idea validation
- Phase 3 (gen-plan-auto) failure → stop, report error + idea draft path for manual continuation
- RLCR start failure → stop, report error + both file paths + manual RLCR command with all pass-through args
- At every failure point, provide copy-pasteable manual continuation commands
