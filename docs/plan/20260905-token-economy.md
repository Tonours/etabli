# Implemented: reduce recurring harness context and preserve chosen reasoning

## Metadata

- Archived: 2026-09-05 (Europe/Paris; measurements captured 2026-09-04 UTC)
- Source plan: `PLAN.md` — token economy across Claude, Codex and Pi
- Source plan SHA-256: `a1756458f442910f22a9965e87d093e29653fbe287e0c4805d5e8a36e542d4cd`
- Status: IMPLEMENTED
- Commit / branch: uncommitted local work; no push or deployment

## Outcome

Status: **verified** for measured context surfaces, tests and local application.
Provider-billed savings, prompt-cache effects and model task-quality equivalence
are **not verified**. Five candidates were resolved within the 120-minute cap;
no universal minimum or provider token percentage is claimed.

| Surface | Frozen baseline | Final | Reduction |
| --- | ---: | ---: | ---: |
| Claude description index, characters | 6141 | 4290 | 30.14% |
| Pi projected skill block, characters | 8635 | 6578 | 23.82% |
| Pi active tool description/schema metadata, UTF-16 code units | 65101 | 31353 | 51.84% |
| Codex CLI rendered catalogue, UTF-8 bytes | 19164 | 18691 | 2.47% |

These are separate populations and units. Claude retains 24 visible names and
84 configuration keys. Pi's skill metric keeps the existing pstack subtraction
convention; the unadjusted final block is 8270 characters. Codex retains the same
81 names in order, with at least 22 configured plugin skills outside the probe.

## Context and decisions

- C1: Pi's 8635-character skill projection exceeded the unchanged 7190 gate.
  Five Adonis specialists are now filtered while the suite and linked files stay
  available. Native explicit `--skill` access was also verified. The checker now
  validates configured npm keeper identity, YAML mapping, name and nonempty
  description before applying a real boolean DMI exemption.
- C2: twelve Claude descriptions are shorter; names and all non-description
  bytes remain identical. The guard is strengthened from 6510 to 4912 characters
  with exact 4912/4913 boundary fixtures. Four CSS paths are symlinks to Pi-owned
  sources. Trigger-intent examples are evidence of human review, not of model
  routing equivalence.
- C3: the global Codex budget was rejected. A native isolated loopback capture
  proved that budget 750 omits 32 of 81 names, including essential workflow skills.
  Budgets 1500/3000 preserve that partial population but cannot establish safety
  for excluded plugins. The frozen fallback shortened only the owned coolify and
  runtime-skill-canary descriptions: 739 to 268 characters. No Codex setting changed.
- C4: the Pi router no longer mutates the selected reasoning level to persistent
  xhigh. Tests cover off/low/medium/high/xhigh, following ordinary turns and task-loop
  continuations. Routing and mutation guards are unchanged.
- C5: one small `load_workflow_tools` tool enables existing Task or delegation
  groups on demand. It defers only targets active and registered at initialization,
  adds them to the current set, rechecks availability and makes repeat loads
  idempotent. Explicit CLI tool policies bypass the profile. Rollback:
  `ETABLI_EAGER_TOOLS=1 pi`.

## Accepted drift and rejected alternatives

The plan expanded from four to five candidates only after the native 65101-character
Pi tool surface was measured; the original time cap stayed unchanged. The C5
amendment passed adversarial review before implementation. The installed runtime
actually defers nine tools: its supervisor registers later and remains active.
The final criteria clarify this already-reviewed eligibility boundary without
relaxing the 40% reduction requirement. Twenty non-target definitions remain
hash-identical. Installed requests expose 22, then 29, then 31 tools; the isolated
fixture exposes 6, then 13, then 16. Only the loader executes, twice.

The upstream subagent compact mode was rejected: 8290 characters compared with
4606 for the default descriptions/guidance. Lower user-selected reasoning, output
clipping, skill deletion, provider migration and new dependencies were excluded.
After both tool groups load, the loader adds 320 metadata characters; net per-task
savings depend on actual group use, loader calls and cache behavior.

## Validation evidence

