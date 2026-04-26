# Add gen-idea-auto and gen-plan-auto Skills

## Goal Description

Add two auto-chaining skills to the Humanize plugin that eliminate manual command transitions in the idea→plan→implementation pipeline. `gen-plan-auto` wraps gen-plan with auto-RLCR-start. `gen-idea-auto` chains gen-idea→gen-plan-auto into a single command. Both support all RLCR parameter pass-through for full control. Prerequisite: port `gen-idea` from PolyArch/humanize dev branch.

## Acceptance Criteria

- AC-1: gen-idea ported from dev branch
  - Positive Tests:
    - `commands/gen-idea.md` exists and is callable as `/humanize:gen-idea`
    - `scripts/validate-gen-idea-io.sh` validates input/output paths correctly
    - `prompt-template/idea/gen-idea-template.md` exists with correct placeholders
    - gen-idea produces a structured idea draft file
  - Negative Tests:
    - Missing idea input → exit 1
    - Missing template → exit 7
    - Output file already exists → exit 4

- AC-2: gen-plan-auto command auto-chains to RLCR
  - Positive Tests:
    - Accepts all gen-plan args (`--input`, `--output`, `--discussion`, `--direct`)
    - Accepts RLCR pass-through args (`--max`, `--codex-model`, `--yolo`, `--push-every-round`, `--base-branch`, `--full-review-round`, `--skip-impl`, `--claude-answer-codex`, `--agent-teams`)
    - RLCR args stripped before passing to gen-plan validation
    - `--discussion` mode: converge then AskUserQuestion → auto-start RLCR with `--skip-quiz` + pass-through args
    - `--direct` mode: write plan v1 then AskUserQuestion → auto-start RLCR with `--skip-quiz` + pass-through args
    - AskUserQuestion first choice = `"Yes, start implementation (Recommended)"`
    - User selects No → prints plan path + full manual RLCR command with all pass-through args
  - Negative Tests:
    - `--plan-file` rejected (auto owns plan path)
    - Invalid gen-plan args still rejected by existing validator
    - RLCR pass-through args do not interfere with gen-plan validation
  - AC-2.1: Duplicate pass-through flags handled deterministically (last value wins)

- AC-3: gen-idea-auto chains idea→plan→RLCR
  - Positive Tests:
    - Accepts all gen-idea args (`<idea-text-or-path>`, `--n`, `--output`) plus `--plan-output` plus RLCR pass-through args
    - Session dir `.humanize/idea-plan-auto/<slug>/` created with `idea.md` and `plan.md`
    - After gen-idea completes, auto-chains into gen-plan-auto with idea output as `--input`
    - Full pipeline: idea text → structured draft → converged plan → running RLCR loop
  - Negative Tests:
    - gen-idea failure stops cleanly without starting gen-plan
    - gen-plan failure stops cleanly without starting RLCR
    - Missing idea input → error before any file creation

- AC-4: Windows .cmd support
  - Positive Tests:
    - `scripts/validate-gen-idea-io.cmd` exists and delegates to `.sh` via bash
    - Windows users can run gen-idea and auto commands
  - Negative Tests:
    - Missing bash → clear error message with install instructions

- AC-5: Skills for all platforms
  - Positive Tests:
    - `skills/humanize-gen-idea-auto/SKILL.md` exists with correct allowed-tools
    - `skills/humanize-gen-plan-auto/SKILL.md` exists with correct allowed-tools
  - Negative Tests:
    - Skills without required allowed-tools fail to invoke scripts

- AC-6: Backward compatibility and new tests
  - Positive Tests:
    - Existing gen-plan, gen-idea, start-rlcr-loop behavior unchanged
    - All existing tests pass
    - New tests: RLCR arg stripping, frontmatter validation, Windows shim parity
  - Negative Tests:
    - No new required config fields break existing configs

- AC-7: Installer and docs updated
  - Positive Tests:
    - `scripts/install-skill.sh` skill list includes new skills
    - `docs/usage.md` documents auto commands
    - README mentions auto pipeline
  - Negative Tests:
    - Installer omitting new skills → skill not discoverable

## Path Boundaries

### Upper Bound (Maximum Acceptable Scope)
Full implementation of gen-idea port, both auto commands with complete RLCR pass-through, skills for all platforms, comprehensive tests (arg stripping, frontmatter, shim parity, pass-through construction), and complete documentation updates.

### Lower Bound (Minimum Acceptable Scope)
gen-idea port, both auto command `.md` files with basic RLCR pass-through, `.cmd` launcher for gen-idea validator, minimal skill entries, and updated install-skill.sh.

