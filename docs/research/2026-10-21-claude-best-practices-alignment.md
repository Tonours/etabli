# Etabli vs Claude / Claude Code best practices (October 2026)

Date: 2026-10-21. Scope: read-only research, no repo change other than this file.
Convention: **Fact** = quoted or paraphrased from a cited source or file. **Inference** = my reading; treat as a hypothesis.

## TL;DR - top 5 recommendations

1. **Unattended runs on untrusted input use `--dangerously-skip-permissions`; reconsider that one surface first.** Anthropic lists `bypassPermissions` as "Isolated containers and VMs only" and says deny rules still apply in every mode (S6). The PR review/autoreview scripts run `claude -p --dangerously-skip-permissions` over third-party diffs (`claude/scopes/work/scripts/pr-review-watch/review-run.sh:127`, `pr-autoreview/run.sh:112`, `pr-council-review/run.sh:157`). Minimal change: `--permission-mode dontAsk` plus `--allowedTools` for those scripts (the documented fan-out pattern, S1), or auto mode. No new surface, only flags. Interactive bypass is a separate, deliberate choice (ADR-0032) and I do not recommend reopening it.
2. **Run `/doctor prompt-audit` and `claude plugin eval`/`/skill-doctor` once, add nothing permanent.** These built-ins audit CLAUDE.md, rules, skills and agents (S2). A one-off run tests whether the instruction tree (about 1,800 lines under `workflow/` read on demand) still earns its keep, which is the Growth rule's "measure first". Unverified: I did not fetch the `plugin-evals` page.
3. **Trim `workflow/skills/orchestration.md` (122 lines) and the Pi-parity prose it carries.** It encodes a four-label capability taxonomy and Pi `Task*` runtime notes (`orchestration.md:32-44,104-112`). Claude natively provides `/goal`, forks, background subagents and `isolation: worktree` (S3, S4). Delete-first: keep only the one-writer rule and delegation preconditions.
4. **Replace `workflow/skills/worktree-isolation.md` (45 lines) for the `worker` with `isolation: worktree` frontmatter, if the worker is used weekly.** The agent frontmatter field creates and auto-cleans a temporary worktree (S4). `claude/scopes/shared/agents/worker.md:1-9` does not set it. Keep the file only for Pi.
5. **Optionally add one `Stop` hook (or `/goal` wording) as the deterministic "checks are green" gate, only if prose-only completion has produced a false "done".** Anthropic ranks prompt, `/goal`, Stop hook, second-opinion as increasing gates (S1). Etabli has `/goal` guidance (`claude/CLAUDE.md:17`) but no Stop hook (`claude/settings.workflow-hooks.json:3-25`, PreToolUse only). This is an addition, so by AGENTS.md Growth rules it needs measured need first; `docs/plan/20261017-residual-risks.md` is the place to check.

Overall: etabli is mostly aligned or ahead on instruction hygiene, skills, subagent scoping and verification discipline. The drift is in permissions for unattended runs, cross-runtime documentation weight, and not yet using a few native features (worktree isolation, Stop hooks, prompt audit).

## Method and sources

Local: read AGENTS.md, CLAUDE.md, claude/CLAUDE.md, claude/README.md, both settings fragments, three hooks, workflow/spec.md, skill-design.md, memory.md, answer-quality.md (head), orchestration.md, long-loop.md, worktree-isolation.md, verify.md, implementation-loop.md (head), the four agent files (worker.md and scout.md fully; adversary/reviewer by grep), skill-surface.tsv, ADR index, ADR-0032 and ADR-0036 heads, skills tree (`skills/shared`, `skills/work`). Not read in full: contract-details.md (only Daily loop), review-rubric.md, plan-loop.md, review.md, PLAN_TEMPLATE*.md, ADRs 0014/0027-0031/0033-0038 beyond the index titles. Vault: grep hits `~/work/obvault/kb/skill-catalog-context-budget-gating.md` (secondary, supports the skillOverrides gate) and `second-brain-best-practices-gap-2026.md` (memory, not used).

