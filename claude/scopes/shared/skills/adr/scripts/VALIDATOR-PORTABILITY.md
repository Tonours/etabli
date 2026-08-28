# ADR Validator Portability

`scripts/validate-adrs` is a thin wrapper. It is intentionally small, but it is
not standalone.

## Runtime contract

The wrapper needs Node.js and one shared module:

- repo-local module: `claude/scopes/shared/skills/adr/scripts/adr-validation.mjs`
- installed skill module: `~/.claude/skills/adr/scripts/adr-validation.mjs`

It resolves the repo-local module first, then falls back to the installed Claude
skill path.

## Recommended install

For a repository that owns its ADR tooling, copy both files:

```bash
scripts/validate-adrs
claude/scopes/shared/skills/adr/scripts/adr-validation.mjs
```

Then run:

```bash
node scripts/validate-adrs
```

## Wrapper-only install

Copying only `scripts/validate-adrs` is valid only when the ADR skill is already
installed at:

```bash
~/.claude/skills/adr/scripts/adr-validation.mjs
```

If neither module location exists, the wrapper fails before reading ADR files.

## CI note

Keep the validator command dependency-free:

```bash
node scripts/validate-adrs
```

Do not require Claude, Codex, npm install, or Python just to validate ADR files.
