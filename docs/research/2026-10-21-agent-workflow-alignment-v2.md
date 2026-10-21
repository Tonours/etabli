# Etabli vs current best practice: Claude Code, Pi, and agent workflow (v2)

Date: 2026-10-21. Extends `docs/research/2026-10-21-claude-best-practices-alignment.md` (v1). Read-only research; this file is the only repo change.
Convention: **Fact** = from a cited source, file or my own run. **Inference** = my reading, a hypothesis. Source ids `S1-S15` are v1's (not re-fetched here); `N1-N29` are listed at the end, all fetched or run on 2026-10-21. Fetches go through a summarising tool, so quotes are as returned, not byte-verified; re-fetch before quoting in an ADR.

## TL;DR - top 7 recommendations

| # | Runtime | Effort | Recommendation |
|---|---|---|---|
| 1 | Claude | S | **Stop counting `permissionMode: dontAsk` as a safety layer.** Under main-session bypass it is ignored (confirmed in the docs, N1). The real barriers are the `tools` allowlist and the PreToolUse guard; I confirmed a settings-file PreToolUse deny fires under `--dangerously-skip-permissions` (N27). Edit the prose that lists `dontAsk` as one of three layers (`workflow/contract-details.md:38-41`) and drop the line from `scout`/`reviewer`/`adversary` frontmatter. Delete-only. |
| 2 | Claude | S | **Unattended PR scripts: flags only.** Replace `--dangerously-skip-permissions` with `--permission-mode dontAsk --allowedTools ...` (or `auto`), add `--bare`. They already use `--settings '{"disableAllHooks":true}' --strict-mcp-config --setting-sources project,local` (`pr-review-watch/review-run.sh:127-129`), so v1 overstated the gap, but bypass on third-party diffs is still the case Anthropic reserves for isolated environments (N2). |
| 3 | General | S | **Do not adopt v1's "worker gets `isolation: worktree`" as written.** The subagent worktree branches from the remote default branch, not your HEAD (N3), so an uncommitted root `PLAN.md` and unpushed commits are absent. Either set `worktree.baseRef: "head"` and still hand the plan text in the prompt, or keep the foreground single-writer rule (it is already conservative and correct, N4/N5). Keep `worktree-isolation.md:34-40` (environment boundary); delete the creation mechanics only for Claude. |
| 4 | Pi | S | **Test deleting `npm:pi-mcp-adapter`.** Pi ships native MCP since 0.99.0 (2026-09-29, N14) reading the same `~/.pi/agent/mcp.json`; etabli still installs the adapter for one skill (`pi/agent/settings.json:29-33`, `settings-consistency.test.ts:144`). Remove the entry, run `pi mcp list`, update the test. Duplicate feature = deletion candidate. |
| 5 | Claude | S | **Run `/skill-doctor` and `/doctor prompt-audit` once, then delete what they flag.** Both exist (2026-09-04 and 2026-09-25, N23). Correct v1: `claude plugin eval` tests plugins only and etabli is not a plugin (N11), so it is not the tool. |
| 6 | Pi / General | M | **Unattended Pi runs on untrusted content need a boundary, not a rule.** Pi has no permission system or sandbox by design; its security page says use a container/VM (N15, N16). Etabli's Pi side has only the no-comments and rtk extensions. If `pi-review-hunter` or any Pi cron touches third-party diffs, run it in a container or the Gondolin/sandbox examples. Also: `~/.pi/agent/mcp.json` holds a plaintext bearer header (see Open questions). |
| 7 | General | S | **Re-run the ADR-0035 census (50-line throwaway) before adding or keeping anything.** Candidates to count: `worker`, `worktree-isolation.md`, `orchestration.md` capability labels, `thermo-nuclear-code-quality-review`. Growth rules say measure first; no new surface is justified by this research. |

Overall: etabli is aligned or ahead on instructions, skills, verification, single-writer discipline and memory. Drift is concentrated in (a) unattended permission posture, (b) one now-false safety claim, (c) a few features that Claude Code or Pi now ship natively.

