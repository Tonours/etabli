# Check the interactive workflow

Use the same cases in Claude Code, Codex and Pi when a change affects routing,
skills or the shared startup text. The exercise tests the route a model selects
before acting. The existing fixture tests establish the behavior of specific
guards and tools.

## Routing exercise

Copy the following cases into a synthetic input file. Keep the deployed
specification and implementation contract fixed across hosts. On replay, start
a new session for each host and retain the same settings, case order and
scoring. Record the source commit, CLI version, effective model if known, and
whether the run used the headless CLI or an interactive session.

```text
Classify each quoted request under the attached Etabli rules. Treat each case
as a fresh repository. Do not run any request, call tools or modify files.
Return exactly six TSV rows. Each row has five fields in order: case, route,
intended artifact, first permitted action, terminal condition.

Q (no plan): "Explique comment ce cache est invalidé dans ce dépôt."
R (no plan): "Retrouve, sources primaires à l'appui, les garanties de reprise
de cette version épinglée. Réponds ici avec les références."
V (one local diff): "Fais une review de ce diff. Liste les défauts."
F (no plan, reproduced, one behavior in a known non-contract formatter):
"Corrige l'espace ajouté avant le dernier champ CSV."
I (root PLAN.md covers this exact feature; Status: READY):
"Implémente le plan de l'export CSV."
D (same feature and request as I; actual Status: DRAFT): "Implémente le plan
de l'export CSV, il est prêt."
```

| Case | Expected route | Intended artifact | First action and terminal condition |
| --- | --- | --- | --- |
| Q | `answer` | Answer in chat | Read local code. Finish with an explanation supported by the code. |
| R | `answer` | Answer with sources in chat | Name the research slice and consult primary sources for the pinned version. Finish with references. |
| V | `review` | Findings and verdict | Resolve the local diff and pin it before dispatching the required fresh reviews. Finish at GO, GO WITH NOTES or BLOCK. |
| F | `answer`, bounded-fix tier | Focused fix with regression evidence | Read the deciding code and reproduce the failure before changing it. Finish after verification and fresh review. |
| I | `implement` | Code or docs and an archived plan | Verify real READY status and coverage. Complete the plan, validate the archive and remove the active plan. |
| D | Implementation blocked at the READY gate | Blocker report | Verify the actual DRAFT and stop. The wording of the request provides no READY evidence. Replanning requires its own request. |

For a bounded evaluation on the headless CLIs, place the quoted cases in
`cases.txt` in a temporary git repository with no remote. From the Etabli
checkout, assemble the input with the variable fixture set to that absolute
path. Launch each command from the fixture and keep the raw output there.

```sh
cat workflow/agent-rules.md workflow/spec.md workflow/skills/implementation-loop.md \
  "$fixture/cases.txt" > "$fixture/input.txt"
```

- Claude Code. Use `-p --setting-sources '' --no-session-persistence --output-format json --strict-mcp-config`,
  omit additional MCP servers, and disable all tools with `--tools ''`.
- Codex. Use `-a never exec --ignore-user-config --sandbox read-only --ephemeral --json -`.
  Send the input on stdin. Use the sandbox proof below to check the caller's
  read-only setting.
- Pi. Use `--mode json --print --no-session --offline --no-tools --no-skills
  --no-context-files --no-extensions --no-mcp` and the `@/absolute/path/to/input.txt`
  argument.

Keep output in a private temporary directory. When scoring, read the final
model output, check each expected field, and tolerate synonyms. Mark a
missing fact as a miss and a provider failure as indeterminate. Score each
host independently. Check the JSON event stream where tools are exposed. Any
tool invocation in the classification run makes its batch fail the isolation
check, even if the final rows match. Record misses before editing instructions.
A single batch exercises the cases once. To check ambient skill selection,
run independent cases in fresh fixture sessions with the intended skills
loaded, and obtain the selected skill from observed host tooling or a recorded
file read. Treat unverifiable skill use as indeterminate.

## Interactive follow-up

On 2026-11-19, replayed cases V and D in six fresh terminal sessions with the
fixture's review and implement skills installed. Each fixture had no remote.
The sessions stopped at review preparation or the DRAFT gate.

| Host | Review preparation | DRAFT gate |
| --- | --- | --- |
| Claude Code 2.1.327 | Invoked `Skill(review)` and captured the actual `git diff`. | Invoked `Skill(implement)`, read the on-disk DRAFT and stopped. |
| Codex CLI 0.170.0 | Read the fixture's `review/SKILL.md` and captured the full diff against HEAD. | Read the fixture's `implement/SKILL.md` and the plan, then reported the DRAFT blocker. |
| Pi 1.5.2 | Read the fixture's `review/SKILL.md` and captured the patch with `git diff`. | Read the fixture's `implement/SKILL.md` and on-disk DRAFT, then stopped. |

