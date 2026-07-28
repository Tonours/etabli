# react-doctor CLI Reference

Observed with `react-doctor@0.2.14`.

## Useful Commands

Baseline JSON report:

```bash
npx --yes react-doctor@latest --json --full --no-respect-inline-disables --fail-on none .
```

Score only:

```bash
npx --yes react-doctor@latest --score --full .
```

Explain a diagnostic:

```bash
npx --yes react-doctor@latest --explain <file:line>
```

Project selection:

```bash
npx --yes react-doctor@latest --project <name> --json --full .
```

## Relevant Flags

- `directory`: project directory, default `.`
- `--json`: emit structured JSON
- `--score`: output only the score
- `--full`: force full scan
- `--diff [base]`: scan changed files vs a base branch
- `--project <name>`: select workspace project
- `--fail-on <level>`: fail on `error`, `warning`, or `none`
- `--no-respect-inline-disables`: audit mode that neutralizes inline lint suppressions
- `--explain <file:line>` / `--why <file:line>`: explain a diagnostic
- `install|setup`: installs react-doctor into coding agents/hooks; do not run unless the user explicitly asks

## JSON Fields To Check

React Doctor JSON includes:

- `ok`
- `projects`
- `diagnostics`
- `summary.errorCount`
- `summary.warningCount`
- `summary.totalDiagnosticCount`
- `summary.score`
- `summary.scoreLabel`
- `error.message` when project detection or scanning fails

Score `null` is not success.
