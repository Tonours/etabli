---
name: react-doctor-100
description: Run react-doctor on React codebases and iteratively fix diagnosed issues until the project reaches a verified score of 100 without shortcuts. Use when the user asks to run `npx react-doctor@latest`, improve React project health, fix react-doctor findings, chase a react-doctor score, audit React performance/security/correctness/accessibility/bundle/architecture issues, or create a `/goal` to keep fixing a React project until react-doctor is clean.
---

# React Doctor 100

Use this skill to run `react-doctor` as a hard quality gate for React projects, then fix root causes until the score is verified as 100.

## Core Contract

Target score 100 is not enough by itself. Completion requires:

- `react-doctor` reports score `100`.
- Project validation appropriate to the repo passes: tests, typecheck, lint, build, or documented equivalents.
- Fixes address root causes rather than hiding diagnostics.
- Remaining false positives, tool bugs, or blocked checks are reported instead of treated as success.

## Baseline

Before editing:

1. Run `git status --short` in the project and preserve user changes.
2. Confirm the target is a React project through `package.json`, workspace config, or detected React dependency.
3. Detect package manager and validation scripts from project config.
4. Capture a baseline report (script path is relative to this skill's
   directory; the target repo is the argument):

```bash
python3 scripts/run_react_doctor.py /path/to/react/repo
```

The script exits `0` only when it produced a real score. Exit `2` means bad
input or no usable Node; exit `3` means react-doctor ran but no score came
back, with the reason on stderr. A `score=None` is never a pass.

If the script is unavailable, install the package into a scratch directory and
call its binary directly — `npx react-doctor@latest` is unreliable on npm 11,
which rejects the versioned name and swallows unknown flags as npm config:

```bash
cd "$(mktemp -d)" && npm i react-doctor@latest
./node_modules/.bin/react-doctor /path/to/react/repo \
  --json --scope full --no-respect-inline-disables --blocking none
```

Read `references/react-doctor-cli.md` when flags or output shape are unclear.

### Node prerequisite

`react-doctor@0.9.12` declares `node ^20.19.0 || >=22.13.0`. Older Node (for
example v22.12.0) fails the **install** with `EBADENGINE`; the binary itself
still runs once installed. The script auto-selects a supported interpreter,
preferring the current `node` and otherwise scanning `~/.nvm/versions/node/`
and `$ASDF_DATA_DIR/installs/nodejs` (default `~/.asdf`) newest-first
newest-first. If none qualifies it stops with an explicit message instead of
producing an empty report.

## Fix Loop

Repeat until the completion contract is proven:

1. Parse the latest report and identify the highest-impact cluster.
2. Prefer fixes in this order: correctness/security, accessibility, performance, bundle/dead code, architecture/design.
3. Make the smallest defensible change that fixes a real issue.
4. Add or update tests when behavior changes.
5. Run the narrowest useful project validation.
6. Rerun react-doctor and compare score/diagnostics against the previous report.
7. Broaden validation before declaring completion.

When a diagnostic is unclear, use the `why` subcommand (`--explain` was removed
in 0.9.x):

```bash
./node_modules/.bin/react-doctor why src/App.tsx:42
```

## No Shortcuts

Do not:

- add blanket `eslint-disable`, `oxlint-disable`, or similar suppressions to silence diagnostics
- remove functionality only to improve the score
- weaken lint, test, typecheck, build, or react-doctor configuration
- hide files from analysis unless they are generated artifacts and the repo already treats them that way
- pin or downgrade `react-doctor` to get an easier score
- treat score `null`, missing project detection, skipped score, or `--no-score` output as success
- ignore failing project validation because react-doctor is green
- commit, push, amend, force-push, install hooks, or run `react-doctor install` unless the user explicitly asks

Inline suppressions already in the project should be audited with `--no-respect-inline-disables` unless the user asks for a different mode.

## Monorepos

For workspaces:

- If the user names a package/project, scan that target first.
- If no target is named, run a full scan and let react-doctor detect projects.
- Use `--project <name>` only after confirming the names from the report or
  project config. It accepts workspace names or directory paths, comma-separated
  for multiple targets.
- Do not fix unrelated packages just because they share a workspace.

## Recommended Goal

Use this when the user asks for a reusable `/goal`:

```text
/goal In the current React project, run react-doctor in full audit mode (`--scope full`), capture the baseline score/report, and iteratively fix real root-cause issues until react-doctor reports score 100 and the repo's relevant tests/typecheck/lint/build validations pass. Preserve existing behavior and user changes; do not suppress, hide, downgrade, disable, or remove functionality just to improve the score. After each fix slice, rerun the narrowest useful validation and react-doctor, then choose the next highest-impact diagnostic cluster. If score 100 is impossible because of no React project, tool failure, false positive, missing external dependency, or conflicting requirements, stop with the latest report, attempted fixes, evidence, remaining diagnostics, and the exact blocker.
```

## Final Report

End with:

- baseline score and final score
- files changed
- diagnostic clusters fixed
- validation commands and outcomes
- skipped checks with reasons
- remaining risks or blockers
