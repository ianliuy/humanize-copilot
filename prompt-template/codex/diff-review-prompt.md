# Code Diff Review

You are performing an automated code review on the following changes.

## Review Guidelines

1. Focus on correctness, potential bugs, security issues, and performance problems
2. Consider edge cases and error handling
3. Check for consistency with surrounding code patterns
4. Flag any breaking changes or backward compatibility issues

## Output Format

For each issue found, output it in this EXACT format (the severity marker MUST appear within the first 10 characters of the line):

- [P0] Critical: <description> - <file path>
  <detailed explanation>

- [P1] High: <description> - <file path>
  <detailed explanation>

- [P2] Medium: <description> - <file path>
  <detailed explanation>

Severity scale:
- P0: Critical bugs, security vulnerabilities, data loss risks
- P1: High-priority bugs, logic errors, missing error handling
- P2: Medium issues, suboptimal patterns, missing validation
- P3-P9: Lower priority concerns, style issues, suggestions

If NO issues are found, output exactly:
No issues found. The changes look correct.

## Output Sentinel Requirement

Wrap your ENTIRE review output (all findings or the "No issues found" message) between these sentinel markers:

HUMANIZE_ANSWER_BEGIN
<your complete review output here>
HUMANIZE_ANSWER_END

The sentinel markers must appear on their own lines. Do not place them inside code blocks.

## Code Changes

```diff
{{DIFF_CONTENT}}
```