- `scripts/verify-agentic-infra core`: 18/18, including 262/262 Pi tests and
  212/212 router scenarios; `.workflow/token-economy/core-final.log`.
- `scripts/verify-agentic-infra shell-docs`: 67/67;
  `.workflow/token-economy/shell-docs-final.log`.
- Both skill-checker smoke suites, final YAML cases, TypeScript checking,
  all 66 skill-lock hashes and `git diff --check`: passed.
- `scripts/claude-skill-load-check`: `.workflow/token-economy/claude-baseline.log`,
  `claude-intermediate.log`, `claude-final.log`: 6141, 5250, 4290.
- `scripts/pi-skill-load-check`: `.workflow/token-economy/pi-baseline.log`,
  `pi-intermediate.log`, `pi-reviewed-final.log`: 8635, 6838, 6578.
- Native Pi captures and rerunnable helper:
  `.workflow/token-economy/pi-tools-probe/{summary.json,replay.sh,REPLAY.md}`.
  Parent reruns `parent-fixture.json`, `parent-lazy.json` and
  `parent-installed-load.json` confirm request schema changes before the next turn.
- Native Codex evidence:
  `.workflow/token-economy/codex-probe/after-fallback/comparison.json` and
  `configured/summary.json`; remote connections blocked during the local mock.
- All 14 description edits preserve other bytes;
  `.workflow/token-economy/description-intents.json` records trigger review.
- Native explicit Adonis access: `.workflow/token-economy/pi-explicit-skill.json`.
- Existing user changes and unrelated settings preserved:
  `.workflow/token-economy/preservation-final.json`.

No fake-provider usage entered token outcome telemetry. The outcome ledger records
usage as unmeasured; real reviewer consumption is not a before/after benchmark.

## Review and simplification

Simplify: clean. Native Pi dynamic loading and existing checker surfaces were used;
no new abstraction framework or dependency. Sibling comparison used
`pi/extensions/web-search.ts`, `scripts/claude-skill-load-check` and the Pi smoke suite.

Fresh isolated Logic and Spec hunters initially reproduced a medium false-green
for malformed YAML or an empty comment-only description on npm DMI keepers.
Accepted, fixed using the SDK's existing YAML parser, and freshly re-reviewed:
Logic GO, Spec GO, lead GO. Provenance for these Codex-native hunters is a GPT-6
self-report, not cross-model evidence. Their deciding-code and lens tables are
preserved in `.workflow/token-economy/lead-review.md`.

The subsequent independent code adversary ran through Pi with verified structured
metadata: **github-copilot / claude-sonnet-5**, stopReason=stop, exit 0,
**GO WITH NOTES**. Accepted: C5 criterion wording. Rejected with current evidence:
generic non-npm validation expansion and an unproven root-DMI catch concern.
The review assumption that all configured sources were npm was inaccurate:
18 local marker skills resolve to canonical default-root identities, while the
configured git package enables no skills. Generic git/local package validation
remains outside the npm change. Full arbitration and provider evidence are in
`.workflow/token-economy/adversary-{review.md,arbitration.md,provenance.json}`.

Reviewed implementation SHA-256:
`ef72c6c39015188b83bd0d4dcddd2b2cae0bdbe69d863e44c2511fd8a5d0b0e0`.
After review, only one report sentence changed from two tools to two calls;
runtime diffs remain identical. Final implementation patch:
`18d14b43990b7ca765eefa0e9a8f08ad622bfe3d968763f0ea062139384641a8`.
Final pre-archive plan status: READY; implementation may finish.

## Follow-up state

Local source symlinks apply the changes; only five skill filters were added to
`~/.pi/agent/settings.json`, with a private backup. Existing sessions need a new
startup or appropriate reload. Initial `claude/CLAUDE.md` and `pi/models.json`
edits remain byte-identical. No publication is performed.

The next useful measurement is matched real tasks across harnesses, with provider
input/output/cache/reasoning usage and task success judged separately. Current
context reductions justify the implementation; they do not prove task-level
savings. No required code work remains. Root PLAN.md is removed through the archive
hash gate; the completion ledger is validated afterward.

Next links: `docs/harness-token-efficiency.md`,
`.workflow/token-economy/events.jsonl`.
