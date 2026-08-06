---
name: bff-ticket-loop
description: Project skill for employer BFF epic ticket decomposition. Use when asked to decompose, source-verify, harden, or publish employer BFF sub-tickets from a Linear epic. Produces local ticket Markdown from fixed ~/work source repos, runs cross-model adversary gates, and publishes to Linear only when the final gate passes and explicit external-write authorization is present.
---

# bff-ticket-loop

Temporary, project-specific skill for the **employer BFF** epic. It reproduces the
ticket-creation loop validated on PRD-637: local-first authoring, source-verified
contracts, cross-model adversarial hardening, and optional Linear publication.

Built to be driven by `/goal`: it runs autonomously through local authoring and
validation, then writes to Linear only if the current user request or active goal
explicitly authorizes external Linear writes. The measurable authority is the
final gate below; permission to write is separate.

## Inputs

- The target epic: a Linear issue ID (e.g. `PRD-637`) or a description of the epic to decompose.
- If ambiguous, ask the single narrowest blocking question, then proceed.

## Fixed sources of truth (do NOT rediscover these per run)

**Product contract:**
- The employer BFF spec — Linear document `34ffa23dcf74` (id `249d1267-569f-4981-9a46-cf6f1d84620e`). Read via the available Linear document tool equivalent to `get_document`. This is the source of WHAT the BFF must do. If no Linear document reader is available, STOP with `BLOCKED(linear-document-unavailable)`.

**Technical certainty — these 4 repos, exact paths:**
| Repo | Role |
|------|------|
| `~/work/employer-server` | SaaS: entities, liana/api routes, permissions, error shape |
| `~/work/employer-bugfixes` | The CURRENT employer front. NOT `~/work/employer` (that checkout is a stale feature branch — never source from it). |
| `~/work/agent-nodejs` | BFF (`packages/agent-bff`), agent, agent-client, mintToken precedent, MCP `employerOAuthProvider` |
| `~/work/zendesk/employer-for-zendesk` | Zendesk app: OAuth flow, error categorization, the cross-origin callback |

## HARD GATE — repos must be in a fresh trusted source state

Before Phase 2 reads a single line of code, for EACH of the 4 repos:

```bash
bash ~/.claude/skills/bff-ticket-loop/scripts/source-gate.sh --pull
```

If the bundled script is unavailable, perform the same checks manually:

Two repo classes, different rules:

**Read-only source repos — `employer-server`, `employer-bugfixes`, `zendesk/employer-for-zendesk`:**
- **Worktree clean** (`git status --porcelain` empty) — a dirty tree risks sourcing uncommitted edits; reject + surface.
- **On a trusted source branch** — `git rev-parse --abbrev-ref HEAD` ∈ {`main`, `master`, `release-*`}. A read-only repo sitting on a feature branch (even a SYNCED one) is the bugfixes-behind-6 trap in disguise: it sources from the wrong branch silently. If not on a trusted source branch → STOP (`BLOCKED(read-only-repo-off-trusted-branch)`).
- **AND synced**: `HEAD == origin/<that-branch>`. Behind, no local commits → `git pull --ff-only`, re-check. Diverged (local commits ahead) → STOP. These three are never expected to carry local work.

**The working repo — `agent-nodejs` (carries the BFF code itself, expected on a WIP feature branch):**
- The "diverged → STOP" rule does NOT apply here — a WIP branch with local/ahead commits is the NORMAL, expected state.
- DO: `git fetch origin main`; report how far the branch base is behind `origin/main`.
- Any claim sourced from code that exists only on this WIP branch (not yet on `origin/main`) is tagged **UNMERGED** in the ticket (Phase 2) — cited but flagged, never "verified on main".
- Reject a DIRTY `agent-nodejs` tree before sourcing. Commit or stash first. Committed WIP-branch work is fine to source as UNMERGED; uncommitted work is not stable enough for file:line evidence.

No source-check claim is trusted until its repo passed this gate. This is the
employer-bugfixes-was-behind-6 lesson: a stale or dirty tree produces false file:line.

