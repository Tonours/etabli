# Mail, events, and jobs playbook for AdonisJS 7

Use this file when the feature sends email, emits events, reacts asynchronously, or runs operational background work.

## Mail

### Default path

- validate first
- persist state if needed
- send through Adonis Mail
- keep send triggers visible in the workflow

### Watch for

- mail sends hidden inside unrelated layers
- random SDK or SMTP wrappers where Mail is enough
- email sent before the underlying state change is safe

## Events and listeners

### Default path

- emit events from visible workflow points
- keep listeners focused and understandable
- use events for reactions, not to hide the main business path

### Watch for

- listeners doing too much
- surprise side effects without tests
- events used as architecture camouflage for missing service boundaries

## Jobs, commands, scheduler, and queues

### Default path

- commands for operator-triggered tasks
- background jobs through the first-party experimental `@adonisjs/queue`: typed `Job<T>` classes, `dispatch()` / `dispatchMany()` from application code, a separate worker (`queue:work`) with heartbeats, Redis/Database/Sync adapters, retries/backoff, batching, and dispatch-time dedup when retries can double-enqueue
- recurring jobs through the queue scheduler (`start/scheduler.ts`, cron or interval)
- Ace commands that dispatch under the sync adapter should load configured job locations first
- introduce a queue only when the work is too slow or heavy for the request — but when you do, use the official package (pinned while experimental), not a third-party or project-native worker
- keep execution entry points explicit and observable

### Watch for

- recurring behavior hidden in HTTP requests
- startup-triggered jobs buried in imports
- a custom queue/worker setup where `@adonisjs/queue` covers the need and the project accepts its experimental API surface
- async work with no clear failure, retry, or visibility path
- duplicate job storms on webhook/HTTP retries when `.dedup()` would fit

## Safety rule

If a side effect should only happen after a successful write, make that ordering explicit and test it.