External, all fetched 2026-10-21 via WebFetch (a small model summarises the page, so quotes are as returned, not byte-verified):

| Id | URL |
|---|---|
| S1 | https://code.claude.com/docs/en/best-practices |
| S2 | https://code.claude.com/docs/en/memory |
| S3 | https://code.claude.com/docs/en/skills |
| S4 | https://code.claude.com/docs/en/sub-agents |
| S5 | https://code.claude.com/docs/en/goal |
| S6 | https://code.claude.com/docs/en/permission-modes |
| S7 | https://code.claude.com/docs/en/hooks-guide |
| S8 | https://code.claude.com/docs/en/plugins |
| S9 | https://github.com/anthropics/claude-code (raw CHANGELOG.md: https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) |
| S10 | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices |
| S11 | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5 |
| S12 | https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents |
| S13 | https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents |
| S14 | https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills |
| S15 | https://www.anthropic.com/engineering/multi-agent-research-system |

Limits: the CHANGELOG is about 1.06M characters and I read only the first 100,000; it carries version numbers without dates, so "2026" attribution is by version (2.1.2xx-2.1.3xx), not date. `/goal`, memory and worktree changelog entries were not found in that slice. Not fetched: anthropics/skills repo, `building-effective-agents`, `writing-tools-for-agents`, the hooks reference, `permissions`, `sandboxing`, `auto-mode-config`, `workflows`, `agent-teams`, `plugin-evals`. Statements about those come only from links on fetched pages and are marked unverified.

## Per-axis findings

| # | Axis | Verdict | One-line recommendation |
|---|---|---|---|
| 1 | CLAUDE.md / imports | Aligned | Keep; run `/doctor prompt-audit` once |
| 2 | Skills | Aligned; one minor drift | Keep; note 1024 vs 1536 char cap |
| 3 | Subagents | Aligned; gap on worktree isolation | Use `isolation: worktree`; verify `dontAsk` under bypass |
| 4 | Hooks | Aligned for what exists; gap for completion gate | Optional Stop hook, evidence first |
| 5 | Plan mode vs PLAN.md | Etabli goes beyond | Measure ceremony; no new surface |
| 6 | Context / compaction | Aligned | None |
| 7 | Claude 5 prompting | Aligned; small drift on pause rule | Use Anthropic's literal "stop and report" paragraph |
| 8 | Verification / eval | Aligned; eval gap is deliberate | Do not rebuild the ledger (ADR-0034) |
| 9 | Permissions / safety | Drift (unattended) | Fix flags on PR scripts (TL;DR 1) |
| 10 | Plugins | Etabli diverges, justified | Do not adopt |
| 11 | Pi parity | Drift (weight) | Trim orchestration.md |

### 1. CLAUDE.md, memory, instruction size, imports

- Etabli (fact): root `CLAUDE.md` is 7 lines and imports `@AGENTS.md` (CLAUDE.md:1-7); `claude/CLAUDE.md` is 40 lines, imports `../workflow/agent-rules.md` and `RTK.md` (claude/CLAUDE.md:39-40); AGENTS.md is 70 lines, agent-rules.md 43. `autoMemoryEnabled: false` (claude/settings.skill-overrides.json:6) with memory in the obvault. Spec states "Instruction files stay maps, not manuals" (workflow/spec.md:106-107).
- Source (fact): target under 200 lines per CLAUDE.md; imports "don't reduce its context cost, because imported files also load at launch"; max import depth four hops; `@AGENTS.md` import is the documented way to share with other tools (S2). Keep lines only if removing them would cause mistakes; prune or convert to hooks (S1).
- Verdict: aligned. Always-loaded text is well under the budget (about 7.2 KB across the three files by `wc -c`).
- Inference: the always-loaded set is fine, but `workflow/spec.md` (187 lines) is effectively always read because CLAUDE.md names it "entry and map, wins on conflict". That makes it a de facto instruction file near the 200-line target. Small risk, no action needed beyond the prompt audit.
- Disabling auto memory is a legitimate choice: the docs describe auto memory as loaded "first 200 lines or 25KB" and complementary (S2). Etabli's vault is a larger, curated replacement. No change.
- Nit: the "SOLUTION EFFICIENCY" block sits outside any heading (claude/CLAUDE.md:35-37); cosmetic.

