# Implemented: recurring findings become constraints in the subject project's own tooling

## Metadata
- Archived: 2026-10-13
- Source plan: `PLAN.md` — les findings récurrents deviennent des contraintes dans l'outillage du projet cible (le code comme mémoire)
- Source plan SHA-256: `95d81e471cf29ba91925cd9492accc1c0cfaa6a3432a038586fc1d7bddfe7daa`
- Status: IMPLEMENTED
- Commit / branch: `feat/project-constraints` (uncommitted at archive time)
- Workflow initiative: project-constraints

## Outcome
- `project-verification discover` reports an additive `constraints: [{ tool, path }]` field listing linter and type-checker config at the root, `apps/*/` and `packages/*/` (eslint, ember-template-lint, stylelint, typescript, biome, oxlint, ruff, mypy, pyright, pyproject, clippy, golangci-lint, ast-grep). Presence only: no constraint-file content is read; the existing `package.json` metadata read is unchanged.
- New cold contract `workflow/project-constraints.md`, deployed by `scripts/deploy-workflow`: a recurring mistake on a project's code takes the first rung that can express it (type, existing linter rule, structural test, CI check, prose last), ships with a case failing before and passing after, removes the prose it replaces, and is never auto-applied.
- `workflow-ship-metrics` recommends a candidate project constraint for `finding/*` rows observed only in `code_review` that reach three mapped families; every other row keeps its previous recommendation.
- `escaped-defect.md` gains `action: project_constraint` and a `constraint:` field; the dead "reviewer improvement loop contract" reference is gone.
- Pointers: `contract-details.md` Golden principles, scaffold `AGENTS.md`, README adoption paragraph, `docs/workflow-statistics.md`, ADR-0030.

## Context
- `scripts/lib/workflow-patterns.mjs`: a three-family recurrence detector already existed; it is reused, no new registry.
- `scripts/workflow-context-budget`: `spec-map` had 2 chars of headroom and `contract-details.md` 2 lines, so the rule lives in a cold contract and only a pointer was added.
- `scripts/lib/project-verification-source.mjs:16` (`confinedFile`) refuses every symlink; constraint candidates follow the same policy.

## Decisions
### Etabli owns the loop, never framework rules
- Context: etabli serves projects on many frameworks.
- Choice: detect where constraints live and route a recurring mistake there; ship no per-framework rule.
- Rejected options: shipping framework rule packs; running linters inside discover; an ast-grep fallback (deferred until a need is measured).
- Rationale: the subject project's own tooling is the durable memory; etabli stays dependency-free and read-only.
- Consequences: `constraints` says where to put a rule, never that a rule is active (a detected `tsconfig.json` does not prove `strict`).

### `pyproject.toml` reported, not parsed
- Context: two successive adversary passes found holes in section detection (regex, then multiline strings).
- Choice: report `{ tool: "pyproject", path }` and let the agent read `[tool.*]` itself.
- Rejected options: a lexical TOML scanner copied into every project.
- Rationale: removes the whole bug class for a small loss.
- Consequences: discover reads no constraint-file content.

### One candidate rule: `lstatSync(...)?.isFile()`
- Context: symlink cases (internal, external, broken, to a directory) were underspecified.
- Choice: report a candidate only when it is a regular file; same policy as `confinedFile` and the scopes.
- Consequences: six invalid neighbours pinned by tests.

### Project-constraint recommendation limited to pure `code_review` findings
- Context: `finding/*` also covers planning findings, which are not code defects.
- Choice: the new branch applies only when `phase_counts` has the single key `code_review`, after the threshold and unmapped branches.

## Accepted Drift
- Original plan/spec: Risks listed "aucune lecture de contenu" for discover.
- Implemented reality: discover reads no constraint-file content; the pre-existing `package.json` metadata read remains (AC-3 wording).
- Why accepted: the AC was already narrowed in plan pass 4; the Risks line was the only broader wording left.

## Validation Evidence
- `node --test tests/project-verification-recipe.test.mjs`
  - result: 24 pass, 0 fail.
- `node --test tests/workflow-patterns.test.mjs`
  - result: 27 pass, 0 fail.
- `bash tests/workflow-docs-smoke.sh`, `bash tests/workflow-scaffold-smoke.sh`, `bash tests/workflow-ship-metrics-report-smoke.sh`
  - result: ok.
- `scripts/workflow-context-budget`
  - result: all surfaces ok, no ceiling raised; `spec-map` 30205 → 30163, `ship` 83277 → 83209; `contract-details.md` 282 lines.
- `scripts/validate-adrs`
  - result: 30 records ok.
- `scripts/verify-agentic-infra core`
  - result: 4/35 fail (pi-tests, durable-tests, pi-typecheck, guards-active), all environmental (missing `pi/durable/node_modules`, `yaml` missing from global Pi); the installed-extension-loader failure reproduces on `main`.
- `bun test pi/extensions/__tests__/`
  - result: 447 pass, 1 pre-existing fail.
- Review (high-risk): T1 → T2 → D1 → F1. Plan adversary passes 1-5 on `gpt-6.1-sol`. Code-diff adversary `gpt-6.1-sol` GO on T2 and F1 (run `01a13262-9d4d-7533-81c8-997c97cda674`, patch sha256 `3d8811cf…`). Logic and Spec hunters GO with no findings on F1.

## Follow-up State
- Remaining risks: an agent may write over-broad lint rules; mitigated by never-auto-applied and the fail-before/pass-after case. `scripts/lib/project-verification-recipe.mjs` reaches projects only on the next `deploy-workflow`.
- Parking lot: periodic `workflow-ship-metrics --projects` across work projects, once real `finding/*` constraint recommendations appear; ast-grep fallback.
- Superseded docs/specs: the "third occurrence… mechanical check" sentence in `workflow/spec.md` (moved to `contract-details.md` Golden principles).
- Next links: `workflow/project-constraints.md`, `docs/adr/0030-promote-recurring-findings-into-project-native-constraints.md`.
