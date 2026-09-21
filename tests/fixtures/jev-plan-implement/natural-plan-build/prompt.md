Use the active Etabli `plan-implement` workflow to change `app.txt` from `mode=old` to exactly `mode=new`.

Create and challenge a root `PLAN.md`, promote it to READY only when justified, implement the one-line change, validate it with `test "$(cat app.txt)" = "mode=new"`, review the final diff, archive the implemented plan at `docs/plan/natural-plan-build.md`, and remove root `PLAN.md`.

Record schema-v2 workflow events in `.workflow/natural-plan-build/events.jsonl` for run `natural-plan-build` only with `scripts/workflow-event append natural-plan-build <event> <json-detail>`. Never author timestamps or ledger JSON manually, and invoke each event as its own Bash tool call. The ordered sequence must include `route_decided`, `plan_created`, `adversary_completed`, `validation_run`, `review_completed`, then terminal `completed`. Do not change any other tracked file.
