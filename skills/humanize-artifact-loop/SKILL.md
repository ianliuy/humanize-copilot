---
name: humanize-artifact-loop
description: Start an iterative artifact loop for non-code deliverables with Codex-based summary review.
type: flow
user-invocable: false
disable-model-invocation: true
allowed-tools:
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-artifact-loop.sh:*)"
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-artifact-loop.cmd:*)"
  - "Read"
  - "Task"
  - "AskUserQuestion"
---

# Humanize Artifact Loop (Non-Code Deliverables)

Use this flow to produce file-based deliverables (documents, designs, flow definitions) through an iterative review loop.

Unlike the RLCR loop, this does not use git-based code review. Review is summary-based only.

## Required Sequence

### 1. Setup

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-artifact-loop.sh" $ARGUMENTS
```

### 2. Work Round

For each round:
1. Read current loop prompt from `.humanize/artifact-loop/<timestamp>/round-<N>-prompt.md`
2. Produce deliverable files
3. Commit changes
4. Write summary to `.humanize/artifact-loop/<timestamp>/round-<N>-summary.md`
5. Run stop gate:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/rlcr-stop-gate.sh"
   ```
6. Handle gate result: 0 = done, 10 = blocked, 20 = error

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `path/to/plan.md` | Plan file path | Required |
| `--plan-file <path>` | Explicit plan path | - |
| `--max N` | Maximum iterations | 42 |
| `--codex-model MODEL:EFFORT` | Codex model and effort | gpt-5.4:high |
| `--codex-timeout SECONDS` | Codex timeout | 5400 |
| `--full-review-round N` | Full alignment interval | 5 |
| `--skip-quiz` | Skip plan understanding quiz | false |

## Cancel

Cancel by removing the active state.md or running `/humanize:cancel-rlcr-loop`.