### Allowed Choices
- Can use: existing command-to-command chaining pattern (gen-plan → start-rlcr-loop)
- Can use: existing `.cmd` wrapper pattern for Windows support
- Can use: RLCR arg stripping in command `.md` body (no new scripts needed)
- Cannot use: modifications to existing gen-plan, gen-idea, or start-rlcr-loop commands

## Feasibility Hints and Suggestions

### Conceptual Approach

**gen-plan-auto.md** body:
1. Parse `$ARGUMENTS`, separate gen-plan args from RLCR pass-through args
2. Run gen-plan phases 0-7 with gen-plan args (internally force `--auto-start-rlcr-if-converged`)
3. Replace Phase 8 Step 5: always AskUserQuestion with `["Yes, start implementation (Recommended)", "No, let me review the plan first"]`
4. If Yes: invoke `setup-rlcr-loop.sh --skip-quiz --plan-file <plan.md> <RLCR-pass-through-args>`
5. If No: print plan path + manual command

**gen-idea-auto.md** body:
1. Parse `$ARGUMENTS`, separate gen-idea args, `--plan-output`, and RLCR pass-through args
2. Create session dir `.humanize/idea-plan-auto/<slug>/`
3. Run gen-idea with `--output .humanize/idea-plan-auto/<slug>/idea.md`
4. Chain to gen-plan-auto with `--input <idea.md> --output <plan.md> <RLCR-pass-through-args>`

### Relevant References
- `commands/gen-plan.md` — existing gen-plan with auto-start mechanism
- `commands/start-rlcr-loop.md` — RLCR startup with all supported args
- `scripts/validate-gen-idea-io.sh` — gen-idea validator (from dev branch)
- `scripts/validate-gen-plan-io.cmd` — `.cmd` wrapper pattern reference
- `skills/humanize-gen-plan/SKILL.md` — skill registration pattern

## Dependencies and Sequence

### Milestones
1. **Port gen-idea**: Copy from dev branch + create .cmd wrapper
   - Phase A: Copy commands/gen-idea.md
   - Phase B: Copy scripts/validate-gen-idea-io.sh + create .cmd
   - Phase C: Copy prompt-template/idea/gen-idea-template.md

2. **Create gen-plan-auto**: Command + allowed-tools
   - Phase A: Write commands/gen-plan-auto.md with auto-start logic
   - Phase B: Verify RLCR arg stripping works

3. **Create gen-idea-auto**: Command + session dir logic
   - Phase A: Write commands/gen-idea-auto.md with chaining logic
   - Phase B: Verify full pipeline

4. **Skills and packaging**: Platform coverage
   - Phase A: Create skills/humanize-gen-idea-auto/SKILL.md
   - Phase B: Create skills/humanize-gen-plan-auto/SKILL.md
   - Phase C: Update install-skill.sh

5. **Tests and docs**: Validation
   - Phase A: Tests for arg stripping, frontmatter, shim parity
   - Phase B: Update docs/usage.md, README, install guides

M2 depends on M1. M3 depends on M2. M4 and M5 can partially overlap with M3.

## Task Breakdown

| Task ID | Description | Target AC | Tag | Depends On |
|---------|-------------|-----------|-----|------------|
| task1 | Port gen-idea.md from PolyArch/humanize dev | AC-1 | coding | - |
| task2 | Port validate-gen-idea-io.sh from dev + create .cmd | AC-1, AC-4 | coding | - |
| task3 | Port gen-idea-template.md from dev | AC-1 | coding | - |
| task4 | Write commands/gen-plan-auto.md with auto-start + RLCR pass-through | AC-2 | coding | task1 |
| task5 | Write commands/gen-idea-auto.md with session dir + chaining | AC-3 | coding | task1, task4 |
| task6 | Create skills/humanize-gen-plan-auto/SKILL.md | AC-5 | coding | task4 |
| task7 | Create skills/humanize-gen-idea-auto/SKILL.md | AC-5 | coding | task5 |
| task8 | Update install-skill.sh with new skills | AC-7 | coding | task6, task7 |
| task9 | Update docs (usage.md, README, install guides) | AC-7 | coding | task4, task5 |
| task10 | Analyze RLCR arg surface for pass-through completeness | AC-2 | analyze | - |

## Claude-Codex Deliberation

### Agreements
- Port gen-idea as prerequisite before auto commands
- RLCR arg stripping in command body (no new validator scripts)
- Session dir `.humanize/idea-plan-auto/<slug>/` for vertical organization
- AskUserQuestion with `Yes (Recommended)` for autopilot compatibility
- `--skip-quiz` always injected by auto commands
- `--direct` allowed in gen-plan-auto (skips convergence, still auto-starts)
- Both commands and skills needed for all-platform coverage

