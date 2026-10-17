# Implemented: English-only docs, refreshed MCP and vendor docs, dead links removed

## Metadata
- Archived: 2026-10-17
- Source plan: `PLAN.md` — English-only docs, refreshed against live state, duplicates merged
- Source plan SHA-256: `f121b331cfe9cd497e30544bc706983d8c3c6ba9f5b99630a004930e72032c38`
- Status: IMPLEMENTED
- Commit / branch: `main`, from `0a6f1b34`
- Workflow initiative: none

## Outcome
- `GLOSSARY.md`, `extras/README.md`, the `pr-autoreview` prompt and its four repo profiles are English. The Slack report stays French (pinned in the prompt, French template labels).
- `docs/mcp-strategy.md` keeps ownership rules, memory vaults (`alambic-brain`, `alambic-obvault`, chosen by GitHub org), a `Linear MCP gap` section (cited by two Linear contracts), security and name-only drift commands; the dated inventory is gone.
- `mcp/servers.template.json`: alambic entries with `ALAMBIC_ROOT`/`ALAMBIC_STATE_DIR` placeholders; `runtimeAssignments` and `scope` dropped (no reader).
- `docs/vendor-skills.md` merged into `vendor/README.md` (mattpocock count fixed to 8) and deleted.
- `SECURITY.md` drops the pre-public checklist (repo is public); `workflow/spec.md` drops the removed classifier; `claude/README.md` documents skill governance and the two machine-local lists.
- Dangling tracked symlink `claude/skills/herdr` removed (herdr now comes from dotfiles).

## Context
- `pr-autoreview` is live on macbook-work (4 enrolled repos), served through `~/.claude/scripts/pr-autoreview` symlink; `run.sh` renders 8 placeholders and gates on `{{DONE_FILE}}`.
- French scan over tracked files found prose only in the 7 translated files; the rest is data.

## Decisions
### Keep French where it is data
- Context: "everything in English" vs functional French.
- Choice: keep `write-direct` voice examples, quoted French user triggers in the spec route table, test inputs, ADR and plan archives, and the French Slack output labels.
- Rejected options: translating triggers (would stop matching French requests) or rewriting records.
- Rationale: these strings are matched or emitted, not instructions.
- Consequences: the French scan has a fixed exemption list.

## Accepted Drift
- Original plan/spec: scope did not list `claude/skills/herdr`.
- Implemented reality: deleted as a dangling tracked symlink with no reader.
- Why accepted: within "faire le ménage", no route or behavior change.

## Validation Evidence
- command: `scripts/verify-agentic-infra full`
  - result: 37/37 PASS
- command: `cd pi && bun test extensions/__tests__/ && bun run typecheck`
  - result: 62 pass, 0 fail, tsc clean
- command: `bash tests/pr-review-gates-smoke.sh`; prompt placeholder diff
  - result: PASS; placeholders identical (25 occurrences)
- command: review
  - result: T1 Logic/Spec GO WITH NOTES, adversary x2 GO WITH NOTES; D1 Logic GO, adversary GO WITH NOTES

## Follow-up State
- Remaining risks: `claude-skill-load-check` needs the dotfiles herdr link (pre-existing); README "live deploy" leaves the dry-run/HOME conditions implicit.
- Parking lot: none.
- Superseded docs/specs: `docs/vendor-skills.md` (into `vendor/README.md`).
- Next links: `docs/mcp-strategy.md`, `vendor/README.md`, `claude/README.md` § Skill governance.
