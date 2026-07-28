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

## Jobs, commands, scheduler

### Default path

- commands for operator-triggered tasks
- scheduler for recurring tasks
- queue/job integration only when justified by workload or latency needs
- keep execution entry points explicit and observable

### Watch for

- recurring behavior hidden in HTTP requests
- startup-triggered jobs buried in imports
- async work with no clear failure/visibility path

## Safety rule

If a side effect should only happen after a successful write, make that ordering explicit and test it.