### 2. Skills

- Etabli (fact): one tree `skills/<scope>/` served to both runtimes (AGENTS.md architecture; workflow/runtime/skill-surface.tsv:1-42); SKILL.md files are thin entry points over `workflow/skills/<name>.md` (claude/README.md:44-47; e.g. `skills/shared/plan-loop/SKILL.md` is 12 lines). Visibility managed by `skillOverrides` with `on` / `user-invocable-only` (claude/settings.skill-overrides.json:7-37) and a load check (claude/README.md:60-69). Skill rules: description at most 1024 chars, body under 500 lines, one level of references (workflow/skill-design.md:36-47).
- Source (fact): body under 500 lines, reference files for detail, scripts "executed, not loaded"; `description` plus `when_to_use` truncated at 1,536 characters in the listing; `skillOverrides` values are `on`, `name-only`, `user-invocable-only`, `off`; `disable-model-invocation` for side-effect skills; `paths` and `context: fork` frontmatter exist (S3). Progressive disclosure and "start with evaluation" (S14).
- Verdict: aligned, with a minor drift: etabli's 1024-char cap (skill-design.md:39) is stricter than the documented 1,536. Stricter is harmless and matches the agentskills.io spec the file cites.
- Gap (inference): the `name-only` override state is unused; for rarely-triggered `on` skills (for example `prototype`, `wizard`, `herdr`) it halves their catalog cost while keeping them model-discoverable. Worth testing against the existing index gate; the obvault note above reports 59-86% savings from such levers.
- Gap (inference): `context: fork` would let `review` or `adversary` run in an isolated context without a separate agent file, but etabli already has agents for this; adding it would duplicate. Skip.
- Etabli goes beyond: deterministic index-size gate and keep-set pin (claude/README.md:65-69).
- Overlap to watch (fact + inference): bundled `/code-review`, `/simplify`, `/verify`, `/batch` ship with Claude Code (S3). Etabli already avoids shadowing `/verify` (claude/CLAUDE.md:18) and its `code-quality`/`review` skills carry a repo-specific rubric, so they are not pure duplicates; however `skills/shared/thermo-nuclear-code-quality-review` (191 lines) and `code-quality` (64) overlap the bundled simplify/code-review idea. Check weekly use before keeping (Growth rule).

### 3. Subagents

- Etabli (fact): four agents `scout`, `worker`, `reviewer`, `adversary` in `claude/scopes/shared/agents/`; each pins `model: claude-sonnet-5-5`, an `effort`, a `tools` allowlist, `maxTurns`; read-only ones add `permissionMode: dontAsk` and a PreToolUse Bash guard (scout.md:1-16; worker.md:1-9). One writer at a time (workflow/spec.md:25-26; orchestration.md:23-27). Delegate only on explicit preconditions (orchestration.md:59-72).
- Source (fact): use subagents for verbose output, tool restriction and self-contained work; use the main thread for iterative, shared-context or quick changes. Frontmatter supports `model`, `effort`, `tools`/`disallowedTools`, `hooks`, `isolation: worktree`, `memory`, `background`. **If the main session is in `bypassPermissions`, the subagent runs in that mode and `permissionMode` is ignored.** Nesting depth 3, 20 concurrent (S4). Multi-agent costs about 15x chat tokens and "tightly coupled work like most coding is a poor fit" (S15). On Sonnet 5.5 at `max`, telling the model not to launch reviewer sub-agents unless asked cut session cost by about a third (S11).
- Verdict: aligned, and conservative in the direction Anthropic recommends (parent keeps the critical path, delegation is opt-in).
- Drift risk (fact + inference): because Claude here runs under bypass (claude/README.md:110-118) and the docs say `permissionMode` is then ignored (S4), the `dontAsk` line in scout/reviewer/adversary likely provides no protection; the real barrier is the `tools` allowlist plus `read-only-agent-guard.mjs` (claude/hooks/read-only-agent-guard.mjs:33-53). I did not verify that a hook `deny` still fires under bypass; the same docs say deny rules do (S6). Test once with `tests/claude-hooks-smoke.sh` under a bypass session.
- Gap: `isolation: worktree` is not used by `worker` (TL;DR 4); `workflow/skills/worktree-isolation.md` re-implements it by prose.
- Minor: pinning a full model id (`claude-sonnet-5-5`) is allowed (S4) and gives reproducibility; the cost is silent staleness when a newer Sonnet ships. `inherit` or an alias is the alternative. Preference call, not drift.
- Effort: `adversary` at `effort: low` (adversary.md:5). The Sonnet 5.5 guide says at `low` the model "keeps its thinking short and can skip verifying" (S11). Inference: an adversarial role is the one place where shallow thinking defeats the purpose; test `medium` on a known-bad diff before changing.

