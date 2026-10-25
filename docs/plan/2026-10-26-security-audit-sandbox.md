# PLAN.md

## Meta
- Subject: Docker sandbox for the security-audit skill on macOS (macmini, macbook-work)
- Status: DONE
- Branch: feat/security-audit-sandbox
- Last revised: 2026-10-25
- Archive: docs/plan/2026-10-26-security-audit-sandbox.md

## Goal
Give `security-audit-glm` runs an OS-enforced sandbox that meets every control of the skill's "Universal execution safety" section, so verifiers can execute target code and reach `confirmed` instead of stopping at `needs_validation`, on macmini (this host) and macbook-work.

## Workflow Contract
- Route: plan-implement
- Role: parent writes; Codex gpt-6.1-sol reviews plan and diff (cross-model)
- Tier: high-risk (remote machine setup)
- Budget: 2 review rounds per artifact, one live e2e audit per machine
- Stop condition: ACs proven on both machines, plan archived, root PLAN.md deleted
- Required evidence: smoke test output on both machines, e2e audit with at least one `confirmed` record, GLM-only transcript check

## Acceptance Criteria
- AC-1 [product]: `security-audit-sandbox` runs a command with no external network (isolated loopback only), an allowlisted env with scratch-local HOME/TMPDIR/caches, read-only rootfs/toolchain/target, writes only to a size-capped copy of the agent scratch, and CPU, memory, pids, file-size, disk and wall-clock limits. Proof: `tests/security-audit-sandbox-smoke.sh` probes each control on macmini and macbook-work, all pass.
- AC-2 [product]: argument guards refuse a scratch path that is not `<dir>/agents/<id>/scratch` (id per the skill regex) with no symlinked component, a target that is `/`, `$HOME` or an ancestor of either or of the scratch, and limits above their caps; host env is never forwarded and the target command starts under `env -i`. Proof: fake-docker section of the smoke test (argv) plus live `env` probe.
- AC-3 [product]: `security-audit-glm` checks the sandbox before launch and tells the parent how to use it; without it the run still starts, source-only, with a warning. Proof: extended `tests/security-audit-glm-smoke.sh`.
- AC-4 [product]: an e2e quick audit of the toy vulnerable server on macmini yields at least one `confirmed` record whose evidence comes from a sandboxed run. Proof: `findings.json` + transcript showing `security-audit-sandbox` calls, assistant models all GLM.
- AC-5 [process]: image built and smoke test green on macbook-work. Proof: remote command output.

## Repos
- Owner: this repo
- Satellite: none

## Scope
### In
- `scripts/security-audit-sandbox` (bash) and `scripts/security-audit-sandbox.Dockerfile`
- Results leave the sandbox only as capped stdout/stderr: the promotion allowlist is empty and nothing is copied back to host scratch
- `scripts/security-audit-glm` (preflight + prompt), its smoke test
- `tests/security-audit-sandbox-smoke.sh`, `workflow/runtime/agentic-infra-checks.tsv`
- ADR-0039 consequences update
- Image build on macmini and macbook-work

### Out
- Editing the vendored skill
- Enforcing that GLM agents never run target code on the host outside the sandbox (prompt discipline only, as in the upstream skill)
- Copying sandbox-written files back to host scratch (results leave through stdout/stderr; the parent may save that text itself)

## Facts And Assumptions
### Observed Facts
- macmini: macOS 26.2 arm64, Docker Desktop 29.7.2, VM 2 GB RAM / 10 CPU. macbook-work: macOS 14.4 arm64, Docker Desktop 29.8.2, VM 8 GB / 8 CPU. Apple `container` absent on both.
- Probe on macbook-work (alpine): `--network none` blocks egress, `--read-only` + `:ro` mounts block writes, `--user 65534` + `--cap-drop ALL` work, `--ulimit fsize` and `--pids-limit` trigger, env is only image PATH/HOSTNAME plus `-e` values.
- Docker Desktop shares `/Users`, `/private`, `/var/folders`, `/tmp` by default; the default output dir `~/security-audit-skill` is under `/Users`.
- The e2e run on 2026-10-25 kept all 5 leads `needs_validation` because macOS could not enforce the controls.
### Assumptions
- A tmpfs mount with `size=` enforces the disk cap and counts against the container memory cgroup (to verify in smoke).
- An OOM kill shows as `State.OOMKilled=true` on the stopped container (to verify).

