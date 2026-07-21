# Implemented: Pi settings synchronization no longer requires npm

## Metadata
- Archived: 2026-07-20
- Source plan: Keep Pi settings synchronization independent of npm availability
- Status: IMPLEMENTED
- Commit / branch: `main` (uncommitted local change)

## Outcome
- Applied the Etabli-managed local deployment; no managed local links, Codex files, Claude/Pi surfaces, or Pi settings resources required an update.
- Fixed the installer settings-resource synchronizer so it requires Node.js only, matching the runtime it invokes.
- Restored the isolated-HOME installer smoke test and the complete infrastructure suite.

## Context
- `scripts/lib/install-main.sh:127-132`: the former availability guard required npm for all callers.
- `scripts/lib/install-main.sh:322-429`: Pi settings-resource synchronization runs only an inline Node JSON transformer.
- `tests/install-smoke.sh`: the smoke fixture switches `HOME`; the asdf npm shim cannot resolve that isolated home even though Node remains runnable.

## Decisions
### Separate Node-only and Node-plus-npm guards
- Context: the JSON synchronizer was skipped whenever npm was unavailable, despite not invoking npm.
- Choice: added `node_available` and used it only for `sync_pi_agent_settings_resources`; retained `node_runtime_available` for npm-dependent helpers.
- Rejected options: alter the smoke fixture, or weaken the existing Node-and-npm guard globally.
- Rationale: preserves npm preconditions while making the JSON-only synchronization portable to the isolated environment the test models.
- Consequences: no package install behavior or tracked Pi settings changed.

## Accepted Drift
- Original plan/spec: local configuration update and verification.
- Implemented reality: the local deployment was already aligned; full verification exposed and corrected a source installer guard that prevented its isolated smoke test from passing.
- Why accepted: the source repository is the requested local configuration authority, and the patch is limited to the verified fault.

## Validation Evidence
- `bash tests/install-smoke.sh`
  - result: PASS (`install smoke test: ok`).
- `scripts/verify-agentic-infra all`
  - result: PASS; all configured shell/docs, Pi, and Neovim checks completed, including 219 Pi tests and 610 assertions.
- `bash scripts/deploy-agent-workflow --apply`
  - result: PASS; 0 Codex links changed and all Pi/Claude managed surfaces reported `OK`.
- `bash scripts/check-fix-symlinks.sh --fix`
  - result: PASS; 0 issues, 0 fixes, 0 unresolved.
- `bash scripts/deploy-agent-workflow --dry-run && bash scripts/check-fix-symlinks.sh`
  - result: PASS; no planned deployment changes and no link drift.
- Bash LSP diagnostics and `bash -n scripts/lib/install-main.sh`
  - result: PASS.

## Follow-up State
- Remaining risks: the global Pi runtime is intentionally not version-pinned by this change; no upgrade was required to align it with the repository configuration.
- Parking lot: none.
- Superseded docs/specs: none.
- Next links: `scripts/lib/install-main.sh`, `tests/install-smoke.sh`.