## What changed vs v1

### Confirmations
- **`permissionMode` ignored under bypass: confirmed.** Sub-agents doc: "When the main conversation is in `bypassPermissions`, `acceptEdits`, or auto mode, the subagent runs in that same mode and Claude Code ignores the `permissionMode` you set." The `bypassPermissions` exception for the other modes needs v2.1.267+ (N1). Same page: agent teams inherit the lead's bypass too (N6).
- **Hook deny under bypass: confirmed empirically.** Claude Code 2.1.306, `claude -p --dangerously-skip-permissions --model haiku --settings <file>` with a `PreToolUse` `Bash` command hook exiting 2. The model reported the call blocked with the hook's stderr and the target file was not created (N27). Docs add: "Deny rules block in every mode, including `bypassPermissions`" (N7) and settings-file hooks "all apply inside subagents" (N1). Limit: I tested the main agent's Bash, not a subagent, and not a hook declared in agent frontmatter.
- v1's other findings stand: `/goal`, `skillOverrides`, hooks, memory, CLAUDE.md import size, Sonnet 5.5 prompting (S1-S11 not re-fetched).

### Corrections to v1
1. **Dates now exist.** The GitHub releases API gives 249 dated releases (v2.0.73 2025-12-19 to v2.1.306 2026-10-21, N9). v1 said entries were undated and could not find some features. Now: `isolation: worktree` in agent definitions v2.1.50 (2026-02-20); `skillOverrides` incl. `name-only` v2.1.129 (2026-05-06); `/goal` v2.1.139 (2026-05-11); agent view v2.1.139; dynamic workflows v2.1.154 (2026-05-28); `/skill-doctor` v2.1.261 (2026-09-04); `claude plugin eval` v2.1.269 (2026-09-11); `/doctor prompt-audit` v2.1.283 (2026-09-25); hook `onFailure` v2.1.295 (2026-10-08); `autoCompactWindow` v2.1.296 (2026-10-09).
2. **"Each agent pins `claude-sonnet-5-5`" is wrong for `adversary`**: it pins `claude-opus-5-5` at `effort: low` (`adversary.md:4-5`). v1's low-effort concern stands and is sharper on Opus.
3. **v1 TL;DR 4 (use `isolation: worktree` for `worker`) is incomplete**: see TL;DR 3. Also a subagent in its own worktree takes instruction files from the main conversation, not the worktree (N3).
4. **v1 TL;DR 2 named `claude plugin eval` as an audit tool**: it evaluates plugin behaviour against a no-plugin baseline (N11). The audit tools are `/skill-doctor` (cost and unused skills) and `/doctor prompt-audit` (prompting patterns for older models, N23).
5. **v1 PR-script finding was too strong** on mitigations: `disableAllHooks`, `--strict-mcp-config`, project/local sources only, plus `neutralize_author_config` are already there (`review-run.sh:126-129`). Residual risk remains (bypass + `gh` token).
6. **ADR-0028 (write authority, per-worktree lease) no longer has code**: superseded by ADR-0034, and `workflow-lease` is gone (no non-docs reference). The one-writer rule survives as prose (`orchestration.md:23-27`, `spec.md:25-26`). The user brief cited it as live.
7. **ADR-0023 (pstack Pi port) is superseded by ADR-0033**; ADR-0029 still says Pi is pinned at 1.0.3 while `pi/package.json` pins 1.3.0 (commit 5b1359d9). Pi's canonical repo is `earendil-works/pi`, not badlogic/pi-mono (package.json `repository`, N13).
8. **Pi is not "out of scope"** as v1 treated it: it has its own docs, changelog and native features that overlap etabli (axis 2).

### Resolved open questions from v1
- PreToolUse deny under bypass: resolved (above).
- Dynamic workflows page: fetched (N8). Script-held plan, GA on paid plans, up to 16 concurrent agents and 1,000 per run, no approval prompt under bypass. Not adopted; see axis 4.
- Agent teams: fetched (N6). Experimental, off by default, no worktree isolation for teammates, tmux/iTerm2 split panes.
- anthropics/skills, building-effective-agents, writing-tools: fetched (N20-N22).

