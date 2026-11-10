---
status: accepted
date: 2026-11-10
tags: [pi, local-models, orchestration]
affected_components: [pi/profiles/gemma-orchestrator, scripts/gemma-orchestrate-pi, pi/models.json]
---

# Keep local Gemma orchestration opt-in and bind completion to execution receipts

The owner intends daily use of a local Mac mini orchestration model. A real Pi session demonstrated local/remote confusion and claimed actions without tool executions. Add an opt-in five-tool profile with an owner-selected target, actual execution metadata and current-task receipt checks. It replaces the ambient prompt/tool loadout only in its own process; general Etabli Pi is unchanged. Native boundary termination and a single validation continuation are tested through actual provider HTTP calls. Receipts establish an action and its outer execution target, not the truth of free-text notes or full task correctness. Shell execution retains normal owner authority and is not a sandbox. No cloud fallback or automatic replay of side effects is introduced. The main and isolated model profiles expose distinct supported thinking budgets. Review date: 2026-12-10. If the profile has not been used weekly by that review, remove it and its launcher after preserving the qualification report. Keep original failed25/25 results separate from the new execution-profile probes.
