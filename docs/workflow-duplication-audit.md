# Workflow Duplication Audit

Stability audit of the Etabli workflow layer: where behavior is duplicated
across Pi, Claude, Codex, and `workflow/skills/`, what drift risk it creates,
and what guards it. Last cleanup pass: 2026-07-04. The current loop is
unchanged:

```text
plan-loop -> adversary -> implement -> validate -> review -> archive -> cleanup
```

This is the current anti-duplication architecture map. Shared behavior belongs
in `workflow/skills/*.md`; harness files stay as runtime adapters.

## Duplication map

| Surface | Pi source | Claude source | Codex source | Shared contract | Drift risk |
| --- | --- | --- | --- | --- | --- |
| Embedded `PLAN.md` fallback shape | `pi/skills/plan-loop/SKILL.md` | `claude/commands/plan-loop.md` | n/a | none (verbatim copy) | **High** — divergent shape produces different plans |
| Implementation loop | `pi/skills/{implement,plan-implement}/SKILL.md` | `claude/commands/{implement,plan-implement}.md` | n/a | `workflow/skills/implementation-loop.md` | Low — adapters are thin |
| Adversary gate | `pi/skills/adversary/SKILL.md` | `claude/commands/adversary.md` | n/a | `workflow/skills/adversary.md` | Low — adapters are thin |
| Router decision logic | `pi/extensions/lib/workflow-router-runtime.ts` | `claude/hooks/workflow-router-lib.mjs` | `codex/AGENTS.md` + `codex/workflow/dynamic-workflow-triggers.md` | `workflow/spec.md` and `workflow/skills/orchestration.md` | Medium — divergence silently routes differently |
| Linear, GitHub PR, CI, bug-check, and review skills | `pi/skills/*/SKILL.md` adapters | `claude/commands/*.md` adapters | `codex/skills/linear-*` adapters | `workflow/skills/{bug-check,ci-fix,linear-*,pr-*,review,sec-pr}.md` | Low — adapters are thin and guarded |
| Ticket template fallback | `workflow/ticket-template.md` via scaffold | n/a | `codex/workflow/ticket-template.md` | `workflow/ticket-template.md` | Medium — Codex home needs a deployed fallback, but the copy must not drift from the repo canonical template |
| Codex-visible skill link lists | `scripts/install.sh` | n/a | `scripts/deploy-agent-workflow`, `scripts/check-fix-symlinks.sh` | `pi/agent/settings.json` plus `codex/skills/goal-prompt-rewriter` | Medium — bootstrap scripts must agree on which Pi/Codex skills become visible to Codex |
| Source-resolution fallback paths | each Pi skill | each Claude command | Codex global instructions | none | Accepted — harness paths differ by design |

## Guards added

1. **Embedded fallback shape parity** (`tests/workflow-docs-smoke.sh`): extracts
   the fenced `PLAN.md` shape from both `plan-loop` adapters and requires
   byte-equality. Verified to fail on divergence with a clear diff.
2. **Thin-adapter contract delegation** (`tests/workflow-docs-smoke.sh`): each
   shared-contract-backed Pi, Claude, and Codex adapter must reference its
   `workflow/skills/` contract. A missing reference means the adapter drifted
   back to a self-contained copy.
3. **Router alignment coverage** (`pi/extensions/__tests__/workflow-router-alignment.test.ts`):
   added the two previously-uncovered critical routes — `plan-loop` (pure
   planning) and `implement` (the READY gate). The READY gate is the most
   drift-prone decision; it now asserts both harnesses agree when
   `planStatus: "ready"` and disagree on `implement` when not proven READY.
4. **Codex fallback parity and contract deployment**
   (`tests/workflow-docs-smoke.sh`, `tests/codex-organization-smoke.sh`,
   `tests/deploy-agent-workflow-smoke.sh`): requires
   `codex/workflow/ticket-template.md` to stay byte-identical to
   `workflow/ticket-template.md`, and requires `scripts/deploy-codex` to expose
   root `workflow/skills/*.md` under `$CODEX_HOME/workflow/skills/`.
5. **Bootstrap list parity**
   (`pi/extensions/__tests__/settings-consistency.test.ts`): parses
   `CODEX_VISIBLE_PI_SKILLS` and `CODEX_VISIBLE_CODEX_SKILLS` from
   `scripts/install.sh`, `scripts/deploy-agent-workflow`, and
   `scripts/check-fix-symlinks.sh`, then requires the lists to match.
6. **Exact adapter duplicate scan** (`tests/workflow-docs-smoke.sh`): scans Pi,
   Claude, and Codex skill adapter files and rejects byte-identical adapter
   bodies. Intentional deployed copies must be guarded separately instead of
   hiding in harness adapters.
7. **Dynamic workflow contract scaffold** (`scripts/deploy-workflow`,
   `tests/workflow-scaffold-smoke.sh`): deploys all
   `workflow/skills/*.md` contracts by discovery, so adding a shared contract
   does not require another hardcoded scaffold list.
8. **Deterministic agent scenarios** (`tests/agent-scenarios-smoke.sh`):
   exercises route decisions, READY-guard behavior, Pi/Claude classifier parity,
   and human-checkpoint routing without spawning real LLM runtimes.
9. **Contract coverage and duplicate identity**
   (`tests/workflow-contract-coverage-smoke.sh`): every shared
   `workflow/skills/*.md` contract must be referenced or declared, deployed by
   `deploy-workflow`, and protected against silent tracked copies.

## Gap classification

### Confirmed gaps (now guarded)

- **Embedded PLAN.md fallback shape**: byte-identical 54-line block copied in
  both `plan-loop` adapters with no shared source. Guard #1 above. The shared
  contract lives in `PLAN_TEMPLATE.md` (repo root, canonical); the embedded
  shape is a last-resort fallback and is now kept in sync by test.
