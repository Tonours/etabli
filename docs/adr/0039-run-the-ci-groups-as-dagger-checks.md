---
status: accepted
date: 2026-10-23
tags: [tooling, ci, dagger]
affected_components: [dagger.toml, dagger.lock, .dagger/modules/etabli-ci/main.dang, .github/workflows/agentic-infra.yml]
---

# Run the CI groups as Dagger checks

The two agentic-infra CI jobs now also exist as Dagger checks in one Dang module, `.dagger/modules/etabli-ci`: `secret-scan` (gitleaks on the full history), `shell-docs` and `pi` (`scripts/verify-agentic-infra <group>`). `dagger check` runs them locally in the same container image that Dagger Cloud Checks uses after each push, so a green local run predicts the remote one. Node 22.22.0, bun 1.3.14 and gitleaks 8.30.1 match the GitHub workflow, and `dagger.lock` pins their image digests. jq 1.7 and ruby come from Debian trixie packages and float. `LANG=C.UTF-8` and `CI=true` match the runner.

Review date: 2027-01-23. If neither `dagger check` nor Cloud Checks is used weekly by then, delete the module and keep the GitHub workflow (AGENTS.md Growth).

## Consequences

- Good, because an unchanged rerun is served from cache: on a 10-CPU laptop the cold run took 41.3 s and the warm run 17.6 s, and `pi` dropped from 28.0 s to 3.6 s.
- Good, because Dang needs no generated bindings: the module is one `main.dang` plus `dagger-module.toml`.
- Bad, because Dagger caches `Workspace.git` per client, so `secret-scan` and `shell-docs`, which need the history, rerun on every session. `pi` gets no `.git` and caches fully.
- Bad, because `Workspace.git` exports only HEAD and its full ancestry, so `secret-scan` covers the pushed branch, not every branch as the GitHub `fetch-depth: 0` checkout does. A guard fails both git checks if the export is shallow or has no index.
- Bad, because a cached `pi` run skips `bun audit`: a new advisory against an unchanged lockfile stays green until the source changes. Each push changes the source, so Cloud Checks re-audits.
- Bad, because Cloud Checks needs Dagger 1.0, still in beta (1.0.0-beta.21); a CLI or schema change can break the module.
- Bad, because GitHub Actions and Cloud Checks run the same groups until Cloud Checks has proven reliable. Removing the workflow later also means moving `tests/supply-chain-smoke.sh` and `tests/agentic-infra-manifest-smoke.sh`, which read it.
- The Dagger CLI warns that it cannot open a linked worktree when `extensions.worktreeConfig` is set; checks still pass, because the workspace reads files and Git state through the engine.

## Considered Options

- TypeScript SDK module: rejected, it commits generated bindings and a package tree for what is a container recipe.
- Official modules only (`dagger module recommend`): rejected, none covers `scripts/verify-agentic-infra`.
- Narrow the `pi` source to `pi/` and the files its tests read: rejected, the tests read `scripts/`, `workflow/` and `skills/`, and a missed path would fail silently or pass falsely.
