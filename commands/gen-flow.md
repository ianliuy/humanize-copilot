---
description: "Generate a structured flow-definition file for any task type"
argument-hint: "<goal-description> [--output <path>]"
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

# Generate Flow Definition

This command generates a structured flow-definition file for an arbitrary task. The flow definition describes the steps, tools, deliverables, review criteria, and acceptance criteria needed to accomplish the user's goal.

The output is a structured markdown document following the flow-definition template. This command uses the artifact loop internally to iteratively refine the flow definition via Codex review.

## Workflow

1. **Parse Input**: Extract the goal description from arguments
2. **Generate Initial Flow**: Based on the goal, create a flow-definition draft
3. **Review Loop**: Use the artifact loop to iteratively refine the flow definition
4. **Output**: Write the finalized flow-definition file

## Flow Definition Schema

The generated flow-definition file follows this structure:

```markdown
# Flow Definition: <Title>

## Objective
<What the flow produces>

## Deliverables
| File Path | Type | Description |
|-----------|------|-------------|

## Steps
### Step N: <Name>
- Action: <what to do>
- Tools: <what to use>
- Output: <what files>
- Review Criteria: <how to verify>

## Dependencies
<Step ordering and parallelism>

## Acceptance Criteria
- AC-N: <criterion>

## Review Strategy
### Per-Step Review
### Overall Review

## Known Constraints
```

## Usage

```bash
/humanize:gen-flow "Create a manga with 5 pages about a cyberpunk detective"
/humanize:gen-flow "Design a mobile app UI for a todo list" --output flows/todo-app-flow.md
```

## What This Is NOT

- This command generates the DEFINITION of a flow, not the flow's deliverables
- To execute the flow, use its output as input to `/humanize:start-artifact-loop`
- The flow definition is itself a deliverable (a document) produced via the artifact loop
