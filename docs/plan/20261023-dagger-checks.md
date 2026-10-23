# Implemented: Dagger checks for the agentic-infra groups, run locally and by Dagger Cloud Checks on push

## Metadata
- Archived: 2026-10-23
- Source plan: `PLAN.md` (Dagger checks for the agentic-infra groups)
- Source plan SHA-256: `2e1f5e65bfd0dfbacfe60d0048ed51de0dd19b9e37433219849e4f8699baa2fc`
- Status: IMPLEMENTED
- Commit / branch: `ci/dagger-checks` a3ecbb5c..5e3cf137, PR #74
- Workflow initiative: none

## Outcome
- Dang module `.dagger/modules/etabli-ci` with `secret-scan`, `shell-docs` and `pi` checks; `dagger.toml`, `dagger.lock`; ADR-0039 with a 2027-01-23 review date.
- Cloud Checks enabled for Tonours/etabli; GitHub secret `DAGGER_CLOUD_TOKEN` set (unused by workflows).
- GitHub workflow untouched; both CIs run in parallel.

## Evidence
- Local `dagger check`: cold 41.3 s, warm 17.6 s (`pi` cached at 3.6 s), one doc edit 23.8 s.
- Cloud Checks, 3 runs: 4/4 green each, about 1 min 20 s; no warm cache (engine wait about 24 s, images pulled, every step rerun).
- GitHub Actions on the same pushes: 36-46 s shell-docs, 21-24 s pi.
- `scripts/verify-agentic-infra full` 39/39; gitleaks history (1480 commits) and dir scans clean.
- Review: reviewer subagent GO WITH NOTES; CI=true, shallow/index guard (negative-tested on a depth-1 clone), ADR limits recorded.

## Follow-ups
- Remove the GitHub workflow once Cloud Checks has proven reliable; move `tests/supply-chain-smoke.sh` and `tests/agentic-infra-manifest-smoke.sh` with it.
- Recheck Cloud timings when Dagger ships its distributed cache.
