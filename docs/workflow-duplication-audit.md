# Workflow Duplication Audit

Stability audit of the Etabli workflow layer: where behavior is duplicated
across Pi, Claude, and `workflow/skills/`, what drift risk it creates, and what
guards it. The current loop is unchanged:

```text
plan-loop -> adversary -> implement -> validate -> review -> archive -> cleanup
```

This is a read-only map plus targeted anti-drift guards. It is not a redesign.

## Duplication map

| Surface | Pi source | Claude source | Shared contract | Drift risk |
| --- | --- | --- | --- | --- |
| Embedded `PLAN.md` fallback shape | `pi/skills/plan-loop/SKILL.md` | `claude/commands/plan-loop.md` | none (verbatim copy) | **High** — divergent shape produces different plans |
| Implementation loop | `pi/skills/{implement,plan-implement}/SKILL.md` | `claude/commands/{implement,plan-implement}.md` | `workflow/skills/implementation-loop.md` | Low — adapters are thin |
| Adversary gate | `pi/skills/adversary/SKILL.md` | `claude/commands/adversary.md` | `workflow/skills/adversary.md` | Low — adapters are thin |
| Router decision logic | `pi/extensions/lib/workflow-router-runtime.ts` | `claude/hooks/workflow-router-lib.mjs` | none (parallel impl) | Medium — divergence silently routes differently |
| Source-resolution fallback paths | each Pi skill | each Claude command | none | Accepted — harness paths differ by design |

## Guards added

1. **Embedded fallback shape parity** (`tests/workflow-docs-smoke.sh`): extracts
   the fenced `PLAN.md` shape from both `plan-loop` adapters and requires
   byte-equality. Verified to fail on divergence with a clear diff.
2. **Thin-adapter contract delegation** (`tests/workflow-docs-smoke.sh`): each
   implementation-bound adapter (`implement`, `plan-implement`, `adversary` in
   both Pi and Claude) must reference its shared `workflow/skills/` contract.
   A missing reference means the adapter drifted back to a self-contained copy.
3. **Router alignment coverage** (`pi/extensions/__tests__/workflow-router-alignment.test.ts`):
   added the two previously-uncovered critical routes — `plan-loop` (pure
   planning) and `implement` (the READY gate). The READY gate is the most
   drift-prone decision; it now asserts both harnesses agree when
   `planStatus: "ready"` and disagree on `implement` when not proven READY.

## Gap classification

### Confirmed gaps (now guarded)

- **Embedded PLAN.md fallback shape**: byte-identical 54-line block copied in
  both `plan-loop` adapters with no shared source. Guard #1 above. The shared
  contract lives in `PLAN_TEMPLATE.md` (repo root, canonical); the embedded
  shape is a last-resort fallback and is now kept in sync by test.
- **Router READY gate under-tested**: the most important routing rule (only an
  actual READY `PLAN.md` authorizes `implement`) had no cross-harness
  assertion. Guard #3 above.

### Proxy-supported (guarded by a non-targeted check)

- **Router regex divergence**: Pi (`TS`) and Claude (`JS`) keep parallel regex
  sets and branch order. The `workflow-router-alignment.test.ts` suite
  exercises 16 prompts across 14 routes and asserts route + `writeAllowed`
  parity. This is alignment-by-example, not exhaustive; it catches behavioral
  drift on representative prompts but not every regex edge. Acceptable given
  the routers must stay language-native.
- **Contract delegation drift**: adapters could silently re-grow full phase
  order instead of delegating to `workflow/skills/`. Guard #2 catches the
  presence of the contract reference (proxy for "stays thin").
- **Canonical `PLAN_TEMPLATE.md` location**: must stay at repo root only; the
  existing `workflow-docs-smoke.sh` assertion rejects copies under
  `claude/` or `pi/`.

### Unknown (low value to pursue)

- **Cosmetic harness wording in plan-loop procedure**: Pi step 1 says
  `Inspect git status --short and relevant files`, Claude says
  `Inspect repo state and relevant files`; rules order and the
  `/plan-implement` vs `plan-implement` token differ. These are intentional
  adapter-local details, not semantic drift. Forcing byte-equality here would
  add coupling without reducing real risk.
- **`spec-guide` route (Claude-only)**: has no Pi equivalent by design (Pi has
  no guided spec interview skill). Not a drift surface.

### Out of scope

- **Merging the two routers** into one shared module: they target different
  runtimes (Pi TS extension vs Claude Node hook) and must stay language-native.
  The alignment test is the right guard, not a shared implementation.
- **Extracting the embedded fallback shape into a shared file**: it is a
  last-resort fallback used only when every shared copy is missing. A shared
  source for the fallback would defeat its purpose (survive missing sources).
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
bash tests/workflow-autonomous-plan-loop-smoke.sh
git diff --check
```

Record fresh command output in the active review or implementation handoff. Do
not treat this audit note as proof that current validation passed.
