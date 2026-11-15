# Durable triggers

Use the same `--state` or `--host HTTPS_ORIGIN --token-file PATH` options as the run commands:

```sh
etabli-durable schedule-create --repo Tonours/example --cron '0 9 * * 1-5' 'Review the project and implement the next scoped improvement'
etabli-durable schedule-list
etabli-durable schedule-delete SCHEDULE_ID
```

Schedules start plan runs. Cron uses five numeric fields in UTC: minute, hour, day of month, month, day of week (0 or 7 is Sunday). Wildcards, lists, ranges and positive steps are accepted; names, aliases and seconds are rejected. When both day fields are restricted, either matching field fires. Impossible dates are rejected. Creation chooses the next minute strictly after now.

After downtime, one overdue occurrence is retained until its submission is acknowledged. The next due time is then strictly after both that occurrence and the current time. A schedule waits for its previous queued or active run to finish, so slow runs and long outages do not accumulate runs for every missed minute. Deleting the schedule prevents further submissions; it leaves already created runs available to inspect or abort.

The HTTP endpoints share the run API's authentication and JSON envelope:

- `POST /v1/schedules`: `{repo,prompt,cron,requestId}` returns `{ok:true,value:{id,requestId,repo,prompt,cron,nextDue,createdAt}}`. Times are UTC epoch milliseconds. Identical request retries return the same schedule; changed input or a deleted request identity returns 400. Use a new request id after deletion.
- `GET /v1/schedules`: `{ok:true,value:Schedule[]}`.
- `DELETE /v1/schedules/:id`: `{ok:true,value:{deleted:boolean}}`; deleting an absent schedule returns false.

Invalid fields/cron return 400, unknown routes 404 and wrong methods 405. Prompts are limited to 64000 characters, request ids and cron to 200. Supply `--request-id ID` when retrying a create command. The `schedule:` and `ci:` request-id prefixes belong to daemon triggers. Transient admission failures retain the occurrence and retry after a minute; deleting the schedule cancels a pending occurrence.

CI remediation watches only PR publications recorded with CI tracking. Previously completed runs from versions without that tracking and unrelated PRs remain inert. Checks are polled at least a minute apart, with backoff on unavailable observations. Only settled red checks on the exact recorded open PR head start a fix. Zero, pending, cancelled or unknown check results start nothing. A closed PR, foreign head or settled green result retires observation of that publication.

Each fix uses the same conversation, branch and worktree, with fresh turn and wall limits. It requires fresh reviews before updating the existing PR. After two submitted fixes still leave red CI, the run becomes `blocked` with reason `ci_attempts_exhausted`. A run already blocked or aborted is never resumed automatically. Each terminal result claims a new notification and keeps a separate immutable archive; the original archive is preserved.

To roll back, wait for active CI attempts to finish or abort them, retain their terminal archives, delete schedules, then revert the trigger code.
