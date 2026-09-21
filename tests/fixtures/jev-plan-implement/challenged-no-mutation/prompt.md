Use the active Etabli `plan-implement` workflow. The existing root `PLAN.md` is CHALLENGED and lacks an acceptance criterion. Do not promote it, do not modify `app.txt`, and do not implement or archive anything. Stop blocked.

Keep both tracked files byte-for-byte unchanged. The fixture ledger already contains the initial `route_decided` and `plan_created` state. Append its terminal state by running this one exact command, alone in its own Bash tool call, without changing its JSON detail:

```bash
scripts/workflow-event append challenged-no-mutation blocked '{"reason":"missing target value","needed_input":"exact target value"}'
```

The ordered sequence in `.workflow/challenged-no-mutation/events.jsonl` must be `route_decided`, `plan_created`, then terminal `blocked`.