## Phases

### Phase -1 — Product contract first
1. Before reading the epic, siblings, repo code, or drafting a decomposition, read the employer BFF spec Linear document `34ffa23dcf74` (id `249d1267-569f-4981-9a46-cf6f1d84620e`) via the available Linear document tool equivalent to `get_document`.
2. Treat this spec as the loaded product contract for the whole run. If it cannot be read, STOP with `BLOCKED(linear-document-unavailable)`.
3. Extract the contract areas relevant to the target epic, plus any explicit cross-epic dependencies, before Phase 0. Record cross-epic edges in the run ledger as `pending` until both endpoint tickets exist in Linear.

### Phase 0 — Scope
1. Resolve the target epic using the available Linear issue reader equivalent to `get_issue`. Read it fully.
2. Fetch 2-3 sibling tickets already under the project/epic using the available Linear issue lister equivalent to `list_issues` (e.g. PRD-647/648/649) — these define the CANONICAL ticket format. Extract their section order.
3. Decide: which epic, format (mirror the siblings), location (`docs/plan/tickets/`, gitignored). Only ask if genuinely blocked.
4. Create or update `<epic>-README.md` as the run ledger with these exact sections: `Ticket map`, `Dependency graph`, `Cross-epic pending edges`, `Refuted findings`, `Push log`, and `Blocked states`. The README is the crash-recovery surface; every mapping, refutation, push, dependency edge, and blocker is written there before moving to the next phase.

### Phase 1 — Decomposition (structure)
1. `/plan-loop` (or an inline equivalent) on the DECOMPOSITION: how many tickets, exact boundaries, dependency order, what goes in each.
2. Rule: 1 ticket = 1 PR = 1 rollback boundary. Split on a real PR seam, not arbitrarily. A coherent single flow may stay one ticket ONLY if it still fits the size budget below; justify any non-split.
3. **Size budget gate:** estimate each ticket's PR blast radius before authoring:
   - Target: small reviewable PR, normally <= ~800 changed LOC and <= ~12 touched files.
   - Warning zone: > ~800 LOC, > ~12 files, or > 2 subsystems; must include a written non-split justification and an explicit reviewer risk note.
   - Hard stop: expected > ~1500 changed LOC, > ~20 files, or > 3 subsystems means split REQUIRED unless the change is a mechanical/generated migration that cannot be safely separated. A PR around 4k changes is never acceptable for normal product work.
   - If size is uncertain, bias toward more tickets. A false split is cheaper than an unreviewable PR.
4. **Parallelism optimization:** after correctness boundaries are set, minimize the critical path. Prefer independent tickets that can be worked in parallel; keep dependency edges only where one PR genuinely needs another's contract, schema, route, or shipped behavior. Record the intended wave order and every dependency edge in the README.
5. Adversary on the decomposition PLAN (not ticket bodies). Same discipline as Phase 3: background + retry cap (2) + parsable `VERDICT:` line + **hard cap of 3 rounds** (split/no-split is exactly where two adversaries ping-pong). Exit on 0 BLOCKER / 0 HIGH.
6. **Tiebreaker at the cap (autonomy valve):** if round 3 ends with the only open findings being a split/no-split DISAGREEMENT (not a gap/overlap/ordering defect, oversize-ticket defect, or avoidable-serialization defect — those are real and block), resolve it deterministically WITHOUT a human: **prefer MORE splits** (smaller, more parallelizable tickets is the safer default), record the decision + the dissent in the README, and proceed. Only escalate to BLOCKED if the unresolved finding is a true correctness defect (gap, overlap, cyclic deps, oversize ticket, avoidable dependency), not a granularity opinion.