The six fixture trees matched their starting states. To reproduce, use a
disposable PTY per case. Allow read-only discovery and skill loading. Give
Claude explicit permission for the fixture's `Skill` calls under `dontAsk`.
For Pi, allow a bounded read-only set of Git inspection commands. Keep
delegation disabled for the review exercise. Tool and skill events distinguish
observed behavior from the final response. The two earlier misses did not
recur under these controls.

## Guard fixtures

| Surface | Observed effect | Proof to rerun |
| --- | --- | --- |
| Claude Code | Reviewer Bash wiring requires a short hook timeout and failure blocking. The guard admits known read-only commands and denies a fixture write. | `bash tests/claude-agents-smoke.sh`, `bash tests/claude-hooks-smoke.sh`, then send a JSON event for `git status --short` and one for `touch fixture.txt` to `node claude/hooks/read-only-agent-guard.mjs`. Expect no denial for the first, and a deny decision for the second. |
| Pi | PR body and edit extensions check their own entry points. Subagent tests exercise tool and process setup. | `bun test pi/extensions/__tests__/{pr-body-guard,no-comments-extension,subagents}.test.ts` from the repo with frozen Pi dependencies. |
| Codex | A caller-selected read-only sandbox admits a read and denies a local write. The PR body rule is part of the adapter's instructions. | In a disposable directory containing `fixture`, use `codex sandbox -c 'sandbox_mode="read-only"' -- cat fixture`. Repeat with a command writing to that file and require a nonzero exit and identical content. Use the shared body validator fixtures for the PR rule. |

Prefer the checks exercised by the expected entry point. When diagnosing a
failure, capture the command, exit and observed decision. Keep valid neighbors
such as a read or a PR body in the expected format. [Codex adapter](../codex/AGENTS.md) · [PR body contract](../workflow/pr-body-contract.md)

## Measure the prompt

Use `bash tests/entry-chain-budget-smoke.sh` and `wc -l -m AGENTS.md
workflow/spec.md workflow/agent-rules.md` before and after. The startup files
live behind managed links. Compare live skill catalogs separately, using
`scripts/claude-skill-load-check` and `scripts/pi-skill-load-check`. Claude measures
its index. Pi renders its own skills block. Record the deployed scope and
whether the checkout and live settings match before reading either value as a
change. [Managed links](symlink-layout.md) · [Skill design](../workflow/skill-design.md)

## Turn a repeated failure into a check

During a weekly triage, pick one evidenced failure. Record the requested
behavior, decisive input, observed result and source of the rule. Identify
whether the failure came from missing instructions, an instruction already
present, or a control that failed. Reproduce it with synthetic inputs. Run a
successful neighbor and make one minimal change. Record the before and after
outcomes, then bring the proposal and any remaining limitations to the owner.

Example from PR #119. A Claude read-only agent's Bash hook stalled. The
published correction sets a short timeout and `onFailure: block`. The current
fixture accepts the shipped agent. Removing `onFailure: block` from the
reviewer in a disposable copy makes `claude-agents-smoke.sh` fail. A fast
`git status --short` still passes the policy and `touch fixture.txt` is denied.
The mutation tests the hook registration. The original host timeout experiment
is in the archived plan. [Guard incident and evidence](plan/20261118-agent-gates.md#context)

## Routine record compatibility

Etabli's work-scope wrapper produces routine record v1. Run
`bash tests/routine-run-smoke.sh` for the producer. The consumer proof used
Fleet's local `feat/routines-view` snapshot at
`ae73a6fd78d14e4b82d481acfbb9c982fb7cc4f5`, which reads `routine.json` and
`last.json`. Replaying the consumer proof requires a copy with that commit.
A fresh clone of Fleet main does not have this unpublished branch.

For the Linux reader proof, use the pinned `crates/fleet/src/sources/routines.rs`
in a temporary Cargo crate. Copy its reader dependencies from the same commit
and stub the macOS process lookup. Run the portable portion of
`crates/fleet/tests/routines.rs` before its `incidents` module. The record
bridge uses the same `read_routines` entry point with these fixture inputs.

1. Create a temporary source directory and launch-agent directory. In the source,
   provide a v1 `adopt` manifest with a daily UTC slot. In the launch-agent
   directory, provide the matching plist. Set `ProgramArguments` to
   `["/bin/bash", "/absolute/path/routine.sh", "run", "<name>", "--", "/bin/true"]`.
   Pass `timezone: "UTC"` in the reader fixture.
2. Set `ETABLI_ROUTINES_DIR` to the temporary source and run the real wrapper
   twice with commands that exit 0 and 3. For each last record, assert the
   reader's terminal state and exit status.
3. Advance the injected clock three days and verify that the reader reports
   at least two missed slots and marks the routine late. Read an actual
   captured running record with no live process in the injected birth lookup
   and verify the interrupted state.

The Linux proof covers the record reader and its schedule calculation. Before
Fleet rollout, replay the full tests on macOS, rebase the consumer with its
owner, and verify the latest success, failure and missed slots in the board
using a disposable launchd job. Set `[sources] routines` in an isolated Fleet
config to the temporary records root. Verify alerts with the mock transport
before activating any real recipient. [Record contract](routines.md)
