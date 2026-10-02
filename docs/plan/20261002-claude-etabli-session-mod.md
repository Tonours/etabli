# Implemented: native Claude Etabli session cockpit

## Metadata
- Archived: 2026-10-02
- Source plan: `PLAN.md` — Claude Etabli mod, targeted tool/run correction and final delivery
- Source plan SHA-256: `ef09e9a509d6df34a57fe4bb418d76b428bd82ddddbb724d403fa8e858babbe4`
- Status: IMPLEMENTED
- Commit / branch: `feat/claude-etabli-mod`, base/HEAD `fd4bf728f297eae867e5115ab10e3269fb037992`; local uncommitted deliverable
- Workflow initiative: `20261002-claude-etabli-mod-tool-activity`

## Outcome

`/etabli` opens eight human-controlled native Claude views: resume objective/next/blockers/done; recorded route/reason/contract; paged chronological workflow/check/proof journal; historical permission request versus grant/refusal; explicit preflight and prospective closure; revision-bound diff/excerpts/proofs with invalidation; real usage/context/cache/limits and unknowns; source skill availability/scope/invocation conditions distinct from native command visibility. The command adds no model context, grants no permission and writes no workflow source.

A pending tool now marks the current bound session/project stale even after `/etabli run` replaces the presentation state. Completion increments activity synchronously and requests repaint without awaiting it; painting failures or hangs preserve the exact tool result/error. Seven added regressions bring the named suite to81/81. Five reproduced failures were captured before the correction (`focused-RED.log`:40pass/5fail).

## Context and source identity

The delivery lives in the managed worktree `/Users/tonours/.codex/worktrees/683c/etabli`. Final ordered sixteen-file fingerprint: `3d0b84e53cce28279d668d0511b7406ec7dda52b79de6baba834403488edc406`. Full cumulative patch: `e92cef121cb2f6dce483a07063d64650dff5534efd3d6219da498dce03b91547`,133730bytes. Baseline and final per-file hashes are retained in `.workflow/20261002-claude-etabli-mod-tool-activity/`.

Only `claude/mods/etabli/hooks/register.js`, `tests/etabli-session-mod.test.mjs` and `docs/claude-etabli-mod.md` changed in this targeted cycle. Thirteen other source paths retain their predecessor hashes. Earlier eight-view implementation and corrections remain part of the cumulative deliverable; unrelated research and the main checkout were preserved.

[initiative:20261002-claude-etabli-mod] predecessor90-event terminal ledger retained at SHA `3a4db6c39db3116c91ade8f0ee275c69e46de985320fccd6a1fbd91c098b8989`.
[initiative:20261002-claude-etabli-mod-corrections] predecessor48-event terminal ledger retained at SHA `b6cd2f9f23383f3ac470590accebfeefbd89c98525208be5e808eff919312b90`. Neither prior budget/history was reset or rewritten.

## Decisions

The tool observer reuses the original bound identity and the first in-place binding for an initially unbound state. It adds no host identity reads or pending identity observers and does not broaden global markActivity or telemetry writers. Different bound session/cwd is excluded. After an unbound reset before first binding, the old tool's origin is unknown; its completion cannot mark a newly bound replacement. This limitation is tested and documented, and requires explicit refresh/recheck for new-project effects.

Native execution, controlled hook interleavings, official test-kit simulation and image rasterization have separate evidence. A normal native Read proves host execution/output pass-through; post-turn staleness is also affected by turn.complete and is not attributed solely to tool.call. Desktop execution and successful saved-chat restoration are not verified.

## Validation Evidence

All final receipt paths below are under `.workflow/20261002-claude-etabli-mod-tool-activity/`; each check records unchanged before/after final source fingerprint.

- command: `node --unhandled-rejections=strict --test tests/etabli-session.test.mjs tests/etabli-session-mod.test.mjs tests/review-evidence-pack.test.mjs tests/workflow-run-check.test.mjs`
  - result:81/81pass (`focused-FINAL.log`, receipt).
