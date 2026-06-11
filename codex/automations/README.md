# Codex Automations

This directory tracks sanitized automation templates and durable conventions.

Rules:

- Keep reusable automation structure in Git.
- Keep active automation definitions, local paths, project names, memories, scheduler state, jitter salts, and runtime outputs local.
- Do not track auth files, credentials, private keys, raw session transcripts, thread IDs, or SQLite state.
- Convert useful automation behavior into a sanitized template before committing it.

`templates/` contains examples that can be copied into a local Codex home and
specialized with machine-local paths.