### Resolved Disagreements
- **Arg validation strategy** (R1): Codex suggested new validator scripts. Resolved: strip RLCR args in command body before calling existing validators. Simpler, no new scripts.
- **--direct behavior** (R1): Codex noted gen-plan blocks direct-mode auto-start. Resolved: gen-plan-auto overrides that condition, allowing direct auto-start per user decision (DEC-1).
- **gen-plan-auto arg surface** (R1): Codex noted it needs RLCR args too, not just gen-plan args. Resolved: AC-2 updated to accept gen-plan + RLCR pass-through.

### Convergence Status
- Final Status: `converged` (Round 2: no REQUIRED_CHANGES, no UNRESOLVED)

## Pending User Decisions

- DEC-1: --direct behavior in gen-plan-auto
  - Decision Status: `Allowed. Skips convergence, directly enters RLCR. Future use: time-constrained tasks.`

- DEC-2: RLCR parameter pass-through
  - Decision Status: `All RLCR params pass through gen-idea-auto (--max, --codex-model, --yolo, etc.)`

- DEC-3: Auto session directory structure
  - Decision Status: `.humanize/idea-plan-auto/<slug>/ stores idea.md + plan.md`

- DEC-4: Pre-RLCR confirmation
  - Decision Status: `AskUserQuestion. First choice = Yes, start implementation (Recommended). Copilot autopilot auto-selects.`

- DEC-5: Platform coverage
  - Decision Status: `Both commands/*.md AND skills/*/SKILL.md`

## Implementation Notes

### Code Style Requirements
- Implementation code and comments must NOT contain plan-specific terminology such as "AC-", "Milestone", "Step", "Phase", or similar workflow markers
- These terms are for plan documentation only, not for the resulting codebase
- Use descriptive, domain-appropriate naming in code instead

--- Original Design Draft Start ---

# Draft: Add gen-idea-auto and gen-plan-auto Skills

## Problem

Currently, Humanize's workflow requires manual chaining between three skills:

1. `/humanize:gen-idea` — transforms a loose idea into a structured draft
2. `/humanize:gen-plan` — transforms a draft into a structured plan with AC criteria
3. `/humanize:start-rlcr-loop` — starts iterative implementation from a plan

Each transition requires the user to manually copy the output path and invoke the next command. This is unnecessary friction — when the user wants to go end-to-end, they should be able to say "here's my idea, run with it" and have Humanize handle the entire pipeline.

## Goal

Add two new skills that automate the chaining:

### 1. `/humanize:gen-plan-auto`

- Accepts the **same arguments** as `/humanize:gen-plan`
- Internally runs gen-plan with `--auto-start-rlcr-if-converged` and `--discussion` always enabled
- When gen-plan converges and there are no pending user decisions, automatically starts the RLCR loop
- If convergence fails or user decisions are pending, falls back to normal gen-plan behavior (user must manually start RLCR)

### 2. `/humanize:gen-idea-auto`

- Accepts the **same arguments** as `/humanize:gen-idea`
- After gen-idea completes, automatically chains into gen-plan-auto using the idea output as `--input`
- The user can optionally pass `--plan-output <path>` to control where the plan goes (default: auto-generated)
- Full pipeline: idea → draft → plan → RLCR loop, one command

## Prerequisite

The `gen-idea` skill (currently only on PolyArch/humanize `dev` branch) must first be ported to this fork. Required files:

- `commands/gen-idea.md` — the gen-idea command definition
- `scripts/validate-gen-idea-io.sh` — IO validation script
- `scripts/validate-gen-idea-io.cmd` — Windows .cmd launcher (needs to be created, doesn't exist in dev)
- `prompt-template/idea/gen-idea-template.md` — idea draft template

## Design Principles

- **Same args, different default behavior** — auto skills accept the same parameters as their non-auto counterparts, they just default to "keep going" instead of "stop and wait"
- **Graceful degradation** — if any auto-chain step fails, the user gets the partial output and a clear message about what to do next
- **No new scripts** — auto commands are implemented as SKILL.md command files that internally invoke the existing skills/scripts with the right flags
- **Copilot CLI first** — these skills work in Copilot CLI (the user's primary environment)

## Constraints

- Backward compatibility: existing gen-idea, gen-plan, and start-rlcr-loop must not change
- The auto skills must respect all existing Humanize hooks and validators
- Windows support via .cmd launchers where applicable

--- Original Design Draft End ---