### Phase 2 — Source-check (certainty)
1. Run the HARD GATE above on all 4 repos.
2. Reuse the BFF spec doc loaded in Phase -1 as the product contract. If the run context lost it, read it again before sourcing repo code.
3. Parallel scout per repo. For EVERY contract claim a ticket will assert (route, header, field, error shape, precedent), classify:
   - **VERIFIED `path:line`** — exists, cited.
   - **NOT FOUND (net-new)** — doesn't exist yet, fine; mark it NEW in the ticket.
   - **WRONG** — the repo contradicts the claim. Two sub-cases:
     - the ticket claim was just imprecise → fix it to match the repo (cite the real file:line).
     - the claim comes from the BFF SPEC and the repo genuinely contradicts the spec → mark **CONFLICT_UNRESOLVED**, a BLOCKING state. NEVER silently drop a spec requirement because the repo disagrees. Surface it; it blocks the gate until a human resolves the spec-vs-code conflict.
   - **UNMERGED** — the source code backing a claim lives on a WIP/feature branch, not merged to main (e.g. the agent-bff spike on a feature branch). Cite it but tag it `(source on branch <name>, not yet on main)` so the ticket doesn't pretend it's verified-on-main. A claim resting on unmerged code is not a stable contract — flag it.
4. Fold the VERIFIED/UNMERGED file:line refs into the tickets inline (sibling style). A claim about existing code with no file:line is not allowed. Any CONFLICT_UNRESOLVED blocks the gate.

### Phase 3 — Author + cross-model adversary (the core loop)
1. Write each ticket `.md` under `docs/plan/tickets/` with the EXACT contract embedded (routes, payloads, error codes, claims) — a dev/LLM acts from the ticket alone, never "see the spec" for the core contract.
2. **Configure and preflight both adversaries once** with a tiny real round-trip (not just `--version`), so a bad model id / effort flag fails NOW, not mid-loop:
   - Codex adversary: run headless with `codex exec` (Claude `-p` equivalent), pinned to GPT-family + `xhigh` + Fast tier when supported. Fast is a service tier/config, not a model suffix: use `--enable fast_mode -c 'service_tier="fast"'`, not `gpt-5.5-fast`. Preferred command shape: `printf 'reply: OK' | codex exec -m gpt-5.5 -c model_reasoning_effort=xhigh --enable fast_mode -c 'service_tier="fast"' --strict-config --sandbox read-only --skip-git-repo-check --ephemeral "echo back"`.
   - Pi adversary: a pinned GLM/Z.ai-family model with the highest reasoning effort available locally. Preferred command shape: `pi --print --no-session --provider zai --model "<pinned-glm-model>:xhigh" "reply: OK"`.
   - Current known-good defaults may be `gpt-5.5` + `xhigh` + Fast tier for Codex, and `glm-5.2:xhigh` for pi, but do not assume they still exist. Use the locally configured successor only if it is explicitly pinned. Never silently fall back to a default or weaker model/tier.
   - If either preflight fails to resolve a pinned model+effort, STOP with `BLOCKED(model-preflight-failed)` — cross-model review is the guarantee.
3. Cross-model adversary, BOTH run, in PARALLEL, BACKGROUND + until-loop (never foreground — they time out on big bundles). Use the SAME pinned model+effort commands proven in the preflight:
   - **codex (pinned GPT-family, highest effort)**: `cat <bundle> | <preflighted-codex-command> "<prompt>"`
   - **pi (pinned GLM/Z.ai-family, highest effort)**: `<preflighted-pi-command> "<prompt + bundle>"`
   - Background + write verdict to a temp file + until-loop on the `VERDICT:` line, with a wall-clock timeout per round (e.g. 8 min): if no verdict by then, count it as one death toward the retry cap.
   - **Per-call retry cap: 2 relaunches on death/timeout, then treat that pass as FAILED-INFRA and STOP the loop with a report.** No silent infinite relaunch.
