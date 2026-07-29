# Research result

**Status: Partial**

Production coding-agent harnesses make mid-session controls enforceable only when the host can refuse a tool call, suppress a continuation, or refuse a write—not when the model is merely told to stop. For no-progress and thrashing, the hard pieces are continuation/hook overrides, budget caps, and per-response retry budgets; ledger-threshold “blocked” signals still often need agent cooperation. For single-writer / parent-only mutation under parallel scout or council work, tool allowlists, sandbox read-only modes, and admission hooks are the mechanical gates; “parent integrates” prose alone leaves residual shared-tree mutation open.

### No-progress and thrashing stops

**Hook thrashing guard (Claude Code Stop hooks).** After a Stop hook blocks eight consecutive times without progress, the runtime overrides the hook and lets the turn end (cap via `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`); scripts must honor `stop_hook_active` and exit early or they can loop forever. Without that host override, a blocking Stop script can trap the session in infinite continues. Success signal: override fires after the consecutive no-progress block cap (default 8, or the configured cap).[S1]

**Continuation contract + anti-spin (Codex Goals).** Goals are a thread-scoped completion contract: if a continuation turn makes no tool call, the next automatic continuation is suppressed so the agent does not spin; work also stops at budget limit (summarize, do not start new work), and idle-thread continuation runs only while a Goal is active and within budget. Success signals: no further auto-continuation after a tool-less turn; budget exhaustion ends substantive work; completion is checked against named evidence surfaces (tests, benchmarks, artifacts) rather than narrative “done.”[S2][S3]

**Ledger-threshold stop + typed `no_progress` (Pi-like / Etabli workflow).** The contract defines a no-progress stop when the same fix hypothesis fails twice, or the same check stays red three times with no new diff; a typed `no_progress` event carries detail shape `{check_or_hypothesis, command, attempts, head_sha, eliminated}`, and envelope thresholds fix `same_hypothesis_failures=2` and `red_checks_without_diff=3`. A read-only project-autonomy controller can return stop on event `no_progress` or those derived counts—but it never launches agents and only decides from envelope + events the agent appends. Prompt-only or agent-discipline-only application of the same rules does not continuously force mid-session halt. Success signal (when wired): stop decision plus recorded `no_progress` that blocks further mutate on the envelope path; ordinary implement loops remain proxy/discipline without that path.[S4][S5][S18]

**Tool-policy retry budget (MCP Resilient Write L3).** Identical-content write retries are refused mid-session via a per-response `retry_budget` that decrements and blocks further identical retries at zero, plus non-retriable `content_filter` errors—addressing the failure pattern of many identical retries burning minutes and tokens. Prompt-only “don’t retry the same write” does not refuse the tool. Documented success metrics vs baselines: ~5× recovery-time reduction and ~13× agent self-correction rate (with a large automated test suite).[S6]

### Single-writer / parent-only mutation under parallel scouts

**Tool allowlist / disallowed tools (subagent policy).** Scout/council portfolio roles (e.g. Luna, Terra, GLM, Sol, Kimi) are limited to read, grep, find, and ls and explicitly exclude bash, edit, and write; the multi-model contract treats mutation as parent-only—parent integrates findings; sidecars on implementation routes are limited to planning, reconnaissance, and review. Mature Claude surfaces do the same for non-mutating roles: Explore/Plan deny Write and Edit; custom agents use tools/disallowedTools. Codex documents parallel write-heavy work as coordination-heavy and allows custom agents with `sandbox_mode = "read-only"` (subagents inherit parent sandbox/approvals). Prose-only “parent integrates” without tool/sandbox exclusion still allows a non-parent path to mutate. Success signal: tool surface pinned to read-only set (tests assert absence of bash/edit/write); host never executes write/edit from those roles.[S7][S8][S16]

**Schema/router protocol (parent-only writer field + guidance).** Parallel scout/council runs are steered by multi-execution typing with `writer: "parent-only"` and injected guidance that first passes are read-only and the parent is the only writer. Alone this is protocol text, not a file lock—failure mode if only this exists is shared-tree mutation by a non-parent path without mechanical multi-model deny.[S9]

**RPC / tool_call admission gates (Pi workflow-router).** Portfolio fan-out is mechanically gated: Agent calls are admission/budget-guarded; portfolio roles/models are blocked on unguarded TaskCreate/TaskUpdate/TaskExecute so they must use the guarded Agent surface. Success signal: Task RPC from portfolio roles/models denied with an explicit must-use-Agent message (extension tests assert the blocks).[S10]

**Isolation defaults (concurrency coupling reduction, not a write lock).** Portfolio sidecars run isolated, without inherited context, in background, with max concurrent subagents of 3—reducing shared-context coupling during parallel scout/council, not replacing write policy.[S11]

**PreToolUse / permission hard-deny (Claude Code).** Primary evidence a control is host-enforceable is a PreToolUse (or permission) decision that hard-denies so the host never executes the tool—e.g. `permissionDecision: "deny"` with a reason returned to the model. Prompt-only “don’t call that tool” does not prevent host execution. Success signal: call blocked before execution; model sees the deny reason.[S15]

### Soft / host-dependent residuals in mature harnesses

Even in mature dual-runtime harnesses, ordinary mid-session no-progress (same hypothesis twice / same check red three times without new diff) remains soft for non-envelope sessions: event schema and discipline exist, but implement/plan-implement loops are not continuously forced to halt without model cooperation.[S13][S5][S18]

