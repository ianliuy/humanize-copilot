# Deliverable Validation Phase

Codex review has passed. The deliverables are complete and all acceptance criteria have been met.

You are now in the **Deliverable Validation Phase**. This is your opportunity to verify and polish all produced deliverables before final completion.

## Your Task

Review all deliverable files produced during this artifact loop and validate them against the plan's acceptance criteria.

## Validation Checklist

For each deliverable declared in the plan:

1. **Existence**: Verify the file exists at the declared path
2. **Completeness**: Check that the deliverable addresses all relevant acceptance criteria
3. **Quality**: Assess content quality — is it clear, consistent, and well-structured?
4. **Accuracy**: Verify claims and references are correct

## Issue Reporting

Report issues using severity markers:
- `[P0]` Missing or empty deliverable file — critical, blocks completion
- `[P1]` Deliverable does not address a required acceptance criterion — high priority
- `[P2]` Quality issue (incomplete section, inconsistent content, unclear language) — medium priority
- `[P3]` Minor improvement suggestion (formatting, wording) — low priority

## Reference Files

- Original plan: @{{PLAN_FILE}}
- Goal tracker: @{{GOAL_TRACKER_FILE}}

## Before Exiting

1. Complete all validation tasks
2. Commit any final polish changes with a descriptive message
3. Write your validation summary to: **{{FINALIZE_SUMMARY_FILE}}**
4. Run the artifact loop stop gate to trigger review:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/artifact-loop-stop-gate.sh"
   ```
   Handle exit code: 0 = done, 10 = blocked (read feedback, continue), 20 = error

Your summary should include:
- Deliverables validated and their status
- Any issues found and fixed during validation
- Confirmation that all acceptance criteria are met
- Any notes about quality decisions

## Output Requirements

- If issues are found during validation, report them using the severity markers above (`[P0]` through `[P3]`). Do NOT output "COMPLETE" when issues are present.
- **CRITICAL**: Only output "COMPLETE" as the last line if ALL deliverables pass validation with no P0 or P1 issues remaining.
  - All deliverable files exist and are complete
  - All acceptance criteria are met with evidence
  - No P0 or P1 issues remain unresolved
  - P2/P3 issues may be noted but do not block COMPLETE
- The word COMPLETE on the last line will end the artifact loop.