### Still unresolved
- Whether a hook declared in agent frontmatter (the read-only guard) fires for a subagent under bypass. Docs say user-level subagent hooks run without a trust step (N1); not run.
- Claude Code CHANGELOG text itself: I used release bodies from the API (N9) keyword-scanned, not a line-by-line read of 249 releases.
- Pi docs were read from the installed 1.3.0 package, not pi.dev (N14).

## Per-axis findings

Format: (a) etabli today, (b) source, (c) verdict, (d) minimal recommendation.

### 1. Claude Code
- (a) Hooks: no-comments, rtk, read-only guard only (`claude/settings.workflow-hooks.json:3-25`). Bypass by design (`claude/README.md:110-118`, ADR-0032). `autoMemoryEnabled: false`. Four agents; read-only ones list `permissionMode: dontAsk` (`scout.md:8`, `reviewer.md:8`, `adversary.md:8`).
- (b) Hooks reference: 30+ events incl. `Stop`, `SubagentStop`, `TaskCompleted`, `PermissionDenied`, `WorktreeCreate`, `PreModelSwitch`; types command/http/mcp_tool/prompt/agent; exit 2 blocks even if JSON says allow; `onFailure: "block"` v2.1.295+ (N10). Permissions: "PreToolUse hook decisions don't bypass permission rules" - deny/ask rules win over a hook `allow` (N7). Auto mode is the starting mode in interactive sessions since v2.1.283, classifier reads CLAUDE.md, configurable by `autoMode.environment`, `/auto-mode-setup`, `claude auto-mode critique`; `permissions.ask` forces a prompt even in auto mode (N12). Headless: `--bare` is "recommended for scripted and SDK calls, and will become the default for -p"; without it `-p` runs project hooks and `.mcp.json` servers even in an untrusted folder; `-p` starts in Manual mode when nothing sets a mode (v2.1.302+) (N24).
- (c) Aligned on hooks-only-for-hard-rules and instruction size. Drift: `dontAsk` claimed as protection (`contract-details.md:38-41` says "`dontAsk` and a scoped Bash allowlist guard... stronger than prose").
- (d) TL;DR 1. Optional, only if you want a safety net that survives bypass: `permissions.deny` for `Bash(git push --force*)` style rules (apply in bypass, N7); that reverses an ADR-0032 preference, so it is an option. Skip auto mode for interactive use unless prompts become acceptable; it conflicts with "never pause" (`claude/CLAUDE.md:29`).

### 2. Pi (pi-coding-agent 1.3.0)
- (a) Pinned 1.3.0 (`pi/package.json`). Extensions: `no-comments.ts` (37 lines, reuses the Claude guard), `rtk.ts` (41, bash spawn hook), `workflow-tools.ts` (52, lazy-loads Task*/subagent tools), `prefer-ipv4-dns.ts` (19); `herdr-agent-state.ts` is herdr-managed and untracked. Packages (10) in `pi/agent/settings.json:3-50`: mitsupi, pi-skills, pi-autoresearch, pi-cursor-sdk, pi-mcp-adapter, pi-goal, pi-lens, pi-simplify, pi-tasks 0.7.1, pi-subagents. Default model `zai/glm-5.3`. Shared rules linked as `~/.pi/agent/AGENTS.md` (ADR-0037).
- (b) 1.3.0 is the latest published version (npm `time` ends 2026-10-15; nothing after, N13). README: Pi "skips features like sub-agents and plan mode" and has no built-in permission system (N14, N15). Native since 0.99.0: MCP client (stdio/HTTP, OAuth, `/mcp`), `codemode`, `tool_search` (N14 changelog). Tool `exposure: deferred` plus `tool_search` (extensions docs). Native Agent Skills spec implementation, `~/.agents/skills`, `/skill:name`. Native AGENTS.md/CLAUDE.md discovery (`cli.md`). Program status OSC 7501 since 1.1.0. Virtual models for routing (`docs/virtual-models.md`). Published `$schema` for settings/models since 1.2.0.
- (c) Per feature:

| Etabli item | Pi now ships | Verdict |
|---|---|---|
| `pi-mcp-adapter` package | native MCP, same `mcp.json` | duplicate candidate; test deletion (TL;DR 4). Unverified whether both register tools today |
| `workflow-tools.ts` lazy loader | `exposure: deferred` + `tool_search`, `defaultTools` `+name/-name` | duplicate only if pi-tasks/pi-subagents register their tools as `deferred`; otherwise the shim is the only way. Inference; check `pi.getAllTools()` exposure |
| `pi-subagents`, `pi-tasks`, `pi-goal` | not native by design | keep; these are the Pi parity for `Agent`, tasks, `/goal` |
| Shared AGENTS.md link | native discovery | aligned, minimal |
| Skill exclusions `"!name"` | native skill filter patterns | aligned |
| `no-comments.ts` | none (Pi has `tool_call` hook, example `protected-paths`, `permission-gate`) | etabli-specific, keep |
| `rtk.ts` | `bash` spawn hook (example `bash-spawn-hook.ts`) | etabli-specific, keep |
| Herdr state | native OSC 7501 status | herdr's own integration; not etabli code |

- (d) TL;DR 4. Optional, S: add `$schema` to `pi/agent/settings.json` for editor validation (custom keys `rtk`, `tasksTillDone` may fail it; unverified). Do not build a virtual-model router; ADR-0029's registry is advisory by design and a router would be a new surface.
- Etabli goes beyond: tracked Pi config with consistency tests (ADR-0001) is stronger than Pi's own guidance, which treats packages as arbitrary code with full user permissions (N15). Fact: 10 third-party packages run unsandboxed; weigh each against weekly use.

### 3. Cross-runtime parity
- (a) One skill tree to both runtimes, `pi_core` flag for Pi (ADR-0037, `skill-surface.tsv`); shared rules in `workflow/agent-rules.md`; `orchestration.md` carries `confirmed/proxy_supported/blocked/unknown` labels and Pi Task* notes (`orchestration.md:32-44,104-122`). `spec.md:23` and `contract-details.md:7` say Pi is "primary", while ADR-0029 routes planning to Claude and volume to Pi.
- (b) AGENTS.md is a plain-Markdown open format, nearest-file-wins, now stewarded by the Agentic AI Foundation under the Linux Foundation (N19). Agent Skills spec: `name` max 64, `description` max 1024, `compatibility` max 500, `SKILL.md` under 500 lines, references one level deep, `allowed-tools` experimental (N17). MCP latest spec 2026-07-28; extensions Tasks and "Skills over MCP" (N18). Claude imports AGENTS.md via `@AGENTS.md` (S2); Pi reads it natively.
- (c) Aligned on all three open standards; etabli's 1024-char cap equals the spec, so v1's "stricter than 1,536" is actually spec-exact. Drift in weight: capability labels and the "primary tool" wording.
- (d) Trim `orchestration.md` to one-writer rule, delegation preconditions, retry caps and acceptance evidence (`:23-27,57-100`); move Pi Task* notes to a `pi/` note; fix the "Pi primary" wording to match ADR-0029. Delete-first. Watch "Skills over MCP" only; no action.