4. **Verdict contract (parsable, or it doesn't count):** each adversary must end with a line `VERDICT: GO` or `VERDICT: BLOCK`, and list findings as `SEVERITY: ...` (BLOCKER/HIGH/MEDIUM/LOW). If the output has no parsable `VERDICT:` line, that pass is FAILED-INFRA (retry per the cap), NOT a pass.
5. Both judge: contract completeness, AC verifiability (Given/when/then), decomposition (no gap/overlap), ticket size budget, parallelism/dependency shape, buildability, dependency correctness. They are tickets NOT design docs — exact class names / specific algo libs are the implementer's call; do NOT let an adversary penalize their absence.
6. Integrate every real finding; refute (with one-line evidence, recorded) only what's wrong or sur-specification.
7. **Convergence + anti-gaming + cap:**
   - "0 BLOCKER / 0 HIGH" is counted AFTER refutation triage: a finding you've refuted with recorded one-line evidence is reclassified to REFUTED and does NOT count as a BLOCKER/HIGH. So a pass where the only BLOCKER/HIGH items are already-recorded refutations IS a clean pass. (This resolves the apparent contradiction: the raw adversary output may still print a BLOCKER, but if it's the same one already refuted with evidence, it's not counted.)
   - Refuting is for WRONG or sur-specification findings ONLY, and each refutation is logged in the README with a stable key (`<ticket>:<short-slug>`, e.g. `T4:tags-from-mintToken`) + its one-line evidence. The key is how "recurring refuted vs new" is judged auditably: same key seen again = recurring (no reset); a key not in the refuted log = new (reset + triage). You may NOT refute a real finding to escape the gate — if you and an adversary disagree on whether a security/contract finding is real, treat it as REAL and fix it (asymmetric on purpose: false-fix is cheap, missed-real is not).
   - The consecutive-clean counter advances ONLY on a pass that is clean (post-triage) from BOTH. Any ticket edit since the last pass forces the next pass to re-review the edited tickets — an edit can't sit inside a "clean" pair unseen.
   - A recurring REFUTED finding does NOT reset the counter; a NEW real finding DOES. **Asymmetric default to avoid false-DONE:** treat any re-raised BLOCKER/HIGH as NEW (reset + fix) UNLESS its evidence matches a logged refutation verbatim AND it's the same ticket+claim. The adversary doesn't emit your slug — so the burden is on a verbatim evidence match, not a loose "feels like the same finding". When unsure whether a re-raised HIGH is the old refuted one or a new one, treat it as NEW. (A redundant fix is cheap; a false-DONE on a real finding is not.)
   - **Hard cap: max 6 adversary rounds.** If not converged by round 6, STOP and surface the unresolved findings — do NOT loop forever and do NOT lower the bar to escape.
8. **Exit: two CONSECUTIVE rounds, 0 BLOCKER / 0 HIGH from BOTH adversaries, within the 6-round cap.**

### Phase 4 — English + write-direct + anti-slop (STRICT — runs BEFORE the final adversary convergence)

**Ordering rule (critical):** write-direct + anti-slop EDIT ticket bodies, so they must NOT run after the two clean adversary passes — that would push an un-reviewed final version. Apply Phase 4 edits, THEN do the Phase 3 convergence on the polished text. Equivalently: any Phase 4 edit RESETS the Phase 3 consecutive-clean counter. The version that earns the two clean passes IS the final, polished version.

- Everything in ENGLISH. No French anywhere in a ticket body. Verify with a targeted French-phrase grep (not just stopwords) — zero real French phrases.
- `/write-direct` tone on the NARRATIVE only (Outcome, Context, scoping prose): direct, short sentences, problem stated concretely, no filler. NEVER restyle contracts / payloads / error tables / AC / code refs / security lines — those stay exact.
- Anti-AI-slop, ruthless: cut filler ("it's worth noting", "in order to"), hedging, restated-obvious (a sentence repeating the title or an AC), decorative transitions, empty intensifiers ("robust", "seamless", "comprehensive"). KEEP load-bearing info and security guarantees even if terse.
- This gate is part of the final gate. A ticket with slop or any French is NOT done.

### Phase 5 — Final gate (the /goal exit condition)
- The local ticket set passes the final gate when ALL hold:
  1. Every contract claim is in a clean source state: **VERIFIED `file:line`** (synced repo), **NEW** (net-new, marked), or **UNMERGED** (sourced from agent-nodejs WIP branch, cited + flagged). ZERO **CONFLICT_UNRESOLVED** (a spec-vs-code conflict blocks the gate until a human resolves it).
  2. Both adversaries returned 0 BLOCKER / 0 HIGH on two consecutive passes.
  3. English-only + write-direct + anti-slop verified.
  4. Format matches the canonical siblings exactly (section order, flat Scope, Non-goals, AC checkboxes, Stop conditions "Pause and ask…", final `Spec: **…**` line).
  5. 1 ticket = 1 behavior, dependency line present, rollback present where it's a prod change.
  6. Each ticket fits the size budget, or carries a written non-split justification that does not violate the hard stop.
  7. Dependency graph maximizes safe parallelism; serial edges exist only for real contract/schema/route/shipped-behavior dependencies.
- Linear write authorization is present only if the current prompt or active `/goal` explicitly says to create/update/push Linear tickets without another approval. A general request to decompose, review, or draft tickets is not authorization.
- When the whole set passes the final gate and Linear write authorization is present: proceed to Phase 6. If authorization is absent: STOP with `READY_TO_PUSH` and report exactly what would be written.

### Phase 6 — Push to Linear (authorized, once gated, IDEMPOTENT)
1. **Authorization preflight:** re-check that explicit Linear write authorization is present. If not, STOP with `READY_TO_PUSH` before any external write.
2. **Title invariants:** sub-ticket titles must be UNIQUE within the epic and IMMUTABLE after push (they're the dedup key). Before pushing, assert the local set has no duplicate titles → duplicate = BLOCKED(title-collision). Record the local-file slug alongside each title in the README as a secondary key.
3. **Dedup preflight + mapping hydration (re-run safe):** use the available Linear issue lister equivalent to `list_issues`, filtered to the epic's children (`parentId` = the epic issue) — AUTHORITATIVE, not the README. Match each child to a local ticket by EXACT title (primary) cross-checked against the README local-slug→title map (secondary). If two Linear children share a title, or a title matches no local ticket → BLOCKED(ambiguous-mapping): do not guess, because Phase 7 would then wire blocks/blockedBy onto the wrong PRD-IDs. Reconcile with the README; hydrate from Linear any ticket created but missing from the README (crash between create and append). In multi-epic runs, also read earlier `<epic>-README.md` ledgers and hydrate any cross-epic pending edge whose endpoint now exists.
4. For each ticket NOT already present, use the available Linear issue writer equivalent to `save_issue`:
   - `parentId` = the **epic ISSUE id** (e.g. `PRD-637`). Linear hierarchy is issue→issue via `parentId`; Project membership is a SEPARATE `project` field. Before pushing, resolve the target: the available Linear issue reader equivalent to `get_issue <epic>` must succeed (it's an issue). If the target turns out to be a Linear PROJECT, not an issue → that's BLOCKED(ambiguous-target): a project can't be a `parentId`; surface it (the user must give the epic ISSUE id, or confirm tickets should attach to the project via `project` with no parent). Never push with a null/invalid parent.
   - inherit `team` + `project`, `labels: ["User Story"]`, priority from the epic.
   - Title = the ticket title (no "T1a —" prefix; that's a local label). Description = the gated `.md` body.
5. **A ticket whose exact title already exists under the epic is SKIPPED, not re-created.** A crash mid-push or a `/goal` re-run must not duplicate. After each create, append the local→PRD mapping to the README immediately (so a crash leaves a recoverable record).
6. If any create fails, STOP, report which succeeded (with PRD-IDs) and which remain — do not leave a silently-partial epic; the next run resumes from the mapping.

### Phase 7 — Dependency links (MANDATORY final step)
- Only run once ALL sub-tickets for the current epic exist in Linear (Phase 6 complete, full local→PRD mapping known). Translate the current epic dependency graph into `blocks`/`blockedBy` via the available Linear issue writer equivalent to `save_issue`.
- `blocks` is append-only and idempotent on Linear's side (re-posting an existing relation is a no-op), so a re-run is safe — re-post the full graph from the mapping.
- Each upstream ticket lists the tickets it blocks. This encodes the start order (blocked tickets greyed / can't start).
- Cross-epic dependency queue: every cross-epic edge has `from`, `to`, `reason`, `source evidence`, and `status` in the README. If either endpoint ticket does not exist yet, keep the edge `pending` and do not guess a Linear ID. If both endpoints exist, post the edge, mark it `posted`, read both tickets back, and mark it `verified` only when Linear matches. If Linear has an unexpected extra/missing edge, mark `blocked` with evidence.
- In multi-epic runs, after every epic and again at the end, reconcile all known `<epic>-README.md` ledgers: post and verify every pending cross-epic edge whose endpoints now exist; leave only future-endpoint edges as `pending`.
- Verify after: read back the relations of EVERY ticket that should have a blocks/blockedBy link and diff the full set against the intended graph. Missing or extra materialized links → fix before declaring DONE. Checking one ticket is not enough.
- Not optional — no materialized dependency edge is done until it is in Linear and verified. Future cross-epic edges may remain pending only when their other endpoint ticket does not exist yet.

## Terminal states (so /goal stops cleanly, never spins)

Every run ends in EXACTLY one terminal state, stated explicitly in the final message so the `/goal` loop knows to stop, not relaunch:
- **DONE** — all sub-tickets passed the final gate, pushed, all current-epic and materialized cross-epic blocks/blockedBy posted + verified, and any future-endpoint cross-epic edges recorded as `pending`. The goal condition is met for this epic; `/goal` stops or moves to the next epic.
- **READY_TO_PUSH** — all local tickets passed the final gate, but explicit Linear write authorization is absent. Report the ticket count, target epic, dependency graph, cross-epic pending edges, and exact external writes that would be performed. This is terminal until a human authorizes Linear writes.
- **BLOCKED(reason)** — a STOP condition hit (CONFLICT_UNRESOLVED, adversary FAILED-INFRA past retry cap, round cap reached without convergence, model preflight failed, ambiguous epic/project target). This is a TERMINAL state requiring human input — NOT actionable work for /goal to retry. Say `BLOCKED: <reason>` plainly so the loop halts and waits for a human. Do NOT re-loop on a BLOCKED state.

A STOP is a terminal BLOCKED, not a pause to retry the same way. If /goal re-invokes after BLOCKED with no new human input, re-emit BLOCKED — don't spin.

## Operating rules

- LOCAL-FIRST: nothing reaches Linear until the whole set is gated. No half-cooked tickets in Linear.
- EXTERNAL-WRITE AUTHORIZATION: the final gate proves ticket quality; it does not grant permission to mutate Linear.
- LEDGER-FIRST RECOVERY: `<epic>-README.md` is mandatory and must remain machine-readable enough to resume after a crash. Use stable rows for ticket map, dependency graph, cross-epic pending edges, refuted findings, push log, and blocked states.
- Cross-model is the point: codex (GPT family) and pi/glm or another Z.ai/GLM-family model catch different blind spots. Run BOTH; a finding from either counts.
- Refuse sur-specification: the ticket fixes the contract (routes/payloads/errors/claims), not the implementation (class names, file layout, specific lib). Don't let an adversary push you to design-doc detail.
- Timeout discipline: codex/pi in `xhigh` on a 40KB+ bundle are slow. Always background + until-loop on the verdict; never a bare foreground call that the harness kills at 2 min.
- `~/work/employer` is the WRONG front repo (stale branch). Always `employer-bugfixes`.
- Keep the local `.md` set as the source of record under `docs/plan/tickets/` + a `<epic>-README.md` index with the dependency graph.

## /goal usage

This skill is the body of a `/goal` run. The goal's measurable stop condition:
**every sub-ticket passes the final gate (both adversaries 0-BLOCKER/0-HIGH on two
consecutive passes, English/write-direct/anti-slop clean, format-aligned), then either
READY_TO_PUSH if Linear write authorization is absent, or DONE after tickets are pushed
under the epic with all current-epic and materialized cross-epic blocks/blockedBy links
verified, plus future-endpoint cross-epic edges recorded as pending.** Run autonomously to
the correct terminal state.
