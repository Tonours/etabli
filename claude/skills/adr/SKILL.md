---
name: adr
description: Record an Architecture Decision Record for a decision made in this session. Reads the conversation and the working diff, applies the three-condition test (hard to reverse, surprising without context, real trade-off), proposes a draft for human approval, then writes an immutable docs/adr/NNNN-slug.md and updates the CLAUDE.md index. User-invoked only — run /adr when you want to capture a decision.
disable-model-invocation: true
argument-hint: "[optional: the decision to record]"
---

# /adr — record an Architecture Decision Record

Capture a decision made in this session as an immutable ADR. Everything you
write is in **English**, regardless of the conversation language. Read
`ADR-FORMAT.md` (next to this file) for the template, numbering, and
supersession rules.

You run inside the current session, so you already see the conversation. Do
NOT read any transcript file — synthesize the decision from what was discussed
plus the working diff.

## Procedure

1. **Identify the decision.** From the conversation (and `$ARGUMENTS` if given),
   state in one sentence what was decided. Run `git diff` and
   `git status --porcelain` to ground it in what actually changed.

2. **Apply the three-condition test** (from `ADR-FORMAT.md`):
   - hard to reverse
   - surprising without context
   - the result of a real trade-off

   If ANY condition is missing, STOP. Tell the user which condition fails and
   that no ADR will be written. Do not write a weak ADR — over-recording is the
   main failure mode.

3. **Draft on screen.** Show the full ADR (frontmatter + title + 1-3 sentences,
   plus optional sections only if they add value). If it supersedes an existing
   ADR, say which and how.

4. **Wait for explicit approval.** Do not write any file until the user
   confirms. Incorporate their edits into the draft. If the user has already
   pre-approved in their request — e.g. "pre-approved, write directly" or
   "go ahead and write it" — treat that as the confirmation and proceed
   without a separate round-trip. The three-condition test in step 2 still
   applies: pre-approval skips the wait, never the gate.

5. **Write the ADR.**
   - Create `docs/adr/` if it does not exist.
   - Number = `max(existing NNNN) + 1`, zero-padded to 4 digits. Scan
     `docs/adr/` for the current max; never reuse a number even if there are
     gaps.
   - Write `docs/adr/NNNN-slug.md` with `status: accepted` and today's date.
   - If it supersedes ADR-MMMM: flip that file's `status` to
     `superseded by ADR-NNNN` and add a back-link. That status flip is the only
     edit ever allowed on an existing ADR.

6. **Update the CLAUDE.md index** (pointer, not the ADR body — see
   `ADR-FORMAT.md`):
   - Target is ALWAYS `CLAUDE.md` at the project root. Claude Code reads
     `CLAUDE.md`, not `AGENTS.md`.
   - If `CLAUDE.md` exists: update the block between
     `<!-- ADR:INDEX:START -->` and `<!-- ADR:INDEX:END -->` in place. If the
     markers are absent, append the block once. Never duplicate the block.
   - If `CLAUDE.md` does not exist and the project root is a writable git repo:
     create a minimal `CLAUDE.md` containing only the index block. If an
     `AGENTS.md` exists, put `@AGENTS.md` as the first line so both agents share
     instructions. Add no other rules.
   - If the project root is not a writable git repo: write the ADR anyway and
     tell the user the pointer was skipped.

7. **Report.** Name the file written, the assigned number, and whether the
   CLAUDE.md index was created or updated.
