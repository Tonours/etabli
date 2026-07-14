# Pi Workflow Adapter

Etabli's tracked Pi bootstrap loads `@agwab/pi-workflow@0.8.1` as an
explicit-use adapter for named, inspectable workflow graphs. The package is
version-pinned and filtered to `src/extension.ts`, `workflow-guide`, and
`execution-router` in `pi/agent/settings.json`; future Etabli install/deploy
runs reconcile that package into local Pi settings, but workflow execution is
never ambient.

The pinned release requires Node.js `>=22.19.0` on macOS, Linux, or WSL2. If
that runtime requirement is not met, leave the capability `blocked` and do not
claim that package/config presence proves a runnable adapter.

This is an execution adapter, not a replacement workflow contract.

| State | Owner | Contract |
| --- | --- | --- |
| `PLAN.md` | Etabli | The only implementation plan; mutable work still requires `Status: READY`. |
| `.workflow/<slug>/events.jsonl` | Etabli | Canonical append-only progress, review, validation, and terminal evidence. |
| `.pi/workflows/<run-id>/` | pi-workflow | Adapter-owned task/run artifacts used as linked runtime evidence only. |

## Allowed Initial Use

- Invocation is explicit. Ambient Etabli routing may recommend the adapter but
  must not launch `/workflow run` or `/workflow dynamic` automatically.
- Start with the bundled `spec-review` and `impact-review` workflows when their
  loaded specs declare `readOnly: true`.
- Validate before running: `/workflow validate <workflow-name-or-path>`.
- A run that launches subagents requires the same explicit delegation approval,
  bounded objective, budget, and stop condition as other Etabli delegation.
- Mutable or dynamic workflows remain behind the normal READY, permission, and
  review gates. Package availability is not authorization to bypass them.

Pi packages and pi-workflow helper/controller code run with the Pi process's
system access. Resource filtering reduces what Etabli loads; it does not limit
extension permissions. Upstream `readOnly: true` is a capability/worktree
classification signal, not filesystem or OS isolation. Use only trusted specs,
helpers, agents, and tool providers.

## Attach Runtime Evidence

After an explicitly authorized run, link its adapter state to the canonical
Etabli ledger without copying or rewriting the upstream artifacts:

```bash
scripts/workflow-event append <slug> runtime_run_attached \
  '{"adapter":"pi-workflow","run_id":"workflow_example","workflow":"spec-review","state_path":".pi/workflows/workflow_example","status":"completed","usage_measured":false}'
```

The event validator requires the repository-relative state path to equal
`.pi/workflows/<run_id>` and accepts only pi-workflow run statuses. Record
`usage_measured:false` when no measured usage was imported; never substitute
zero.

## Capability Promotion

`supports_named_workflow_graphs` stays `proxy_supported` until the active Pi
runtime proves all of the following with the pinned package:

1. `/workflow list` discovers the bundled workflows.
2. `/workflow validate spec-review` passes with the expected read-only preview.
3. An explicitly authorized read-only pilot run completes and its artifacts can
   be inspected under `.pi/workflows/<run-id>/`.
4. The matching `runtime_run_attached` event validates in the Etabli ledger.

This capability is independent from `supports_subagents`: pi-workflow uses its
own `@agwab/pi-subagent` backend, so it does not prove that Etabli's Pi Task*
`subagents:rpc:*` protocol is available.

## Sources

- Upstream: <https://github.com/AgwaB/pi-workflow>
- Pi package/security contract:
  <https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/packages.md>
