# Implemented: optional env merging and targeted workflow context

## Metadata
- Archived: 2026-11-07
- Source plan: `PLAN.md` - retained Etabli token optimizations
- Source plan SHA-256: `e3db19e986b6a33ac0fcd02138ba14e5801e92f43b66102a91ef48936d9024c2`
- Status: IMPLEMENTED
- Commit / branch: `refactor/token-defaults`, base `b1f47978854ae01962cc09a5db943e6dded26d76`
- Workflow initiative: token-defaults

## Outcome
- Add optional merging for only `env.CLAUDE_CODE_SUBAGENT_MODEL` in the existing settings writer. Validate tracked/local shapes, preserve unrelated local values without logging them, and retain env-only drift, backup, atomic write, private mode, no-op, install and dry-run behavior.
- Leave the model env unset in the real shared fragment. Standard deployment preserves existing model choices; it does not activate Sonnet.
- For an explicitly supplied model fragment, probe `claude --version` with a 5 s timeout and 4096-byte output cap. Missing, old, unrecognized or failed probes skip the managed env key with a warning while other tracked settings still sync. This is a partial PATH check, not certification of SDK/IDE runtimes.
- Replace raw tracked/local JSON parser errors with safe classifications so malformed settings cannot expose value snippets.
- Load Fleet memory for Fleet CLI/daemon/skill work, reporting, host questions or the `Tonours/fleet` repository. `FLEET_SESSION_ID` alone no longer requires retrieval; the absent-brain exception remains.
- Preserve the original noncontractual small cases and extend the initial-route editorial exception across repository surfaces. Exclude high-risk surfaces, executable directives/prompts/heredocs, pinned contract text and semantic assertions/routes/gates/obligations/schemas/locks. Only verified generated skill hashes may accompany editorial skill text. In-flight delta escalation stays unchanged.
- Combine the local simplify/quality invocation while retaining both original scopes, evidence records, blocking behavior and rerun obligations.

## Decisions
### Preserve reviewer defaults
- The initial proposal lowered fix-verification model, council effort and the turn cap without a review-quality comparison. No reachable frozen escaped-defect corpus was found in inspected sources.
- The owner explicitly chose to preserve existing review defaults: fix verification Opus/low, council high, 200 turns. Production review launchers, isolated settings and agent frontmatters have no diff.
- No quality-equivalence claim or risk exception was made. The original high-risk gates governed this run.

### Defer shared model activation
- Native Claude Code >=2.1.251 gives per-invocation/frontmatter choices (including `inherit`) precedence over the env default; [native model resolution](https://code.claude.com/docs/en/sub-agents#choose-a-model). Older versions had different precedence. The FORCE variable is not managed.
- The initial PATH guard was insufficient: the real writer and real `claude-bin.sh` resolver with a newer PATH CLI and an older alternate runtime still wrote Sonnet. This was demonstrated with fake version binaries, without model calls.
- The owner explicitly chose to ship env support but defer global activation until every runtime consumer is verified. Removing the shared env field closes automatic activation without accepting that compatibility risk.
- An explicitly tracked future key overwrites its local value. Council user-settings filtering does not scrub exported process env, so model-less descendants may inherit it. Explicit reviewer flags remain unchanged.

## Accepted Drift
- Remove all three proposed reviewer-default changes and the shared Sonnet activation after the owner's two explicit decisions.
- Correct the scope of native defaults, remove plugin-savings assumptions, add safe parse errors and the bounded partial compatibility check in the existing writer.
- Restore original small-tier cases after Spec review and clarify editorial exclusions. No first-party skill body changed, so no lock refresh was needed.
- No Fleet source changes, Caveman installation, live settings writes, remote deployment or merge.

## Validation Evidence
- `node --test tests/surfaces.test.mjs`: baseline 33/33; initial new env suite 5 failing / 2 passing; final 44/44 passing.
- Integration cases cover secret preservation/no logs, backup/no-op/env-only drift, dry-run counts/no writes, missing-file/install/private mode, absent env, invalid shapes/keys/values, malformed JSON redaction, version boundaries/failure/missing CLI, output overflow, timeout, and the actual shared fragment.
- Real writer plus real resolver: PATH 2.1.300 / alternate 2.1.200 preserves local Opus after deferral; compatible 2.1.300 / 2.1.300 control also preserves Opus. External version binaries were faked; protection code was unmocked. No model requests.
- `scripts/verify-agentic-infra full`: 46/46 checks pass on the final implementation; surfaces 44/44 included. Workflow/scaffold/skill-load checks pass; entry chain 401/405 lines.
- `node workflow/runtime/mutation-probe.mjs --base b1f47978854ae01962cc09a5db943e6dded26d76 --test 'node --test tests/surfaces.test.mjs'`: 25 killed, 0 survivors, 0 invalid/denied/timeout on the unchanged T2 settings-sync executable. A weak error assertion found by the initial probe was strengthened before final review.
- `simplify: clean`; `quality: pass` (code-quality plus adjacent validation/atomic-write/settings patterns). No new dependency or subsystem.
- Fresh-context Logic/Spec/Threat reviews used inline hunter templates with complete deciding-code and threat tables. T1 restored the original small cases and added runtime compatibility checks; T2 exposed the alternate-runtime gap; final D1 Logic/Threat both GO with T2 Spec carried for unchanged criteria. All counting reviews ran Claude Opus5.5, requested and effective Anthropic via T3, independent of the author families.
- Final D1 code-diff adversary: GO WITH NOTES, STATUS complete, effective Claude Opus5.5 via T3. Delta SHA-256 `f7b7fcc9a478b28a97cd8d37760cc421d5d8642a01b1a0048bafc93b47da3c33`; cumulative implementation `9cf93c4b7d0dd217666061e801d171a394bea325076a3284e400760db3ce1378`; captured plan `f4621f7134ef416858d4438157aa32e9dedea6f1cfec477cf3acd0b54e8f5f46`. Low notes concern optional/inherited-default wording and 1.5 s scheduling margin in the timeout test; no unresolved runtime defect. The parent retained complete hunter tables and attack dispositions in private evidence.

## Follow-up State
- Global Sonnet activation remains deferred. Future activation must inventory and verify all CLI/SDK/IDE consumers; the PATH probe alone is insufficient.
- Native workload token/cost reduction is unmeasured. Fixture tests establish configuration behavior, not review recall or production savings.
- The isolated worktree remains available while the PR is reviewed; the original checkout is preserved. Root `PLAN.md` is removed through the archive hash gate.
