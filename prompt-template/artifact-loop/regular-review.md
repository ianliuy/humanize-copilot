# Deliverable Review - Round {{CURRENT_ROUND}}

## Original Plan

**IMPORTANT**: The original plan is located at:
@{{PLAN_FILE}}

You MUST read this plan file first to understand the full scope of work before conducting your review.

Based on the original plan and @{{PROMPT_FILE}}, Claude claims to have completed the work. Please conduct a thorough critical review to verify this.

---
Below is Claude's summary of the work completed:
<!-- CLAUDE's WORK SUMMARY START -->
{{SUMMARY_CONTENT}}
<!-- CLAUDE's WORK SUMMARY  END  -->
---

## Part 1: Deliverable Review

- Your task is to conduct a deep critical review, focusing on finding quality issues and identifying gaps between the plan and actual deliverables produced.
- Report issues using severity markers in the first characters of each line:
  - `[P0]` Critical: Missing deliverable, completely wrong content, blocks acceptance
  - `[P1]` High: Deliverable does not address a required acceptance criterion
  - `[P2]` Medium: Quality issue (incomplete section, inconsistent content, unclear language)
  - `[P3]` Low: Minor improvement suggestion (formatting, wording)
- If Claude planned to defer any tasks to future phases in its summary, DO NOT follow its lead. Instead, you should force Claude to complete ALL tasks as planned.
  - Such deferred tasks are considered incomplete work and should be flagged in your review comments, requiring Claude to address them.
  - If Claude planned to defer any tasks, please explore the deliverables in-depth and draft a detailed action plan. This plan should be included in your review comments for Claude to follow.
  - Your review should be meticulous and skeptical. Look for any discrepancies, missing deliverables, incomplete work.
- If Claude does not plan to defer any tasks, but honestly admits that some tasks are still pending (not yet completed), you should also include those pending tasks in your review.
  - Your review should elaborate on those unfinished tasks and draft an action plan.
  - A good action plan should be **singular, directive, and definitive**, rather than discussing multiple possible options.
  - The action plan should be **unambiguous**, internally consistent, and coherent from beginning to end, so that **Claude can execute the work accurately and without error**.

## Part 2: Goal Alignment Check (MANDATORY)

Read @{{GOAL_TRACKER_FILE}} and verify:

1. **Acceptance Criteria Progress**: For each AC, is progress being made? Are any ACs being ignored?
2. **Forgotten Items**: Are there tasks from the original plan that are not tracked in Active/Completed/Deferred?
3. **Deferred Items**: Are deferrals justified? Do they block any ACs?
4. **Plan Evolution**: If Claude modified the plan, is the justification valid?

Include a brief Goal Alignment Summary in your review:
```
ACs: X/Y addressed | Forgotten items: N | Unjustified deferrals: N
```

## Part 3: {{GOAL_TRACKER_UPDATE_SECTION}}

## Part 4: Output Requirements

- Your review comments can include: problems/findings/blockers; claims that don't match reality; action plans for deferred work (to be completed now); action plans for unfinished work; goal alignment issues.
- If after your investigation the actual situation does not match what Claude claims to have completed, or there is pending work to be done, output your review comments to @{{REVIEW_RESULT_FILE}}.
- **CRITICAL**: Only output "COMPLETE" as the last line if ALL tasks from the original plan are FULLY completed with no deferrals
  - DEFERRED items are considered INCOMPLETE - do NOT output COMPLETE if any task is deferred
  - UNFINISHED items are considered INCOMPLETE - do NOT output COMPLETE if any task is pending
  - The ONLY condition for COMPLETE is: all original plan tasks are done, all ACs are met, no deferrals or pending work allowed
- The word COMPLETE on the last line will stop Claude.