Codex Goals keep blocked stop and evidence-based completion partly host-dependent: the blocked condition is written into the Goal contract, and the model marks complete when evidence supports it; host-hard pieces are separate—budget-limited stop and automatic-continuation suppression after a tool-less continuation turn.[S17][S3]

Multi-model single-writer remains protocol/proxy without an OS or file lock: parent-only is contract + role tool surfaces + honesty labels, not kernel enforcement across sidecars; residual failure is a non-parent path still mutating the shared tree without a mechanical multi-model deny.[S12][S14]

## Sources
- [S1] "Automate actions with hooks — Claude Code Docs" — "https://code.claude.com/docs/en/hooks-guide"
- [S2] [S3] "Using Goals in Codex — OpenAI Developers Cookbook" — "https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex"
- [S4] "Etabli workflow contract (spec + events + envelope schema)" — "/Users/tonours/work/etabli/workflow/spec.md"
- [S5] "Etabli project-autonomy + harness audit + leap baseline G3" — "/Users/tonours/work/etabli/scripts/lib/project-autonomy.mjs"
- [S6] "Resilient Write: A Six-Layer Durable Write Surface for LLM Coding Agents" — "https://arxiv.org/html/2604.10842v3"
- [S7] "Etabli Luna Scout agent + portfolio config test" — "/Users/tonours/work/etabli/pi/agents/etabli-luna-scout.md"
- [S8] "Pi Adaptive Multi-Model Orchestration" — "/Users/tonours/work/etabli/workflow/skills/multi-model-orchestration.md"
- [S9] "workflow-router-runtime multi-execution guidance" — "/Users/tonours/work/etabli/pi/extensions/lib/workflow-router-runtime.ts"
- [S10] "Pi workflow-router portfolio call guards" — "/Users/tonours/work/etabli/pi/extensions/workflow-router.ts"
- [S11] "Pi subagent defaults + agent isolation frontmatter" — "/Users/tonours/work/etabli/pi/agent/subagents.json"
- [S12] "Etabli leap baseline G2 + harness audit / capabilities" — "/Users/tonours/work/etabli/docs/research/20260729-etabli-leap-baseline.md"
- [S13] "Etabli leap — Pass A baseline (G3 no_progress)" — "/Users/tonours/work/etabli/docs/research/20260729-etabli-leap-baseline.md"
- [S14] "Etabli runtime capability matrix (parent-only writer proxy)" — "/Users/tonours/work/etabli/workflow/runtime-capabilities.json"
- [S15] "Claude Code Hooks reference (PreToolUse deny)" — "https://code.claude.com/docs/en/hooks"
- [S16] "Claude Code Create custom subagents (tool deny) + Codex subagents" — "https://code.claude.com/docs/en/sub-agents"
- [S17] "Using Goals in Codex (OpenAI cookbook)" — "https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex"
- [S18] "Bounded Project Autonomy Envelope (no_progress controller)" — "/Users/tonours/work/etabli/workflow/project-autonomy-envelope.md"

## Coverage and uncertainty
- "Question 1 uncertainty: No primary Codex/Claude/Pi doc inspected here shows OS sandbox or git worktree isolation enforcing hypothesis-level no-progress/thrashing stops; those mechanisms are documented for filesystem/network isolation and parallel-agent collision avoidance, not thrashing."
- "Question 1 uncertainty: Pi-like subagents:rpc in this repo is documented as a capability/availability gate for TaskExecute tracking (e.g. tasks-till-done-runtime), not as a thrashing/no-progress detector."
- "Question 1 uncertainty: Claude Code PreToolUse/tool-policy hooks can hard-deny tools mid-session, but primary docs do not define a built-in \"repeated failed hypothesis without new evidence\" detector beyond the Stop-hook eight-block progress override."
- "Question 1 uncertainty: Codex cookbook describes anti-spin continuation and budget stops architecturally but does not publish quantitative thrashing-reduction metrics comparable to Resilient Write’s 5×/13× figures."
- "Question 1 uncertainty: Etabli continuous mid-session mutate-block on no_progress for ordinary plan-implement routes remains an explicit gap (G3), not a confirmed kernel/hook enforcer."
- "Question 2 uncertainty: Live multi-model/subagent runtime proof remains labelled unknown (opt-in RUN_REAL_MULTI_MODEL); offline tests prove config and tool_call guards, not live host tool-surface enforcement."
- "Question 2 uncertainty: Claude lacks the same Pi portfolio agent frontmatter tool pins in this repo; Claude multi-model one-writer is mostly shared contract/prose rather than an equivalent portfolio tool-allowlist surface found here."
- "Question 2 uncertainty: No completed external deep-research-run artifacts were present under docs/research/deep-research-runs for non-Etabli harness primary docs; claims above are local-harness primary only."
- "Question 3 uncertainty: Pass B external deep-research run artifacts under docs/research/deep-research-runs/ were empty; claims rely on primary product docs plus local Etabli audit/baseline, not a completed Pass B synthesis."
- "Question 3 uncertainty: Live Claude Agent-tool and Codex interactive goal/subagent behavior remain capability-label unknown/opt-in in this repo; offline docs do not prove every host build wires the same hooks."
- "Question 3 uncertainty: Whether production Codex enforces single-writer as more than sandbox_mode + orchestration guidance (e.g. FS locks) is not stated in the inspected subagents page beyond inheritance of sandbox/approvals and caution on parallel writes."
- "Question 3 uncertainty: Claude Stop hooks can force continuation (decision block / continue false) but no inspected primary doc defines a built-in thrashing/no-progress detector; any such stop is host-authored, not a default product invariant."