## Requirement Trace
| Requirement / source | Observed state | Gap / ambiguity | Decision | Step / expected evidence |
| --- | --- | --- | --- | --- |
| No external network, isolated loopback (SKILL.md) | `--network none` keeps `lo` only | none | use it | smoke: egress blocked, loopback server reachable |
| Empty env from allowlist, scratch-local HOME/TMP/caches | docker passes no host env, but image ENV and Docker proxy config can be injected | not empty | trusted entry runs the command under `env -i` with an explicit list (PATH, HOME, TMPDIR, XDG_CACHE_HOME, npm/pip caches, offline flags, LANG, CI) plus literal `--env K=V` | live smoke: `env` output equals the list |
| Read-only target and toolchain, writes only in scratch | `--read-only`, `:ro` | /dev/shm and /dev/mqueue stay writable with the default IPC namespace | `--ipc none`; no tmpfs on /tmp; HOME/TMP/cache under a fresh `/scratch/.sandbox` created after the seed copy (`rm -rf` then `mkdir`) | live smoke: writes to /, /tmp, /var/tmp, /run, /dev/shm, /dev/mqueue, /target, /seed fail |
| CPU, memory, process, file-size, disk, wall-clock limits | flags exist | disk cap on bind mounts impossible on Docker Desktop; stdout floods bypass fsize | scratch = tmpfs `size=` seeded with `cp -RP` from host scratch (ro) and discarded; `--log-driver none`; output through `head -c` cap, container killed when the cap or deadline hits; defaults/caps: timeout 300/1800 s, memory 1g/1536m, cpus 1/4, pids 256/1024, disk 512m/2g, file-size 256m/disk, nofile 1024, output 256KiB/4MiB | live smoke: ENOSPC, SIGXFSZ, fork fail, OOM, exit 124, output cap; cgroup files show memory.max, pids.max, cpu.max |
| Never expose output dirs, home, creds, sockets | only scratch (ro seed) + target (ro) mounted; docker socket and DOCKER_* never passed | a `scratch` dir of another agent or behind a symlinked parent | require `<dir>/agents/<id>/scratch`, physical path equals logical path; refuse `/`, `$HOME` and their ancestors as target, and targets containing the scratch | fake-docker smoke |
| No network but isolated loopback | `--network none` | DNS failure could mask a route | probe raw IPv4 and IPv6 connects, DNS UDP/TCP, `host.docker.internal`, Desktop gateway 192.168.65.1, plus a loopback client/server | live smoke |
| Proof cannot be a skip | live section skips without docker | a skip would pass AC-1 | `SANDBOX_SMOKE_REQUIRE=1` turns a skip into a failure; used on both hosts | host runs show no skip |
| Do not let builds fetch dependencies | no network | image must already hold the toolchain | `--build` is the only networked step, run at setup | image present on both hosts |

## Approach
- Input domain / bounds: scratch path (exists, dir, not symlink, basename `scratch`), optional target dir, limits as positive integers/sizes, command after `--`.
- Regression family: launcher env/flags (existing smoke stays green); failing neighbors: missing docker, missing image, docker daemon down.

