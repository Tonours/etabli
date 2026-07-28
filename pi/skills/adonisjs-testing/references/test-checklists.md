# AdonisJS test checklists

## Endpoint checklist

- success path
- invalid body
- invalid params/query if relevant
- unauthenticated path if relevant
- unauthorized path if relevant
- response contract check if relevant

## Persistence checklist

- expected row/model changes
- transaction safety if multiple writes occur
- important relation/scopes behavior

## Mail and events checklist

- side effect triggered at correct moment
- side effect not triggered on invalid/denied path

## Config and boot checklist

- config-dependent behavior covered where risky
- startup or provider behavior covered indirectly through observable outcomes when needed

## Tuyau checklist

- runtime validation matches inferred type expectations
- serialized response shape is intentional
- client-critical fields are covered by tests

## Review decision

Choose one:
- sufficient for ship
- missing important coverage
- unsafe to ship without more tests
