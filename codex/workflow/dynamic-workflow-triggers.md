# Dynamic Workflow Trigger Recipe

## Trigger
- `/goal`
- explicit agent `workflow` or `dynamic workflow`
- explicit `subagents`, `parallel agents`, `delegate`, or `swarm`
- broad risky work where orchestration reduces drift

## Plan Shape
1. Restate the goal and success criteria.
2. Identify repository/workspace, current state, validation, and out-of-scope actions.
3. Create/update `.workflow/<slug>/` when the work is substantial or may span turns.
4. Split into packets only when there are independent tracks.
5. Keep the immediate critical path local.
6. Delegate bounded sidecar packets when authorized and useful.
7. Integrate results, resolve conflicts, and verify.

## Packet List
- Discovery or source-of-truth audit
- Implementation slice with disjoint ownership
- Tests or validation
- Docs or handoff
- Security/risk review for sensitive work

## Verification Checklist
- Workflow artifact has goal, criteria, context, risks, packets, integration policy, and verification.
- Subagents were spawned only when authorized and useful.
- Packet ownership was disjoint.
- Final answer distinguishes observed facts from assumptions where relevant.
- Checks match the blast radius.

## Known Risks
- Over-orchestration slows trivial tasks.
- Vague keyword matching can trigger unintended workflows.
- Subagents can duplicate work without strict packet ownership.
- Incidental mentions of CI/GitHub workflows should not trigger agent orchestration.
- Some Codex surfaces may not expose a subagent runner; simulate packets in that case.