## Steps
1. Write `scripts/security-audit-sandbox.Dockerfile`: `node:24-bookworm-slim` + python3, build-essential, git, ca-certificates; non-root user 65534 exists.
2. Write `scripts/security-audit-sandbox`: `--build`, `--check`, run mode. Run mode: `docker run --pull never --network none --ipc none --log-driver none --read-only --cap-drop ALL --security-opt no-new-privileges --user 65534:65534 --memory M --memory-swap M --cpus C --pids-limit P --ulimit fsize=F --ulimit nofile=1024 --ulimit core=0 --tmpfs /scratch:size=D,mode=1777 -v scratch:/seed:ro [-v target:/target:ro]`; the trusted entry (`env -i <allowlist> sh -c`) runs `cp -RP /seed/. /scratch/`, recreates `/scratch/.sandbox/{home,tmp,cache}`, then execs the command in the workdir. The host watchdog starts before `docker run`, kills the container at the deadline (exit 124) or when the output cap is reached; INT/TERM/HUP/EXIT traps `docker rm -f`; after exit, inspect `OOMKilled`, print one `=== sandbox:` status line on stderr, remove the container.
3. Write `tests/security-audit-sandbox-smoke.sh`: fake-docker argv/guard section always; live section when docker and the image exist, else `skip` (failure under `SANDBOX_SMOKE_REQUIRE=1`).
4. Update `scripts/security-audit-glm`: run `security-audit-sandbox --check`; when it passes, tell the parent the wrapper is the only allowed execution path, that it meets every control, and that results leave only as stdout/stderr with an empty promotion allowlist; when it fails, warn and tell the parent no sandbox exists (source-only, the skill's own rule). Extend its smoke test.
5. Update ADR-0039 consequences; register the smoke test.
6. Build the image and run the smoke test on macmini and macbook-work.
7. E2E quick audit on macmini against the toy server; check findings and models.
8. Codex review of the diff, fix, verify-agentic-infra full, commit, push, pull on macbook-work, archive plan.

## Checks
- command: `SANDBOX_SMOKE_REQUIRE=1 bash tests/security-audit-sandbox-smoke.sh` (macmini, macbook-work)
  - expected: all ok, no skip
  - last run: 2026-10-25 macmini (bash 5.3 and /bin/bash 3.2) ok; macbook-work (/bin/bash 3.2, image built via login shell) ok
- command: `bash tests/security-audit-glm-smoke.sh`
  - expected: ok
  - last run: 2026-10-25 ok (18 checks, bash 5.3 and 3.2)
- command: `scripts/verify-agentic-infra full`
  - expected: only the known pre-existing `pi-audit` failure
  - last run: 2026-10-25 40/41, only `pi-audit` (undici advisory, pre-existing)

## Risks
- Docker Desktop not running at audit time: `--check` fails fast with a remediation message; the launcher falls back to source-only.
- macmini VM has 2 GB: defaults (1 GB memory, 512 MB disk tmpfs counted in it) must fit; parallel hunters may contend.
- GLM agents may still run target code on the host with the Bash tool: the guarantee covers the wrapper only; the prompt makes it the only allowed path and the skill already forbids unsandboxed execution. Residual, documented in the ADR.

## Decision Log
- 2026-10-25: Docker over Apple `container` (absent, macOS 14 on macbook-work) and over sandbox-exec (no memory/pids/disk limits).
- 2026-10-25: tmpfs scratch copy instead of a writable bind mount, because Docker Desktop cannot cap disk on bind mounts.
- 2026-10-25: Codex plan challenge (round 1, CHALLENGED): added `--ipc none`, `env -i`, `--log-driver none` + output cap, numeric caps, signal traps, stricter path guards, network probes, no-skip proof. Not taken: blocking host-side execution of target code (out of scope, documented residual).

## Review Changes
- Plan adversary (model, `shasum -a 256 PLAN.md` at dispatch, verdict, deltas): codex gpt-6.1-sol xhigh, e56dabdd49b834f8, CHALLENGED (5 High, 4 Medium); all but host-side execution blocking folded in above.
- Code review and code-diff adversary (reviewers, rounds, verdicts): codex gpt-6.1-sol xhigh round 1 CHALLENGED (2 High, 5 Medium), all fixed: agent dirs refused as target, overflow-safe sizes, protected `--env` names, retrying watchdog, limiter kills at once, `--image` removed, refusal tests on fake docker with exit 2; `.env` readable in the target recorded as a residual in ADR-0039. Round 2 CHALLENGED (1 Medium: another agent's root accepted as target), fixed by refusing any target under the run's agents directory, with a test; budget reached.
- simplify: / quality:

## Open Questions
- None

## Notes / Handoff
- Done: 57dbc0a9 + eb57c2e9 pushed to main, deployed on macbook-work (smoke 61 ok from the checkout; deploy reports the pre-existing ungoverned `fleet` skill).
- AC-4 evidence: e2e run 2 (macmini, quick) ran target code 21 times through the wrapper, never on the host, 748 assistant messages all `glm-5.3`; verifiers confirmed `/ping` injection (`uid=65534(nobody)` inside the sandbox), `/file` traversal and the event-loop hold. `findings.json` was not written: `claude -p` stopped a verifier after its 10 min background ceiling, now raised to 1 h in the launcher. Run 3 (1344 messages, all GLM) spent 2 h 43 relaying skill files through helper agents in the critic phase and was stopped; that is GLM orchestration cost, not the sandbox.
