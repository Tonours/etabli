# Shadow promotion candidate (not durable kb)

mode: {{MODE}}
date: {{DATE}}
shadow_only: true
durable_status: draft-candidate
apply_allowed: false

## Decision
{{DECISION}}

## Preconditions (route / checks)
- route: {{ROUTE}}
- preconditions: {{PRECONDITIONS}}
- checks: {{CHECKS}}

## Outcome (validation)
{{OUTCOME}}

## Archive reference
{{ARCHIVE}}

## Candidate wikilinks (update-before-create)
{{WIKILINKS}}

## Gate
- Automated Etabli runs may only prepare this payload.
- Use obvault `capture` / `distill --shadow` under a separate approved path.
- Never paste secrets, full transcripts, live PLAN.md, or ticket dumps into kb/.