### 4. Hooks

- Etabli (fact): three PreToolUse command hooks, two wired globally (no-comments on `Write|Edit|MultiEdit`, rtk on `Bash`; claude/settings.workflow-hooks.json:3-25) and one in agent frontmatter. No other event. Approval/route/READY gates were removed on purpose (ADR-0032; workflow/spec.md:170-177). The comment guard and rtk guard fail open on parse errors (no-comments-guard.mjs:7-10; rtk-guard.mjs:9-12), the read-only guard fails closed (read-only-agent-guard.mjs:36-42).
- Source (fact): hooks are for actions that must happen "every time with zero exceptions"; CLAUDE.md is advisory (S1, S2). Hook types: command, http, mcp_tool, prompt, agent (agent experimental); events include PostToolUse, Stop, SubagentStop, UserPromptExpansion (S7). A Stop hook can block turn end until a check passes (S1). CHANGELOG 2.1.295 added `onFailure: "block"` for command/HTTP hooks (S9, version only, undated).
- Verdict: aligned. The no-comments rule is the textbook "convert a style rule to a hook". The deliberate removal of gates is consistent with the "prune ruthlessly" guidance, though it leaves completion discipline (plan READY before editing, archive and delete PLAN.md, spec.md:62-64) in prose, which Anthropic classes as advisory (S2).
- Gap, optional: no Stop hook. Inference: this is the cheapest deterministic way to enforce "checks ran" but it contradicts ADR-0032's direction; only add if a false "done" has been observed.
- Minor: `onFailure: "block"` would make the two fail-open guards configurable fail-closed. Not needed unless a miss was observed.

### 5. Plan mode vs root PLAN.md

- Etabli (fact): routes in spec.md:131-147: ordinary coding with no plan goes straight to edit (line 136); `plan-loop` for broad or unclear work; `READY` gate has 11 criteria (spec.md:114-127); a 12-step daily loop (contract-details.md:162-177); archives in `docs/plan/` (8 files now, `ls docs/plan`); no root PLAN.md at snapshot.
- Source (fact): explore, plan, implement, commit; "If you could describe the diff in one sentence, skip the plan"; interview then write SPEC.md then execute in a fresh session; specs should name files, scope, and end with an end-to-end verification step (S1). Plan review against `PLAN.md` by a subagent is shown as the example adversarial step (S1).
- Verdict: aligned on the principle, etabli goes beyond on ceremony. Persisting the plan to a file that survives `/clear` is the documented pattern. The heavier parts (risk tiers, cross-model adversary for high-risk, provenance hashes in PLAN.md, spec.md:75-78) have no Anthropic counterpart.
- Inference: the multi-step route table is where over-engineering is most likely. ADR-0035 already set a weekly-use bar. Recommendation: no new surface; count how many `docs/plan/` archives per month actually passed through `adversary` and `plan-implement` (a 50-line throwaway script, per AGENTS.md Growth) and delete the route that is unused.
- Native plan mode (`--permission-mode plan`) is not referenced anywhere in etabli's contracts; under bypass, plan mode is available only when bypass is in the mode cycle (S6). Not a gap, because PLAN.md serves a different purpose (cross-session artifact).

