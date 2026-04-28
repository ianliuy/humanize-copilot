---
name: humanize-gen-flow
description: Generate a structured flow-definition file for any task type using the artifact loop.
type: flow
user-invocable: false
disable-model-invocation: true
allowed-tools:
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-artifact-loop.sh:*)"
  - "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-artifact-loop.cmd:*)"
  - "Read"
  - "Glob"
  - "Grep"
  - "Task"
  - "Write"
  - "AskUserQuestion"
---

# Humanize Gen-Flow

Generates a structured flow-definition file by running the artifact loop with a specialized prompt for flow-definition creation.

The flow definition describes steps, tools, deliverables, and review criteria for accomplishing an arbitrary user goal.

## Usage

```bash
/humanize:gen-flow "Create a manga about a cyberpunk detective"
```

## Output

A structured markdown file following the flow-definition template at:
`prompt-template/artifact-loop-flow/flow-definition-template.md`