### 4. Orchestration, parallelism, worktrees, write authority
- (a) One writer at any instant, foreground worker, parent re-takes the pen (`orchestration.md:23-27`; `contract-details.md:33-37`); delegation preconditions (`:59-72`); worktree contract (`worktree-isolation.md:1-45`); council removed (ADR-0013); lease removed (ADR-0034). No `isolation:` in any agent (`grep` over `claude/scopes/shared/agents`).
- (b) Anthropic: simplest solution first; patterns are chaining, routing, parallelization, orchestrator-workers, evaluator-optimizer (N20). Claude Code has five parallel modes (subagents, agent view, teams, dynamic workflows, projects) and "Do the tasks touch the same files? Isolate the work with worktrees... Agent teams don't isolate teammates in worktrees" (N5). Teams: "For sequential tasks, same-file edits, or work with many dependencies, a single session or subagents are more effective"; teammates inherit the lead's bypass; Claude can name subagents that launch as teammates when the flag is on (N6). Workflows move the plan into a script; bypass skips the approval prompt (N8). Worktrees: `--worktree`, `.worktreeinclude`, `worktree.baseRef` (`fresh` default or `head`), enforcement blocks edits and git redirects into the main checkout, `WorktreeCreate`/`Remove` hooks (N3). Multi-agent research costs about 15x chat tokens and suits breadth-first work, not tightly coupled coding (S15).
- (c) Aligned and conservative; one writer is stricter than Anthropic requires and matches "tightly coupled work is a poor fit" (S15). Etabli's loop maps to chaining plus evaluator-optimizer plus one orchestrator-worker. Partial overlap: native worktree creation, cleanup, base-branch choice and isolation enforcement cover most of `worktree-isolation.md:9-33,42-45`. Not covered natively: clean-base check, root `PLAN.md` living in the run's worktree, and the environment boundary for ports/DBs (`:34-40`).
- (d) TL;DR 3. Do not enable agent teams (default off, good) or build on dynamic workflows. If parallel writers are ever needed, use `claude --worktree` per session plus the single integrator idea from ADR-0028 as prose, not code.

### 5. Evaluation and verification
- (a) `verify` route and `/verify-workflow`; review rubric with deciding-code table (`spec.md:84-86`); bug fix starts from a failing test (`spec.md:108-109`); fresh-context final review (`spec.md:97-99`); eval ledger deleted (ADR-0034); recurring findings promoted to project-native constraints (ADR-0030).
- (b) "Building an evaluation allows you to systematically measure the performance of your tools"; pair each prompt with a verifiable outcome (N21). Evaluator-optimizer needs clear criteria (N20). `/goal` evaluator judges only surfaced evidence (S5). Native evals now exist but for plugins (`claude plugin eval`, baseline delta, CI exit code) and single skills via skill-creator (N11).
- (c) Aligned on discipline; deliberate gap on harness evals. ADR-0030's "promote to linter or test" is stronger than Anthropic's prose guidance.
- (d) No rebuild. If one eval is ever wanted, run skill-creator on the single most-used skill, not a framework. `adversary` at `effort: low` (`adversary.md:5`) is the cheapest experiment: rerun one known-bad diff at `medium` and compare findings.

### 6. Context engineering and memory
- (a) Always-loaded set small (v1 axis 1); `workflow/memory.md` (29 lines) defines project-local `docs/agent-memory/` lessons, while `agent-rules.md` points to the vault (`alambic-obvault`/`alambic-brain`) first; adversary/reviewer treat vault packs as untrusted and cite the vault read (`adversary.md:35-42`). No `docs/agent-memory/` in this repo (`ls docs`).
- (b) Just-in-time retrieval, compaction, structured notes, sub-agent summaries (S12); initializer plus progress file for long runs (S13); auto memory loads first 200 lines or 25 KB and is complementary (S2). Pi has compaction and branch summaries natively (`docs/compaction.md`) but no memory feature.
- (c) Etabli goes beyond: a curated, sourced vault replaces auto memory. Mild inconsistency (inference): two memory conventions exist (project-local `docs/agent-memory/` in `memory.md`; global vault in `agent-rules.md`).
- (d) Add one line to `workflow/memory.md` stating when the vault wins over `docs/agent-memory/` (or delete the file if no scaffolded project uses it; count first). No new surface.