### 6. Context management and compaction

- Etabli (fact): compaction instructions in claude/CLAUDE.md:22-25; handoff block in PLAN.md (spec.md:75-78); statusline script (claude/statusline.mjs); load check on catalog size; JIT retrieval from the vault.
- Source (fact): "context window is the most important resource"; custom compaction instruction in CLAUDE.md is the documented pattern; `/clear` between tasks; after two failed corrections, clear and re-prompt (S1). Skills are re-attached after compaction: 5,000 tokens each, 25,000 combined (S3). Just-in-time retrieval, compaction, structured notes, sub-agent summaries (S12). Newer: idle compaction over 200K tokens, `autoCompactWindow` in subagent frontmatter, `/btw` (S9 versions 2.1.296-2.1.304; S1).
- Verdict: aligned. Etabli's no-progress stop (same hypothesis fails twice; spec.md:90-92) mirrors "correct twice, then clear".

### 7. Prompting for the Claude 5 family

- Etabli (fact): my grep for `MUST|NEVER|CRITICAL|ALWAYS` (whole word, upper case) over AGENTS.md, claude/CLAUDE.md, agent-rules.md, spec.md, the agent files and skills/shared SKILL.md returned 0 hits. Agents are specific (worker.md output format, "Never" list in sentence case at worker.md:51-55). `claude/CLAUDE.md:29-31` says never pause for approval.
- Source (fact): soften aggressive language ("CRITICAL: You MUST ..." becomes "Use this tool when...") because newer models over-trigger (S10). Sonnet 5.5: at `low`/`medium` effort the model may stop to check in; recommended system-prompt text "Keep working until everything the user asked for is done, and only stop to ask when you can't go on without the user or before a risky step", plus "When the work ... is done and checked, stop and report. Don't add features, tests, files, docs or refactors that weren't asked for." (S11). Parallel tool calls are default; subagent over-spawning is steerable by explicit guidance (S10). Medium effort is the suggested starting point for well-specified agentic coding (S11).
- Verdict: aligned. Worker/scout/reviewer at `medium` match the guidance.
- Small drift (inference): `claude/CLAUDE.md:29-31` covers "never pause" but not the second paragraph about not adding unrequested work. The repo has the equivalent in worker.md:26-27 and the YAGNI line, so the effective behaviour is covered for worker but not for the parent. One sentence in claude/CLAUDE.md would close it; weigh against the delete-first rule (it would be the one added line).
- Sonnet 5.5 also notes thorough review rounds at `xhigh`/`max` that spawn reviewer sub-agents on their own (S11); etabli's spec mandates reviewers explicitly, so this is intentional, not drift.
- Not applicable: `thinking`, `budget_tokens`, structured-output notes (S10, S11) concern API integrations, not this repo.

### 8. Verification and evaluation loops

- Etabli (fact): `verify` route and `/verify-workflow` with three verdicts and per-item evidence (workflow/skills/verify.md:15-67); review rubric requires a filled deciding-code table for runtime diffs (workflow/spec.md:84-86); fresh-context final review for autonomous runs (spec.md:97-99); "A bug fix starts from a failing test" (spec.md:108-109); eval ledger and product verification removed (ADR-0034).
- Source (fact): "Give Claude a way to verify its work" is first in the best-practices page; escalating gates prompt, `/goal`, Stop hook, second-opinion subagent; show evidence, not assertions; tell the reviewer to flag only correctness or stated-requirement gaps to avoid over-engineering (S1). `/goal` is a session-scoped prompt-based Stop hook whose evaluator "does not call tools" and judges only what Claude surfaced; conditions up to 4,000 chars with a turn/time clause (S5). Start with evaluation, about 20 real queries and an LLM judge (S14, S15). Initializer/feature-list JSON plus progress file for long runs (S13).
- Verdict: aligned, and spec.md:108-109 is nearly verbatim S1's guidance. The goal contract (`goal` plus cap, claude/CLAUDE.md:17; spec.md:94-96) matches S5.
- Gap, deliberate: no skill or workflow eval harness. ADR-0034 deleted it; Anthropic's "start with evaluation" argues the other way. Recommendation: do not rebuild; if wanted, use the built-in plugin eval after a one-off look (unverified, TL;DR 2).
- Native `/verify` now exists as a bundled app-running skill (S3); etabli's note keeps `/verify-workflow` separate (claude/CLAUDE.md:18). Aligned.
- Inference: S13's finding that JSON is less likely to be overwritten than Markdown for the feature list suggests, at most, a machine-readable acceptance block in PLAN.md; PLAN_TEMPLATE was not reviewed here, so I do not recommend it.

