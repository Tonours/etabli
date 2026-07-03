# Subagent A — verbatim return

- Task: #2 (agentType: Explore, agent `f4f1f954-50d7-420`)
- Status at retrieval: **completed**
- Scope: verify `etabli/pi/AGENTS.md`, `etabli/workflow/skills/orchestration.md`,
  `etabli/docs/agentic-workflow-hardening.md` describe Pi `Task*` / subagents logic.

## Result

Verification complete. Evidence gathered from the three target files plus
corroborating runtime/package evidence (installed packages,
`.workflow/pi-task-subagent-e2e/` results).

## Per-file verdicts

**1. `etabli/pi/AGENTS.md` — MISSING-ASPECTS (not inaccurate)**
Its "Delegation" section is generic: *"delegate independent subtasks only when a
supported subagent runner is available"*. It does **not** name the Pi `Task*`
family, `@tintinweb/pi-tasks`/`pi-subagents`, or parallel subagent dispatch. Grep
for `TaskExecute|TaskCreate|TaskUpdate|TaskList|TaskGet` returned zero hits in
this file. It intentionally defers detail to `orchestration.md`, so the `Task*`
family is described elsewhere, not here.

**2. `etabli/workflow/skills/orchestration.md` — ACCURATE**

- *"Task* tools are Pi-only"*(L14) and *"Pi may use Task* tools and
  tasks-till-done"* (L11) match reality.
- L98-101: *"`TaskExecute` requires explicit subagent tracking capability… Treat
  `TaskExecute` as blocked until the `subagents:rpc:ping`, `subagents:rpc:spawn`,
  and `subagents:rpc:stop` protocol is confirmed."* Corroborated by
  `.workflow/pi-task-subagent-e2e/final-report.md` L18/L23 (unscoped
  `npm:pi-subagents` rejected; scoped provider required) and the live RPC spawn
  evidence in `results/P2-real-e2e.md`.
- "pi-tasks can track status, cascade dependencies, or serve `TaskOutput`"
  (L103) matches `TaskList`/`TaskGet`/`TaskOutput`/`TaskUpdate` existence. Minor
  gap: parallel dispatch (`TaskExecute` takes `task_ids[]`) is not stated
  explicitly, but semantics are covered.

**3. `etabli/docs/agentic-workflow-hardening.md` — ACCURATE**

- L17 Source Matrix: *"`@tintinweb/pi-tasks` and `@tintinweb/pi-subagents`…
  `TaskExecute` subagent execution requires the scoped subagent provider and RPC
  tracking bridge."* Both packages confirmed installed
  (`/Users/tonours/.pi/agent/npm/node_modules/@tintinweb/{pi-tasks,pi-subagents}`);
  the RPC-bridge requirement matches `final-report.md`.

No edits made (read-only).
