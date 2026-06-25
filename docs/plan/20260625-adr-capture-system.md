# Implemented: ADR capture system for Claude Code

## Metadata
- Archived: 2026-06-25
- Source plan: ADR capture system (auto-deployed /adr skill + opt-in signal-only Stop hook), distributed via etabli
- Status: IMPLEMENTED and validated (hook proven 6/6; /adr proven end-to-end via claude -p on 2026-06-25 — see Follow-ups)
- Commit / branch: not committed yet
- Design reference: artifact "ADR autonome — recherche & architecture"

## Outcome
Two components with deliberately different deployment status:
- Skill `/adr` (auto-deployed via `claude/skills/`): user-invoked, applies a three-condition test (hard to reverse, surprising without context, real trade-off), proposes a draft, and only after explicit human approval writes an immutable `docs/adr/NNNN-slug.md` and updates a delimited index in the project `CLAUDE.md`. This is the primary value, active for everyone with no setup.
- Hook `detect-adr-signal.mjs` (opt-in, `Stop` event in the `settings.workflow-hooks.json` fragment): when a structural file changed AND the last assistant message reads like a decision, surfaces a `systemMessage` suggesting `/adr`. No LLM call, no file write, uses `systemMessage` (not `additionalContext`) so it never resumes the turn.

## Files
- `claude/skills/adr/ADR-FORMAT.md` — created. Minimal template, 3 conditions, numbering (`max+1`), supersession, CLAUDE.md pointer format. English.
- `claude/skills/adr/SKILL.md` — created. `/adr` skill, `disable-model-invocation: true`, 7-step procedure with mandatory human approval. English.
- `claude/hooks/detect-adr-signal.mjs` — created. Signal-only Stop hook, double-signal AND, bilingual EN+FR decision markers, anti-noise via `git status --porcelain -- docs/adr`. No deps.
- `claude/settings.workflow-hooks.json` — modified. Added `Stop` block, `timeout: 5`. Existing blocks untouched.
- `claude/README.md` — modified. Documented `/adr` skill + the hook, added `skills/*` to the installed surface.

## Validation run
- Hook check suite: 6/6 PASS + `node --check` + settings JSON valid.
  - syntax OK
  - no-signal input → empty stdout, exit 0
  - primary path (`last_assistant_message`) → `systemMessage`
  - fallback path (transcript JSONL, no `last_assistant_message`) → `systemMessage`
  - non-structural file change → silent (double-signal AND not satisfied)
  - structural change but no decision marker → silent
  - anti-noise: ADR already present in `docs/adr/` → silent (proven by contrast: removing the ADR makes the same input emit)
- `git diff --stat`: 2 tracked files (+26/-1), 4 new plugin files. No out-of-scope file touched.

## Context / key decisions
- `etabli` is a dotfiles + installer repo (no `.claude-plugin/`). `scripts/install.sh` symlinks `claude/skills/*` and `claude/hooks/*.mjs` by glob, so the skill auto-deploys; the settings fragment is linked but NEVER auto-merged (the live settings file can hold secrets — `claude/README.md`), so the hook is opt-in.
- ADRs live in `docs/adr/`, one immutable file per decision; CLAUDE.md holds only a pointer index. Aligned with Nygard/MADR/Fowler/AWS/Microsoft.
- Research convergence: assisted ADR generation YES, autonomous NO; dominant risk = over-generation of low-value ADRs. Hence the skill (human-in-the-loop) carries the value, the hook only suggests.
- All plugin output in English; only the hook's lexical decision markers are bilingual EN+FR (they detect Claude's reasoning language, not the plugin's output language).
- Stop input fields verified against raw `hooks.md:2082-2084`: `stop_hook_active`, `last_assistant_message`, `background_tasks`, `session_crons` all exist. `additionalContext` resumes the turn; `systemMessage` does not.
- Project with no `CLAUDE.md`: the skill creates a minimal one (index block only) if the root is a writable git repo; imports `@AGENTS.md` if an `AGENTS.md` exists. Never writes into `AGENTS.md` (Claude Code does not read it).

## Follow-ups
- RESOLVED 2026-06-25: `/adr` validated end-to-end via `claude -p` (see archive `20260625-adr-test-suite.md`). Proven in a real run: refusal on a trivial rename (no file written), write of `0001` + CLAUDE.md index creation, write of `0002` + index updated in place without duplication.
- RESOLVED 2026-06-25: the human-approval point was settled by adding a legitimate pre-approval clause to `SKILL.md` (a user can say "pre-approved, write directly"); the three-condition gate still applies. This is what lets the write path run headless.
- Test coverage now exists: `tests/adr-hook-smoke.sh` (deterministic, 6 cases, local) and `tests/adr-skill-e2e.sh` (claude -p, manual, out of CI, ~1 USD/run).
- STILL OPEN: bootstrap of existing Forest decisions (BFF, auth JWT, capabilities) remains a separate plan, one-by-one under approval, never bulk.
- NOT COMMITTED: the whole ADR plugin (skill, hook, tests, SKILL.md pre-approval clause) is implemented and validated but not yet committed to git.
