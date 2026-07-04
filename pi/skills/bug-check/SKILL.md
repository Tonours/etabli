---
name: bug-check
description: Analyze a bug from a Linear issue with adversarial root-cause rigor. Use when the user asks to analyze, investigate, diagnose, or understand a bug from a Linear URL or issue key without implementing the fix.
---

# Bug Check

Read and follow the shared contract in `workflow/skills/bug-check.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/bug-check.md`.
2. If missing, fall back to the Pi agent shared copy:
   `../../workflow/skills/bug-check.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../../workflow/skills/bug-check.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/bug-check.md`.

Rules:
- This skill is read-only.
- Do not create `PLAN.md`.
- Do not edit files, post to Linear, or implement.
