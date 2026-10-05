# react-doctor CLI Reference

Verified against `react-doctor@0.9.12` (`--help` output, 2026-08-14).

## Invocation

`npx --yes react-doctor@latest` is unreliable on npm 11 (Node 24): it rejects
the versioned name with `Unknown command: "react-doctor@latest"` and treats
unknown flags as npm config. Install then call the binary:

```bash
cd "$(mktemp -d)" && npm i react-doctor@latest
./node_modules/.bin/react-doctor <directory> --json --scope full --blocking none
```

`node ^20.19.0 || >=22.13.0` is required to install (npm errors `EBADENGINE`
below that). The installed binary still runs on older Node.

## Useful Commands

Baseline JSON report:

```bash
react-doctor . --json --scope full --no-respect-inline-disables --blocking none
```

Score only:

```bash
react-doctor . --score --scope full
```

Explain a diagnostic:

```bash
react-doctor why src/App.tsx:42
```

Project selection:

```bash
react-doctor . --project <name-or-path> --json --scope full
```

## Removed / Renamed Flags

| Old | Now | Behavior on the old form |
|---|---|---|
| `--full` | `--scope full` | hard error, exit 1, empty stdout |
| `--explain <file:line>` | `why <file>:<line>` | hard error |
| `--fail-on <level>` | `--blocking <level>` | deprecation warning, still runs |

## Relevant Flags

- `directory`: project directory, default `.`
- `--json`: emit a single structured JSON report
- `--json-out <path>`: write the report to a file instead of stdout
- `--score`: output only the score
- `--scope <value>`: `full` (default), `files`, `changed`, or `lines`
- `--base <ref>`: base git ref for `files`/`changed`/`lines`
- `--project <name>`: workspace names or directory paths, comma-separated
- `--blocking <level>`: severity that fails CI — `error` (default), `warning`, `none`
- `--no-respect-inline-disables`: audit mode that neutralizes inline suppressions
- `--category <category>`: filter diagnostics by category (repeatable)
- `--staged`: scan only staged files, for pre-commit hooks
- `--max-duration <seconds>`: scan time budget; partial results reported
- `--no-score` / `--no-telemetry`: skip the score API and share URL
- `install|setup`, `ci`: installs into agents/hooks/CI; do not run unless asked

## JSON Fields To Check

Root keys: `schemaVersion`, `version`, `ok`, `directory`, `mode`, `diff`,
`projects`, `diagnostics`, `summary`, `elapsedMilliseconds`, `error`.

The score is **not at the root** — it lives under `summary`:

```json
{"summary": {"errorCount": 1, "warningCount": 19, "affectedFileCount": 14,
             "totalDiagnosticCount": 20, "score": 60, "scoreLabel": "Needs work"}}
```

Each entry in `diagnostics` carries: `filePath` (not `file`), `rule` (not
`ruleId`), `plugin`, `severity`, `message`, `help`, `line`, `column`,
`category`, `id`, `normalizedFilePath`, `tags`.

On failure `ok` is `false`, `summary.score` is `null`, and `error.message`
explains why (e.g. `NoReactDependencyError`). Score `null` is not success.