### 9. Permissions and safety

- Etabli (fact): Claude runs `bypassPermissions` (claude/README.md:110-118; claude/CLAUDE.md:29-31); no hook gates pushes, deletions or PLAN.md writes (claude/README.md:117-118; ADR-0032 consequences: "A mistaken push, deletion or post is caught after the fact"). Unattended PR review runs `--dangerously-skip-permissions` (`pr-review-watch/review-run.sh:127`, `delta-review.sh:43`, `pr-autoreview/run.sh:112`, `pr-council-review/run.sh:157-160`) and mitigates with kill switches, caps, base-reset of agent config files in scratch worktrees, and approval gates (claude/README.md:126-153).
- Source (fact): `bypassPermissions` row: "Everything", best for "Isolated containers and VMs only"; allow rules have no effect in bypass; deny rules block in every mode; some actions are never auto-approved even in bypass; `-p` with bypass requires a container/VM/sandbox runtime and a non-root user (S6). Since v2.1.283 auto mode (a classifier reviewing actions) is the built-in starting mode in interactive sessions; it blocks "scope escalation, unknown infrastructure, and hostile-content-driven actions" (S1, S6). Fan-out guidance: `claude -p ... --allowedTools ... --permission-mode dontAsk` (S1). `permissions.disableBypassPermissionsMode` exists for managed settings (S6).
- Verdict, interactive: etabli's choice is explicit, documented in ADR-0032, and consistent with a single trusted user. Factual risk: no classifier and no sandbox means a prompt-injected or mistaken command executes with user privileges; the ADR already accepts this. Mitigations still available at near-zero cost: deny rules (apply in bypass) for a short list such as force-push to the default branch and recursive deletion outside the repo. That reverses a stated ADR-0032 preference, so it is an option, not a recommendation.
- Verdict, unattended on third-party PR content: drift. These scripts feed untrusted diffs and comments to an agent that holds shell and the `gh` token under bypass, which is the case the docs reserve for isolated environments (S6). Cheapest fix is flag-only (TL;DR 1); the "agent config files reset to base" step (claude/README.md:149) shows the author already considered the injection path.
- Unverified: whether the review scripts need Bash write tools; if only `gh` reads and file reads, an allowlist is small.

### 10. Plugins and marketplace packaging

- Etabli (fact): not packaged as a plugin; a Node manifest links skills, agents and scripts per scope into `~/.claude` and `~/.pi` (ADR-0037, ADR-0038; claude/README.md:8-31). Third-party plugins `datadog`, `forest` are tolerated via `machine-local-plugins.json` (claude/README.md:75-78).
- Source (fact): "Skills, subagents, hooks, and MCP servers all work on their own, without a plugin"; use a plugin to package for teammates or many projects, with versioned releases; every enabled plugin adds name and description tokens every turn; plugins have a context-cost estimate and `claude plugin disable` (S8). Plugin skills are not affected by `skillOverrides` (S3).
- Verdict: etabli diverges for good reason: single user, two runtimes, and Pi cannot load Claude plugins (inference). Packaging would add a marketplace to maintain, against the Growth rules. No action.
- Note (fact): because plugin skills ignore `skillOverrides` (S3), the repo's check that "an enabled plugin ships skills" fails the gate (claude/README.md:66-69) is the right control.

### 11. Pi runtime parity

