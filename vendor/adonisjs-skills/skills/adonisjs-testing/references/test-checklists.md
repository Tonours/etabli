# AdonisJS test checklists

## Endpoint checklist

- generated route name used through the Japa API client when available
- success path
- invalid body
- invalid params/query if relevant
- unauthenticated path if relevant
- unauthorized path if relevant
- response contract check if relevant

## Browser checklist

- reserved for a material Hypermedia or Inertia user journey
- true navigation and visible end state asserted
- auth/session state uses the AdonisJS browser plugins when relevant
- equivalent lower-cost API assertions are not duplicated without a regression reason

## Persistence checklist

- expected row/model changes
- transaction safety if multiple writes occur
- important relation/scopes behavior

## Mail and events checklist

- side effect triggered at correct moment
- side effect not triggered on invalid/denied path

## Queues and jobs checklist

- expected job dispatched (assert via `QueueManager.fake()` + `assertPushed`)
- job not dispatched on invalid/denied path (`assertNotPushed`, `assertPushedCount(0)`, or `assertNothingPushed`)
- payload matches the triggering request
- retry or failure path covered when dropping the job would be harmful
- dedup outcome covered when product correctness depends on single-enqueue

## Config and boot checklist

- config-dependent behavior covered where risky
- startup or provider behavior covered indirectly through observable outcomes when needed

## Ace command checklist

- command executed through the Japa console-test surface
- prompts and arguments covered when relevant
- output and exit status asserted
- persistence or external side effects asserted at their visible boundary

## Tuyau checklist

- runtime validation matches inferred type expectations
- response shape asserted against the transformer output, not the raw model
- client-critical fields are covered by tests

## Review decision

Choose one:
- sufficient for ship
- missing important coverage
- unsafe to ship without more tests
