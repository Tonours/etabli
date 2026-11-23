# Implemented: Enable Pi native codemode and migrate from pi-mcp-adapter to Pi built-in MCP

## Metadata
- Archived: 2026-11-23
- Source plan: `PLAN.md` — Enable Pi native codemode and migrate from pi-mcp-adapter to Pi built-in MCP
- Source plan SHA-256: `0ec73f24c13a070d0d2624eae5f2e2b9d051ce96df1d25bf08e4ef55a59d8239`
- Status: IMPLEMENTED
- Commit / branch: `feat/pi-native-codemode` (base `d90b4bfa`)
- Workflow initiative: none

## Outcome
- `pi/agent/settings.json` enables Pi's native `codemode` (`"defaultTools": ["+codemode"]`, default mode `"on"`) and drops `npm:pi-mcp-adapter@5.2.0`.
- `scripts/lib/pi-agent-settings-sync.mjs` retires `npm:pi-mcp-adapter` (pinned or unpinned, string or object), strips stale exact `"-builtin:mcp"` from local `extensions` in the same run that retires `npm:pi-mcp-adapter` (preserving other entries, deleting `extensions` when emptied, and respecting deliberate `pi config` opt-outs afterwards), merges tracked additive `defaultTools` (`+tool`) while preserving explicit `"-codemode"` opt-outs, existing `"codemode"` entries, and explicit empty `[]` allowlists, fails closed on malformed local/tracked shapes before backup or write, and supports an optional 5th `check` mode argument that reports `DRIFT ... --apply` on missing, symlinked (`lstatSync`), or drifted Pi settings without mutating files or symlinks.
- `scripts/deploy-agent-workflow --check` runs Pi settings drift checks alongside Claude tracked settings when `!claudeOnly` without invoking `seedPiSettings`.
- Added ADR-0052 (`docs/adr/0052-use-pi-native-mcp-and-codemode.md` + `docs/adr/README.md` index) with a 30-day review date (`2026-12-23`), updated `docs/symlink-layout.md` and `docs/mcp-strategy.md`, and expanded tests in `pi/extensions/__tests__/settings-consistency.test.ts`, `tests/surfaces.test.mjs`, and `tests/deploy-agent-workflow-smoke.sh`.
- Claude Code configuration and live host files were left untouched.

## Context
- Pi `1.5.0+` (pinned in `pi/package.json`, `1.6.0` live) natively ships `builtin:mcp`, `builtin:codemode`, `~/.pi/agent/mcp.json`, project `.pi/mcp.json` (with project trust), OAuth (`mcp-auth.json`), and per-server/per-tool `exposure`/`toolExposure`.
- Nested tool calls inside Pi `codemode` scripts execute via `ctx.executeTool()` and still trigger `pi.on("tool_call", ...)` guards (`no-comments.ts`, `pr-body.ts`).
- `pi-mcp-adapter` previously wrote exact `"-builtin:mcp"` into `~/.pi/agent/settings.json` `extensions`, which is also what `pi config` writes on a deliberate user opt-out.
- In Pi, `defaultTools: []` disables all built-in tools whereas `["+codemode"]` is a delta-only list that keeps `read, bash, edit, write`; preserving `[]` prevents silently re-enabling built-in tools.

## Decisions
### Scope `-builtin:mcp` removal to the adapter-retirement run
- Context: Logic hunter T1 flagged that stripping `"-builtin:mcp"` unconditionally on every sync would silently re-enable MCP after a user deliberately disables it in `pi config`.
- Choice: Strip `"-builtin:mcp"` only in the same sync run that removes an `npm:pi-mcp-adapter` package entry.
- Rejected options: Unconditional strip on every run; leaving stale `-builtin:mcp` uncleaned.
- Rationale: Automatically cleans up existing adapter-migrated hosts while remaining symmetrical with `"-codemode"` opt-out preservation afterwards.
- Consequences: Hosts where `pi-mcp-adapter` was already manually removed before deploying keep any existing `"-builtin:mcp"` until edited in `pi config`.

### Optional 5th `check` mode with `lstatSync` symlink detection
- Context: `deploy-agent-workflow --check` needed Pi drift detection without mutating files or calling `seedPiSettings`; Logic hunter T1 noted a converged symlink would pass `--check` even though `--apply` detaches it.
- Choice: Add optional 5th `mode` arg (`deploy` default | `check`) to `pi-agent-settings-sync.mjs` and emit `DRIFT ... is a symlink; run scripts/deploy-agent-workflow --apply` via `lstatSync` in `check` mode.
- Rejected options: Calling `seedPiSettings` in check mode (mutates/risks side effects); ignoring symlinks in check mode.
- Rationale: Preserves 4-arg caller compatibility and aligns `--check` drift reporting with `--apply` actions.
- Consequences: Any legacy host with symlinked `~/.pi/agent/settings.json` is flagged by `--check` until `--apply` detaches it.