### 7. Model routing
- (a) ADR-0029: declarative registry (`workflow/runtime/model-routing.json`), advisory foreground routing, cross-family adversary excludes the author's family, `opusplan` for broad plans, GLM 5.3 and Flash on Pi for volume. Agents pin full Claude ids.
- (b) Anthropic "routing" pattern sends easy inputs to smaller models (N20). Claude Code picks a subagent model from: per-invocation, definition `model`, `CLAUDE_CODE_SUBAGENT_MODEL`, then the parent's (N6, N1). Pi virtual models can route per request from an extension (`docs/virtual-models.md`).
- (c) Aligned. The cross-family adversary rule goes beyond vendor guidance. Pinning ids buys reproducibility at the price of silent staleness (preference, not drift).
- (d) None. Do not build a Pi router; the registry plus drift smokes already suffice for one user.

### 8. Safety and permissions
- (a) Interactive bypass (ADR-0032), no push/delete gates; read-only agents via tools allowlist plus hook; PR scripts under `--dangerously-skip-permissions` with mitigations; Pi side no sandbox.
- (b) Bypass is for "Isolated containers and VMs only"; deny rules block in every mode; `permissions.disableBypassPermissionsMode`; the sandbox covers Bash only, not file tools, MCP or hooks (N2, N7, N26). Pi: "does not ask for approval before every tool call"; "Watching the transcript, using project trust, and reviewing changes do not create a security boundary" (N16).
- (c) Interactive: deliberate and documented, aligned with ADR-0032's single-trusted-user premise. Unattended on untrusted content: drift on both runtimes.
- (d) TL;DR 1, 2, 6. Option, M: Claude Bash sandbox in auto-allow mode for the PR scripts instead of bypass; unverified how it interacts with `gh` network access and `git worktree` writes (worktrees write to the shared `.git`, which the sandbox allows, N3).

## Other angles worth exploring

| Idea | Source | Benefit | Cost / risk |
|---|---|---|---|
| `--bare` plus `--permission-mode dontAsk` on all `claude -p` scripts | N24 | Reproducible, no host hooks/MCP/CLAUDE.md surprises; will become default | Scripts must pass context explicitly (`--append-system-prompt-file`, `--settings`) |
| `Stop` hook running the frozen check | S1, N10 | Deterministic done-gate | New surface, ADR-0032 direction; only after a measured false "done" |
| `/auto-mode-setup` for a trial of auto mode on the PR scripts | N12 | Classifier replaces bypass without prompts | Latency, false blocks, repo-specific `autoMode.environment` upkeep |
| Cloud routines instead of the launchd PR watcher | v1, N23 | Could delete `watch.sh` | Cloud runs lack local env and vault; MCP servers from Claude Code cannot attach to cloud routines (release 2.1.251) |
| Claude `PreModelSwitch`/`PostModelSwitch` hooks to log effective model for ADR-0029 provenance | N10 | Automates "record effective model" | New hook; only if provenance is actually audited |
| Pi `$schema` in settings | N14 | Free validation | Custom keys may fail; tiny gain |
| Rotate and move the plaintext bearer in `~/.pi/agent/mcp.json` to `${ENV}` expansion (Pi supports `${VAR}` in headers, `docs/mcp.md`) | N14 | Removes a secret from a file that Pi packages can read | One-time edit; value not reproduced here |
| `name-only` skill override for rare skills | v1, N9 | Cuts catalog tokens (exists since 2026-05-06) | Discoverability loss; test on load gate |
| Pi virtual-model router | N14 | One selectable model that routes | New extension; no weekly need shown |

## Open questions
- Does `pi-mcp-adapter` still contribute anything native MCP lacks (the `mcp-scripting` skill, `mcp-adapter.json`)? Needs a local run of `pi mcp list` with and without it.
- Do pi-tasks and pi-subagents register tools with `exposure: deferred`? If yes, `workflow-tools.ts` and its test are deletable.
- Does the agent-frontmatter read-only hook fire under main-session bypass for a spawned subagent? Run `tests/claude-hooks-smoke.sh` logic through `claude -p --dangerously-skip-permissions` with a real `scout` spawn.
- Does `worker` ever run weekly? If not, TL;DR 3 is moot and the worker plus worktree-isolation contract can go.
- Secret hygiene: while inspecting `~/.pi/agent/mcp.json` I printed a bearer Authorization header into this session's tool output. It is not copied into this file or the repo; treat that token as exposed to the transcript and rotate it if transcripts are retained.
- Pi docs were not fetched from pi.dev; the installed 1.3.0 package docs and CHANGELOG (6,309 lines, dated) were used.

