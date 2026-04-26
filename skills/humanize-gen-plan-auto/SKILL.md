---
name: humanize-gen-plan-auto
description: Generate a structured implementation plan and auto-start RLCR loop. Wraps gen-plan with auto-start always enabled, plus RLCR parameter pass-through.
type: flow
user-invocable: false
disable-model-invocation: true
---

# Humanize Generate Plan Auto

Auto variant of gen-plan that chains directly into the RLCR implementation loop after plan generation. Accepts all gen-plan arguments plus RLCR pass-through arguments.

The installer hydrates this skill with an absolute runtime root path:

```bash
{{HUMANIZE_RUNTIME_ROOT}}
```

## Usage

```bash
/humanize:gen-plan-auto --input draft.md --output plan.md
/humanize:gen-plan-auto --input draft.md --output plan.md --max 8 --yolo
/humanize:gen-plan-auto --input draft.md --output plan.md --direct --max 5
```