### Restrict tracked `defaultTools` to additive `+tool` tokens and keep `codemode.mode` at `"on"`
- Context: Plan adversary T1 flagged ambiguity in accepting non-additive tracked tokens.
- Choice: Validate tracked `defaultTools` strictly against `/^\+[a-z0-9_-]+$/i`, append to unset/delta/non-empty plain local allowlists while preserving `[]`, `-<tool>`, and `<tool>`, and keep `codemode.mode` at default `"on"`.
- Rejected options: Wholesale `defaultTools` overwrite; switching `codemode.mode` to `"only"` before measuring `zai/glm-5.3` usage.
- Rationale: Preserves user tool choices and avoids hiding direct tools or `load_workflow_tools` behind JS.
- Consequences: Rolling back `"+codemode"` after the 2026-12-23 review requires removing the local entry on deployed hosts or adding a retirement step in `pi-agent-settings-sync.mjs`.

## Accepted Drift
- Original plan/spec: `PLAN.md` revision 1 stripped `"-builtin:mcp"` unconditionally and let converged symlinks exit 0 in `check` mode.
- Implemented reality: `"-builtin:mcp"` is stripped only during the run that retires `npm:pi-mcp-adapter`, and `check` mode flags symlinks as `DRIFT` via `lstatSync`.
- Why accepted: Resolved T1 Logic hunter findings (`medium` opt-out asymmetry, `low` check/apply symlink asymmetry) and passed D1 Logic + Code-diff adversary reviews with `Verdict: GO` and zero findings.

## Validation Evidence
- `env -u DISPLAY -u WAYLAND_DISPLAY scripts/verify-agentic-infra pi`: `SUMMARY: 5/5 checks passed` (`pi-tests` 175/175, `pi-typecheck`, `pi-audit`, `skill-lock`, `pi-import-smoke`).
- `node --test tests/surfaces.test.mjs`: `61/61 pass` (including 4 new `pi-agent-settings-sync` test suites covering all 12 regression/mutation neighbors).
- `bash tests/deploy-agent-workflow-smoke.sh`: `deploy agent workflow smoke test: ok` (including `pi-mcp-adapter` retirement, `-builtin:mcp` cleanup, `defaultTools` sync, Pi drift check, and symlink immutability/detachment).
- `node scripts/validate-adrs`: `ADR validation ok: 52 record(s), next ADR-0053.`
- `bash tests/pi-skill-load-check-smoke.sh`, `bash tests/install-smoke.sh`, `bash tests/supply-chain-smoke.sh`, `bash tests/fix-links-smoke.sh`, and all 13 `core` `shell-docs` checks: PASS.
- `.githooks/scan-secrets "$(git rev-parse origin/main)" "--all --full-history --diff-merges=first-parent"`: 3058 commits scanned, `no leaks found`.
- Reviews: Plan adversary T1 (`codex/gpt-6.1-sol`, `CHALLENGED`, 4 medium folded) -> D1 (`codex/gpt-6.1-sol`, `READY`); Code review T1 (Logic `claude-opus-5-5` `GO WITH NOTES`, Spec `claude-opus-5-5` 1 low, Adversary `gpt-6.1-sol` `GO WITH NOTES`) -> D1 (Logic `claude-opus-5-5` `GO` 0 findings, Spec `claude-opus-5-5` 1 non-blocking low, Adversary `gpt-6.1-sol` `GO` 0 findings).
- `simplify: removed 2`, `quality: pass` (`code-quality` + sibling `scripts/lib/claude-settings-sync.mjs`), `mutation: unavailable (linux has no sandbox-exec)`.

## Follow-up State
- Remaining risks:
  - Hosts with MCP servers declared only in `~/.pi/agent/mcp-adapter.json` or project `.mcp.json`, or using adapter Keychain OAuth, require manual copy to `~/.pi/agent/mcp.json` or `.pi/mcp.json` (plus Pi project trust) and `/mcp login`.
  - `mutation: unavailable (linux has no sandbox-exec)` on Linux host.
  - Pre-existing local test harness quirks noted during verification (unrelated to this change): `pi/extensions/__tests__/installed-extension-loader.test.ts` runs `bash -x pi/node_modules/.bin/pi` which triggers ImageMagick `import` when `DISPLAY`/`WAYLAND_DISPLAY` is set; 3 unrelated SIGHUP smoke tests in `shell-docs` fail when the parent shell inherits `SIG_IGN` on `SIGHUP`.
- Parking lot: Review Pi `codemode` session usage on `2026-12-23` (ADR-0052).
- Superseded docs/specs: Revises the R4 hold in `docs/plan/20261021-research-alignment.md` (historical archive untouched).
- Next links: After PR merge and `git pull` on each host, run `scripts/deploy-agent-workflow --apply` to converge `~/.pi/agent/settings.json`.
