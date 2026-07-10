# Implemented: Dynamic Obvault metadata routing

## Metadata
- Archived: 2026-07-10
- Source plan: Dynamic Obvault metadata routing
- Status: IMPLEMENTED
- Commit / branch: uncommitted local worktrees

## Outcome
- Obvault now derives a routing catalog at read time from verified or accepted
  note tags, aliases, titles, and basenames.
- Claude and Pi consult that catalog only when Etabli's critical built-in topic
  families do not already match.
- Newly added intentional tags become routable immediately without a watcher,
  cache migration, persistent generated index, or Etabli code change.
- The resolver passes prompts as process arguments without a shell, validates
  all returned terms, caps matched notes, times out, and fails open.

## Context
- `obvault/_meta/lib/vault.mjs`: existing scan-on-read manifest and retrieval.
- `obvault/_meta/obvault.mjs`: deterministic local CLI boundary.
- `etabli/workflow/runtime/obvault-topic-resolver.mjs`: shared host resolver.
- `etabli/claude/hooks/workflow-router.mjs` and
  `etabli/pi/extensions/workflow-router.ts`: live adapters.

## Decisions
### Treat note metadata as routing vocabulary
- Context: new KB topics were searchable but could not trigger an answer-route lookup.
- Choice: use tags and aliases as primary routing terms, with whole title and
  basename phrases as lower-weight fallbacks.
- Rejected options: summary/body token extraction and an ever-growing manual router table.
- Rationale: metadata is intentional, inspectable, and less noisy than prose.
- Consequences: note authors should choose specific tags and aliases; generic
  terms are excluded and stale/superseded notes cannot trigger retrieval.

### Rebuild on read instead of maintaining a persistent index
- Context: Obvault already scans its small compiled wiki for every query.
- Choice: build the routing catalog on each `route` call.
- Rejected options: watcher daemon, generated index file, embeddings, and cache invalidation.
- Rationale: immediate correctness and no stale-index state outweigh roughly
  60-80 ms of isolated adapter-process cost at the current corpus size.
- Consequences: introduce caching only after measured corpus growth justifies it.

### Preserve built-in routing precedence
- Context: critical families have reviewed, stable expansions.
- Choice: call dynamic metadata routing only after fixed topic rules miss.
- Rejected options: merging dynamic terms into every fixed query.
- Rationale: prevents new note metadata from silently weakening tested routes.
- Consequences: dynamic routing augments only previously unknown topic space.

## Accepted Drift
- Original plan/spec: expected an optional cache invalidated by document changes.
- Implemented reality: no cache was added.
- Why accepted: scan-on-read observes additions and removals immediately, is
  simpler, and remains comfortably inside the resolver timeout at current scale.

## Validation Evidence
- `cd /Volumes/Crucial/work/obvault && _meta/tests/run.sh`
  - result: strict validation passed for 27 notes; sources 167/167; retrieval,
    security, distillation, schema, and routing suites passed.
- `cd /Volumes/Crucial/work/etabli/pi && bun test ./extensions/__tests__/*.test.ts`
  - result: 204 pass, 0 fail.
- Etabli Claude-hook, router-eval, Obvault-routing, and workflow-docs smoke checks.
  - result: all passed; 32/32 golden routes and Claude/Pi alignment rate 1.
- Isolated FinOps dogfood.
  - result: verified tag and alias routed; generic/stale terms abstained; removal
    was observed on the next call; malicious prompt suffix never entered the query command.
- Live-vault dogfood: `Explique-moi le product discovery`.
  - result: matched `kb/saas-opportunity-discovery-patterns.md` dynamically.
- `git diff --check` in both repositories.
  - result: clean.

## Follow-up State
- Remaining risks: exact normalized phrase matching does not yet handle
  stemming or semantic synonyms; intentional aliases are the supported remedy.
- Parking lot: add a measured cache or vector layer only after scan latency or
  retrieval evals demonstrate a real need.
- Superseded docs/specs: none.
- Next links: `workflow/skills/obvault-memory.md`,
  `obvault/ref/second-brain-operating-model.md`.
