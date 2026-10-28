# Implemented: close the seven confirmed standard-audit findings

## Metadata
- Archived: 2026-10-28
- Source plan: `PLAN.md` — remediate the seven confirmed standard-audit findings
- Source plan SHA-256: `ed7a872280a31a1f1ffe913521f3b7de0c26326b7324645cdc57bf1c1d2b78b6`
- Status: IMPLEMENTED
- Commit / branch: `fix/audit-findings`, based on `7be284d7`
- Workflow initiative: audit-findings

## Outcome
All seven **confirmed** fingerprints from `~/security-audit-skill/etabli/run-2/findings.json` are addressed. Six required runtime fixes; the seventh key-preview fix already existed at the base and now has custom-provider regression coverage.

| Confirmed finding | Correction / evidence |
| --- | --- |
| `read-only-bash:gh-api-jq-env-disclosure` | Check embedded gh jq expressions, including split, attached, inline and clustered flags; safe ordinary filters and env-named repo arguments remain allowed. Hook/policy matrix covers direct and RTK-wrapped calls. |
| `gitleaks:untrusted-revision-suppression-policy` | CI and pre-push share `.githooks/scan-secrets`: isolated bare mirror, explicit built-in rules, no inline allows, ignore fingerprints only from trusted base. Real gitleaks 8.30.1 fixtures reject candidate ignore/config/inline suppressions of reverted secrets. |
| `scripts/deploy-workflow:scaffold-writes-follow-symlinked-parent-outside-target` | Extend existing physical containment to preflight and every write; walk missing parent tails, reject dangling parents, back up dangling leaves instead of following them, preserve tracked symlink protection. |
| `skills/shared/adr/scripts/apply-adr.mjs:managed-write-follows-symlinked-destination` | Preflight all managed ancestors and markdown leaves before normal/reindex/supersession writes, recheck at writeTracked, canonicalize explicit root; recompute only the ADR skill lock hash. |
| `scripts/plan-cleanup:symlinked-docs-plan-path-escape` | Refuse symlinked archive ancestry before reading/writing; exclusive discard-file creation, record before root removal. Unsafe paths leave PLAN.md intact. |
| `scripts/sync-vendor-skills:copy-first-license-symlink-dereference` | Physically confine license source to cloned upstream; reject source/destination leaf symlinks and nonregular destinations. Existing regular/subpath license selection remains. |
| `security-audit-glm:dry-run-prints-api-key` | Preserve base fix `7be284d7`; prove both dummy keys stay out of custom-provider dry-run output and actual dummy launch receives the chosen endpoint/key/model mappings. |

## Context
- Static project paths are lower-trust input. Lexical containment and `existsSync`/`-f` alone do not protect parent or dangling links.
- Gitleaks 8.30.1 loads a target-root ignore even with an explicit alternate ignore path; a separate bare scan root avoids candidate policy without mutating the checkout.
- The original standard audit ended incomplete. Its nine `needs_validation` leads and two final-wave candidates were not promoted to confirmed findings or claimed fixed here.

## Decisions
- Keep filesystem guards explicit and local: ADR skill and scaffold cleanup ship independently; sharing a new path framework would add deployment coupling.
- Only the reviewed base can authorize false-positive fingerprints. PR uses base.sha, main push uses before, existing ref push uses the advertised remote commit. New refs/initial scans have no suppression policy. Missing CI base fails closed; missing local remote object triggers full unsuppressed scanning.
- Preserve the existing conservative jq environment-token policy: JSON fields literally named `env` may also be denied; piping ordinary JSON through a safe filter remains available.
- The clean, reviewed vendor root and scanner/workflow definitions remain trusted configuration. This patch is not an OS sandbox against concurrent hostile path replacement or workflow self-modification.

## Accepted Drift
- Corrected the planned focused guard suite from agent-frontmatter validation to `tests/claude-hooks-smoke.sh` after plan adversary inspection.
- Added one shared scanner entrypoint and one existing-runner security-path fixture suite instead of duplicating CI/hook logic or adding a framework.
- Updated an old scaffold assertion to match the stronger outside-target conflict message. No weakened assertion or runtime exception was needed.

## Validation Evidence
- Red fixtures before corresponding runtime fixes: guard admitted 64 unsafe expressions; candidate fingerprint hid a reverted dummy secret; 25/26 new path cases failed; license source symlink was followed.
- `AGENTIC_INFRA_JOBS=4 scripts/verify-agentic-infra full`: **42/42 checks passed**, including Pi **62 tests**, Pi typecheck/audit, **26/26** new security-path cases, all scaffold/ADR/cleanup suites, real pinned-gitleaks suppression fixtures, license fixtures and launcher dummy-provider checks. Log: `/tmp/etabli-audit-review/full-2.log`.
- `simplify: clean` — existing guards/native operations reused, no dependency or path framework added.
- `quality: pass` — exposed code-quality skill; compared shell/JS/test siblings (`security-audit-sandbox`, `surfaces.mjs`, `surfaces.test.mjs`); new nested ternary removed. Untouched ADR rollback `.reverse()` advisory remains pre-existing.
- Cross-family plan adversary: requested/effective `zai/glm-5.3`, native provider zai/model glm-5.3 vs author openai; READY. Frozen plan hash `0162f031fd380f1cc203bdc5e2c3821e6b0f7516547df24485805157250a25b2`; accepted deltas folded.
- T1 cumulative patch: base `7be284d7`, SHA-256 `210bdbf8c32ccdf9820328bb643cc0a4a0311970bc94cefe8b26ff740399100b`, all 17 implementation/test/doc/lock files. Review-time plan hash `6cbe3a12fb8a748fe367c5fe0b6b7f99f382dd918b3a506d85f05614f053ff70`.
- Separate fresh Logic and Spec hunters through `scripts/pi-review-hunter`, native JSON capture, read/grep only, no session/extensions/skills/context/MCP: effective provider zai/model glm-5.3. Logic GO WITH NOTES with complete deciding-code/lens tables; Spec no findings. One Logic attempt timed out at 600s, reported and not counted; single 900s retry on identical patch completed.
- Separate cross-family code adversary after hunters: same requested/effective zai/glm-5.3 route, native provenance, GO WITH NOTES. No blocking/high findings; no runtime delta after reviewed patch. Native evidence: `/tmp/etabli-audit-review/{plan,T1-logic-retry,T1-spec,T1-adversary}.jsonl`.

## Follow-up State
- Remaining risks: conservative jq false denials and missing-base scanner availability; static-tree checks do not prevent concurrent hostile filesystem races; reviewed vendor parent directories remain trusted.
- Parking lot: nine needs-validation leads and two unverified final-wave candidates still need independent triage; no claim of a completely clean codebase.
- Deployment: linked main guard/skill surfaces pick up merged changes; copied per-project `plan-cleanup` requires ordinary scaffold redeployment in that project.