## Sources

Local (repo-relative from `/Volumes/Crucial/work/etabli`): `AGENTS.md`; `workflow/{spec,agent-rules,contract-details,memory,review-rubric}.md`; `workflow/skills/{orchestration,worktree-isolation,long-loop,obvault-memory,implementation-loop}.md`; `claude/scopes/shared/agents/{reviewer,adversary,scout,worker}.md`; `claude/settings.workflow-hooks.json`; `claude/README.md`; `claude/scopes/work/scripts/pr-review-watch/review-run.sh`; `PLAN_TEMPLATE.md` (headings only); `pi/package.json`, `pi/agent/settings.json`, `pi/settings.json`, `pi/models.json`, `pi/extensions/*.ts`; ADRs 0001, 0023, 0028, 0029, 0030, 0031, 0032, 0034, 0035, 0036, 0037. Not read in full: `plan-loop.md`, `review.md`, `PLAN_TEMPLATE_FULL.md`, ADR bodies beyond the first 30-50 lines.

External, fetched 2026-10-21:
- N1 https://code.claude.com/docs/en/sub-agents (first 100k of 110k chars)
- N2 https://code.claude.com/docs/en/permission-modes
- N3 https://code.claude.com/docs/en/worktrees
- N4 https://code.claude.com/docs/en/agents
- N5 same as N4 (parallel-approach comparison)
- N6 https://code.claude.com/docs/en/agent-teams
- N7 https://code.claude.com/docs/en/permissions
- N8 https://code.claude.com/docs/en/workflows
- N9 https://api.github.com/repos/anthropics/claude-code/releases (249 releases via `gh api`, keyword-scanned)
- N10 https://code.claude.com/docs/en/hooks (first 100k of 270k chars)
- N11 https://code.claude.com/docs/en/plugin-evals and https://code.claude.com/docs/en/plugins-reference
- N12 https://code.claude.com/docs/en/auto-mode-config
- N13 `npm view @earendil-works/pi-coding-agent time`; `pi/node_modules/@earendil-works/pi-coding-agent/package.json` (`repository`); https://github.com/earendil-works/pi-mono (README summary)
- N14 installed Pi 1.3.0 package: `README.md`, `CHANGELOG.md`, `docs/{mcp,extensions,settings,cli,skills,compaction,virtual-models,terminal-setup}.md`
- N15 same package, `docs/how-pi-works.md`
- N16 same package, `docs/security.md`
- N17 https://agentskills.io/specification
- N18 https://modelcontextprotocol.io/specification/latest
- N19 https://agents.md
- N20 https://www.anthropic.com/engineering/building-effective-agents
- N21 https://www.anthropic.com/engineering/writing-tools-for-agents
- N22 https://github.com/anthropics/skills
- N23 release bodies in N9 (`/skill-doctor`, `/doctor prompt-audit`, routines)
- N24 https://code.claude.com/docs/en/headless
- N26 https://code.claude.com/docs/en/sandboxing (first 2 KB only; coverage statement)
- N27 local run: `claude -p --dangerously-skip-permissions --model haiku --settings <PreToolUse Bash hook, exit 2>` on Claude Code 2.1.306, temp dir outside the repo
- Redirect: https://www.anthropic.com/engineering/claude-code-best-practices now 308-redirects to https://code.claude.com/docs/en/best-practices (S1).

Unreachable: none failed outright. Partial reads: hooks (100k of 270k), sub-agents (100k of 110k), sandboxing (preview only), headless/auto-mode/workflows/worktrees complete. Not fetched: pi.dev docs site, effective-context-engineering, multi-agent-research-system and effective-harnesses posts (v1 S12, S13, S15 used), OpenAI/Google agent docs (no cross-vendor standard needed beyond AGENTS.md, Agent Skills, MCP).