- command: `claude plugin test claude/mods/etabli`
  - result:3/3pass (`kit-FINAL.log`); native official test engine with simulated APIs, not desktop pixels.
- command: `scripts/verify-agentic-infra core`
  - result:29/29checks pass (`core-FINAL.log`).
- command: `claude plugin validate claude/mods/etabli`; `node pi/node_modules/typescript/lib/tsc.js --project claude/mods/etabli/tsconfig.json`; `tests/session-handoff-smoke.sh`; `git diff --check`
  - result:all pass (`validator/types/handoff/diff-FINAL` receipts).
- Controlled combined tool/old-refresh/run-selection probe: `composition-FINAL.log` passes; obsolete snapshot absent and current run stale. Closed bound pane is equivalent because no ui.close handler resets its state.
- Native Claude2.1.287 terminal execution: fresh `render` and `fixturefresh` launch receipts and `native-ui/*.txt/.ansi/.json`, all8views; ordinary Read returns ETABLI_TOOL_OK; actual usage/parent cache observed; no paid counting request.
- Owned synthetic Git fixture: full decoded diff1455175bytes, preview98304bytes; explicit excerpt and evidence-page navigation; original requested ref moves with unchanged HEAD/file; repeated rechecks retain the original baseline and invalidate. `native-fixture-ref-move.json` and fixture frames.
- Native lifecycle: `/clear` discards dossier/cache; `/resume` picker cancellation discards dossier without inspecting history or claiming restoration. Save hot reload announces7hooks and resets dossier/cache. `/reload-plugins` alone retained JS state in the isolated launch. The comment-only hot-reload probe was restored byte-for-byte; all view/large-ref flows reran in fresh sessions at the final hash. [Official hot-reload behavior](https://code.claude.com/docs/en/plugins/mods/troubleshoot#editing-a-module-has-no-effect); retained `official-troubleshoot.md`.
- Final full F1 review: GO WITH NOTES, fresh isolated Logic/Spec; eight lenses and19 complete runtime deciding-code rows with outside-pin source anchors/async writers, copied verbatim in `review-F1-lead.md`. Native cross-family adversary effective `claude-opus-5-5`/firstParty, session `02a2b2ff-487f-4558-94e4-da07f8e82203`; raw GO WITH NOTES. No high or required corrective fix. `simplify: clean`; sibling-based quality pass (`quality.md`).

## Terminal image

`claude-etabli-terminal.png`:1737×1424pixels, SHA `f772e17ad3ffbb1878abedb234c07119dc050b9fc0b10b48976a49488cf19b06`. Method: monochrome Pillow rasterization of the unedited actual155×58tmux native Claude screen grid, not terminal-window pixels. `native-ui/final-screen.txt/.ansi/.json`, launch/source/TERM/version/time, rasterizer/Python/Pillow/installed-font hashes and final F1 patch are retained in `screenshot-manifest.json`. Independently recomputed and visually inspected; `screenshot-independent-check.json` passes. Native scene captured before the archive/cleanup transaction, which it truthfully lists as pending.

## Follow-up State

Remaining risks accepted as nonblocking within this narrowly authorized cycle: a legacy v1 completed→handoff tail displays its last event as terminal label (`etabli-session-projection.mjs:84`); an obsolete identity-observation rejection can demand an extra recheck in a replacement panel (`register.js:52`). Neither affects active v2 terminal authority, permissions, transfers old telemetry/cache or loses a capture. They remain explicit limitations, not claimed repaired.

Parking lot: dedicated future legacy-label/observation-error cleanup; actual desktop parity and saved-chat restoration. No commit, push, deployment or global mod installation was performed. Root cleanup and terminal completion are evidenced by the subsequent `archive_written`, `plan_removed`, final `completed` events and `autonomous-completed` validation; this immutable archive is the code/validation record rather than a prediction of those operations.

User guide: `docs/claude-etabli-mod.md`. Launch: `claude --plugin-dir "$PWD/claude/mods/etabli"`. Native hot reload and the final image do not bypass the Computer Use Terminal-app denial.
