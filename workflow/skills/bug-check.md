# Bug Check Contract

Shared contract for read-only Linear bug analysis across AI harnesses.

Runtime adapters may add tool syntax or source-resolution details. They must not
change the read-only boundary, evidence standard, verdict labels, or Linear MCP
source-of-truth rule.

## Purpose

Analyze a Linear bug with adversarial root-cause rigor. This is read-only: no
file edits, no implementation, no Linear comments, and no `PLAN.md` creation.

## Input

Accept a Linear URL or issue key. If the issue is absent or ambiguous, ask one
blocking question.

Use Linear MCP as the source of truth. If Linear MCP is unavailable or the issue
cannot be read, stop with `LINEAR_MCP_UNAVAILABLE` or
`LINEAR_ISSUE_NOT_FOUND`. Do not invent ticket content.

## Evidence Rule

For every claim, ask: do I know this, or am I assuming it?

- If known, cite the evidence: Linear field/comment, file, line, command, or git
  history.
- If assumed, either verify it or label it `UNVERIFIED HYPOTHESIS`.
- Do not use vague confidence words without immediately naming the evidence
  level.

## Phases

1. Fetch the Linear issue:
   - extract the ID from `/issue/<KEY>` when given a URL;
   - read title, description, labels, status, comments, attachments, diffs, and
     PR links through Linear MCP;
   - summarize reproduction, expected behavior, actual behavior, and context in
     3-5 lines;
   - if reproduction or scope is missing, ask one blocking question.
2. Analyze impacted code:
   - derive search terms from the ticket;
   - use focused search and file reads to locate candidate files;
   - read the full functions/classes involved, not isolated snippets;
   - trace execution from input to observed output;
   - list each root-cause candidate with `file:line`, mechanism, and relevant
     code context.
3. Attack the hypothesis:
   - counterexample: can the bug fail to occur under the hypothesis?
   - logical reproduction: can the ticket steps produce the observed bug through
     this cause alone?
   - edge cases: async, lifecycle, cache, permissions, feature flags, i18n,
     initial state, limits, race conditions;
   - alternatives: list at least two alternative causes and reject each with
     evidence, or keep them open;
   - blind spots: inspect tests, config, generated code, migrations, env vars,
     and git history (`git log -p -S` or `git blame`) before concluding.
4. Verdict:
   - `CERTAIN`: root cause proven by code reading, logical reproduction, and
     alternatives rejected with evidence.
   - `HIGH CONFIDENCE`: root cause very likely but one or two alternatives
     remain.
   - `UNCERTAIN`: do not conclude; list the next evidence needed.
5. Fix plan:
   - only if verdict is `CERTAIN`;
   - describe the minimal fix, files/lines, conceptual before/after, regression
     risk, and tests.

## Output

```md
## Ticket
<KEY> - <title>
Summary: <3-5 lines>

## Impacted Code
- <file:line> - <mechanism>

## Adversarial Analysis
Main hypothesis:
Alternatives rejected:
- ...
Blind spots checked:
Verdict: CERTAIN | HIGH CONFIDENCE | UNCERTAIN
Justification:

## Fix Plan
- File:
- Change:
- Risks:
- Tests:
```

## Rules

- Do not create `PLAN.md`.
- Do not edit files.
- Do not post to Linear.
- Do not implement.
- If verdict is not `CERTAIN`, stop after the analysis and name the missing
  evidence.
