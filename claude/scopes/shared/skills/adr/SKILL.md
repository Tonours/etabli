---
name: adr
description: >-
  Records a lightweight Architecture Decision Record for a decision made in this
  session. Use when the user invokes /adr or asks to capture an architectural
  decision, trade-off, supersession, or why a non-obvious technical choice was
  made.
argument-hint: "[optional: the decision to record]"
---

# /adr — record an Architecture Decision Record

Capture a decision made in this session as an immutable ADR. Write ADR content
in English, regardless of the conversation language. Use
`scripts/apply-adr.mjs` for deterministic file writes, numbering, supersession
metadata, and the `CLAUDE.md` index. `ADR-FORMAT.md` is the reference for exact
template and decision rules; read it when the decision needs those details.

You run inside the current session, so you already see the conversation. Do
NOT read any transcript file — synthesize the decision from what was discussed
plus the working diff.

## Procedure

1. **Identify the decision.** From the conversation (and `$ARGUMENTS` if given),
   state in one sentence what was decided. Ground it with token-light git
   evidence first: `git status --short`, `git diff --name-only`, and
   `git diff --stat`. Read targeted diffs only for files needed to understand
   the decision; avoid dumping a large full diff.

2. **Inventory existing ADRs.** If `docs/adr/` exists, read its file list,
   frontmatter, and titles. Read the latest 3 ADRs by number, expanding to 5
   only when recent history looks relevant. Search existing
   ADR titles, `tags`, `affected_components`, and body text for terms from the
   new decision, then read the full text of any likely matches. If
   `scripts/validate-adrs` exists, run `node scripts/validate-adrs` before
   drafting; stop and report any existing ADR integrity failure before adding a
   new ADR. Do not repair pre-existing ADR or `CLAUDE.md` index failures while
   recording a new decision; those must be fixed as a separate maintenance task.

   This is the anti-hallucination gate: never claim an ADR is superseded unless
   you can cite a local `docs/adr/NNNN-*.md` file and explain the relationship.
   If no grounded candidate exists, say that no supersession candidate was
   found.

3. **Apply the three-condition test** (from `ADR-FORMAT.md`):
   - hard to reverse
   - surprising without context
   - the result of a real trade-off

   If ANY condition is missing, STOP. Tell the user which condition fails and
   that no ADR will be written. Do not write a weak ADR — over-recording is the
   main failure mode.

4. **Draft on screen.** Keep it short. Show:
   - the full ADR (frontmatter + title + 1-3 sentences, plus optional sections
     only if they add value)
   - `Supersession analysis`, listing the ADR candidates considered by file path
     and the decision: supersedes ADR-NNNN, no supersession, or uncertain

   Use optional frontmatter only when useful:
   - `supersedes: ADR-NNNN` only when the new ADR replaces an existing ADR
   - `superseded_by: ADR-NNNN` only on the older ADR being superseded
   - `tags: [...]` for short retrieval categories
   - `affected_components: [...]` for concrete boundaries/components

   If the supersession is uncertain, ask the user before writing. Do not mutate
   an existing ADR from a guess.

5. **Wait for explicit approval.** Do not write any file until the user
   confirms. Incorporate their edits into the draft. If the user has already
   pre-approved in their request — e.g. "pre-approved, write directly" or
   "go ahead and write it" — treat that as the confirmation and proceed
   without a separate round-trip. The three-condition test in step 3 still
   applies: pre-approval skips the wait, never the gate.

6. **Apply with the deterministic helper.** Do not hand-edit ADR files,
   supersession metadata, or the `CLAUDE.md` index. Write a temporary JSON file
   with this shape:

   ```json
   {
     "title": "Short title",
     "body": "1-3 concise sentences in English.",
     "supersedes": "ADR-0001",
     "tags": ["storage"],
     "affected_components": ["database"]
   }
   ```

   Include `supersedes`, `tags`, and `affected_components` only when useful.
   Never include `superseded_by`; the helper owns the old ADR mutation. Run:

   ```bash
   node "$HOME/.claude/skills/adr/scripts/apply-adr.mjs" --root . --input /tmp/adr-draft.json
   ```

   If that path is unavailable, locate `scripts/apply-adr.mjs` next to this
   skill. If the helper reports an existing ADR or `CLAUDE.md` integrity
   failure, stop and report the blocker; do not repair it in the ADR write path.

7. **Report.** Use the helper JSON output as source of truth. Name the file
   written, the assigned number, whether any ADR was superseded, and whether the
   `CLAUDE.md` index was created, appended, updated, or skipped.
