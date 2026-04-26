---
name: humanize-gen-idea-auto
description: Full auto pipeline — generate idea draft, create plan, and start RLCR loop. Chains gen-idea → gen-plan-auto in one command.
type: flow
user-invocable: false
disable-model-invocation: true
---

# Humanize Generate Idea Auto

Full pipeline: idea → plan → RLCR loop in one command. Accepts gen-idea arguments, plan output, and RLCR pass-through.

The installer hydrates this skill with an absolute runtime root path:

```bash
{{HUMANIZE_RUNTIME_ROOT}}
```

## Usage

```bash
/humanize:gen-idea-auto "Add undo/redo support"
/humanize:gen-idea-auto my-idea.md --max 10 --yolo
/humanize:gen-idea-auto "Quick fix" --direct --max 3
```