- **Router READY gate under-tested**: the most important routing rule (only an
  actual READY `PLAN.md` authorizes `implement`) had no cross-harness
  assertion. Guard #3 above.
- **Codex fallback copies**: `codex/workflow/ticket-template.md` remains an
  exact deployed fallback for global ticket creation and is byte-guarded.
  Former Pi/Codex `linear-work` duplication was removed; Codex now receives
  shared workflow skill contracts through `scripts/deploy-codex`.
- **Shared skill duplication**: Linear, GitHub PR, CI, bug-check, review, and
  security PR behavior used to live in separate Pi/Claude/Codex bodies. Those
  contracts now live under `workflow/skills/`; harness files are source
  resolution adapters.
- **Codex-visible skill lists**: the same link list exists in install, deploy,
  and symlink-check scripts. Guard #5 keeps the lists synchronized without
  turning bootstrap scripts into a shared-source-loader dependency.
- **Stale Pi loop implementation plan**: `docs/pi-agentic-workflow-loop-plan.md`
  was unreferenced and contradicted current state by saying there was no
  dedicated `verify` skill and by listing pre-router Pi settings. It was removed
  in the 2026-07-03 cleanup; current sources are `workflow/spec.md`,
  `workflow/skills/orchestration.md`, `docs/workflow-101.md`,
  `docs/agentic-workflow-hardening.md`, and `docs/codex-app-subagents.md`.
- **Stale workflow-scaffold best-practices audit**:
  `docs/workflow-scaffold-best-practices-audit.md` was unreferenced and still
  described already-fixed drift as a current recommendation, including the
  scaffold installed-surface map and regression-test gaps. It was removed in
  the 2026-07-03 cleanup; current scaffold contracts live in
  `workflow/spec.md`, `workflow-scaffold/templates/docs/agent-workflow.md`,
  `workflow/plan-archive.md`, and the workflow smoke tests.
- **Implemented plan batch and stale parking-lot docs**: the temporary
  `plans/001` through `plans/016` implementation batch was removed after every
  row reached `DONE` or `REJECTED`; durable context remains in `docs/plan/`.
  `docs/command-backlog.md` and `docs/fable5-notes.md` were removed because
  they were not active contracts and had no references outside the README or
  historical archives.

### Proxy-supported (guarded by a non-targeted check)

- **Router regex divergence**: Pi (`TS`) and Claude (`JS`) keep parallel regex
  sets and branch order. The `workflow-router-alignment.test.ts` suite
  exercises a broad prompt corpus and asserts normalized full-decision parity.
  This is alignment-by-example, not exhaustive; it catches behavioral drift on
  representative prompts but not every regex edge. Acceptable given the routers
  must stay language-native.
- **Contract delegation drift**: adapters could silently re-grow full phase
  order instead of delegating to `workflow/skills/`. Guard #2 catches the
  presence of the contract reference (proxy for "stays thin"), and Guard #6
  rejects exact copied adapter bodies.
- **Canonical `PLAN_TEMPLATE.md` location**: must stay at repo root only; the
  existing `workflow-docs-smoke.sh` assertion rejects copies under
  `claude/` or `pi/`.
- **Manual ADR stress scripts**: `tests/adr-skill-stress.sh` is not referenced
  by automated validation, but its header marks it as manual, out of CI, and
  cost-bearing. It is retained as an explicit manual verification surface, not
  treated as dead code.

### Unknown (low value to pursue)

- **Cosmetic harness wording in plan-loop procedure**: Pi step 1 says
  `Inspect git status --short and relevant files`, Claude says
  `Inspect repo state and relevant files`; rules order and the
  `/plan-implement` vs `plan-implement` token differ. These are intentional
  adapter-local details, not semantic drift. Forcing byte-equality here would
  add coupling without reducing real risk.
- **`spec-guide` execution surface**: the route is present in both classifiers
  and covered by parity tests. The guided interview command remains a
  Claude-command surface; future Pi execution support should add a thin adapter
  rather than changing the classifier contract.
- **Ignored `.workflow/` packets**: ignored local artifacts can be useful
  session evidence. They are not tracked and are not cleaned by repo validation;
  delete them only with explicit local-state cleanup intent.

### Out of scope

- **Merging the two routers** into one shared module: they target different
  runtimes (Pi TS extension vs Claude Node hook) and must stay language-native.
  The alignment test is the right guard, not a shared implementation.
- **Extracting the embedded fallback shape into a shared file**: it is a
  last-resort fallback used only when every shared copy is missing. A shared
  source for the fallback would defeat its purpose (survive missing sources).
- **Replacing the Codex ticket-template fallback with a symlink inside
  `codex/`**: the tracked Codex tree should not contain relative symlink
  shortcuts to root sources. `scripts/deploy-codex` may link root
  `workflow/skills/*.md` directly into `$CODEX_HOME/workflow/skills/`, but the
  ticket template fallback remains byte-guarded because it is a deliberately
  deployed Markdown copy.
- **The `tasks-till-done` runtime**: duplicated task-parse/continue logic is
  Pi-specific (Claude uses native `/goal`); covered by
  `workflow-autonomous-plan-loop-smoke.sh` and the runtime tests, not a
  cross-harness drift surface.

## Verification Checklist

```bash
bun test pi/extensions/__tests__/
bash tests/workflow-docs-smoke.sh
bash tests/workflow-scaffold-smoke.sh
bash tests/claude-hooks-smoke.sh
bash tests/agent-scenarios-smoke.sh
bash tests/workflow-contract-coverage-smoke.sh
git diff --check
```

Record fresh command output in the active review or implementation handoff. Do
not treat this audit note as proof that current validation passed.