- Etabli (fact): Pi is "the primary user-facing tool" (workflow/spec.md:23) yet Claude is the daily harness per this setup; Task* state is Pi-only (orchestration.md:17-19; claude/CLAUDE.md:19-20); capability labels `confirmed`/`proxy_supported`/`blocked`/`unknown` (orchestration.md:32-44); `pi_core` flag controls which skills reach Pi (skill-surface.tsv header).
- Source: none (Pi is out of Anthropic's scope). Anthropic guidance on altitude and minimal context applies to how much parity prose is loaded (S12).
- Verdict (inference): drift in weight, not in correctness. A 122-line contract plus labels exists to manage honesty about two runtimes with different primitives. Where Claude has native primitives (S4, S5), the contract can point to them instead of restating.
- Recommendation: shrink orchestration.md to the one-writer rule, delegation preconditions and retry caps; move Pi Task* notes under `pi/`. Keep `/goal` and cap rules (they match S5).

## Other angles worth exploring

| Idea | Source | Benefit | Cost / risk |
|---|---|---|---|
| Auto mode for interactive use instead of bypass | S1, S6 | Keeps near-zero prompts while a classifier blocks scope escalation and hostile-content actions | Classifier latency and false blocks; conflicts with "never pause" in claude/CLAUDE.md:29; unverified how it interacts with etabli's scripts |
| `--permission-mode dontAsk` + `--allowedTools` on PR scripts | S1 | Deny-by-default for unattended runs | Requires listing tools per script; small edit |
| Stop hook running the repo's frozen check command | S1, S7 | Deterministic "not done until green" | New surface; ADR-0032 removed similar gates; needs measured false-done rate |
| `name-only` skill override for rare skills | S3 | Cuts catalog tokens more | Model may not pick the skill without the description; test on the load gate |
| Routines / scheduled cloud agents instead of launchd watcher | S9 (routines entries) and the `schedule` skill | Could delete `watch.sh` machinery | Cloud runs lack local env and `~/work/brain` access; feasibility unverified |
| `claude agents` agent view, cross-session messaging, `/batch` for fan-out | S1 | Replaces ad-hoc herdr tabs for parallel work | Agent teams are experimental and off by default; overlaps herdr; check weekly use |
| Machine-readable acceptance list in PLAN.md | S13 | Fewer accidental edits by the model | Template churn; tiny gain without measured problem |
| Dynamic workflows (`/workflows`) | S1 link only | Native refute-your-own-findings loops | Page not fetched; unverified |
| `context: fork` skill instead of an agent file | S3 | One file instead of two | Etabli's agents carry hooks and tool scopes; no net deletion |

## Open questions and unverified claims

- Whether a PreToolUse hook `deny` fires for subagents under main-session `bypassPermissions` (S6 says deny rules do; hooks not confirmed). Verify with the existing smoke test.
- CHANGELOG: only the first 100,000 of about 1.06M characters were read, and entries have no dates. Features I could not locate there: `/goal`, auto memory, worktree-isolation frontmatter introduction.
- `claude plugin eval` and `/skill-doctor`: named in the Claude Code guide agent description and linked from S8 as "Test plugins with evals"; page content not read.
- anthropics/skills repo and Anthropic's `building-effective-agents`/`writing-tools-for-agents` posts were not fetched. No claim here depends on them.
- Etabli files not fully read: contract-details.md, review-rubric.md, plan-loop.md, review.md, PLAN_TEMPLATE*.md, adversary/reviewer agent bodies, ADRs 0014, 0027-0031, 0033-0038 bodies. Verdicts on route ceremony (axis 5) rest on spec.md and the Daily loop only.
- Quotes from external pages come through a summarising fetch tool; wording may be paraphrased slightly. Re-fetch before quoting in an ADR.
- "Weekly use" of each surface is not measured here; AGENTS.md Growth rules say to measure before cutting or adding.

## Sources

Local files cited use repo-relative paths from `/Volumes/Crucial/work/etabli`. External sources S1-S15 are listed in the Method table above, all fetched 2026-10-21. Secondary (vault): `~/work/obvault/kb/skill-catalog-context-budget-gating.md` (created 2026-08-31, verified, supports the skillOverrides gate).
