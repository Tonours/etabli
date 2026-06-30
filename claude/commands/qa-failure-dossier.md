# Failure Dossier Prompt

You are preparing evidence for an agent or reviewer.

Read `test-results/failure-dossiers/latest.json`, `config/failure-dossier.schema.json`, the Playwright HTML report and trace artifacts when present.

Produce:

- Failure class.
- Exact failing test and project.
- Relevant error message.
- What the user was trying to do.
- Evidence from trace, screenshot, video or attachment.
- Most likely cause.
- Smallest next action.
- Validation command.

Constraints:

- Separate observed facts from assumptions.
- Do not propose unrelated refactors.
- Do not call an issue flaky unless retry evidence or trace evidence supports it.
- If artifacts are missing, state which artifact is missing.
- Treat `availability: "missing"` as authoritative; do not invent artifact paths.
- Prefer the `failures[].reproduction.command` value when asking the user or agent to rerun.
