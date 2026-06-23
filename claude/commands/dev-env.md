---
description: Local dev-env helpers — kill ports, open a Ghostty+Claude window, set Node version
argument-hint: "kill-ports 4200 4000 | ghostty-claude [dir] | set-node [version]"
allowed-tools: [Bash, Read]
---

# Dev Env

User request: $ARGUMENTS

Run the matching helper. If no subcommand is given, infer it from the request.

## kill-ports <port...>
Kill whatever listens on each port. Default set when none given: 4200 4000 4001 4002.
```
lsof -ti tcp:<port> | xargs -r kill -9
```
Report per port: killed PID(s) or "free".

## ghostty-claude [dir]
Open a new Ghostty window in `dir` (default: current cwd) running Claude with
`--dangerously-skip-permissions`.
```
open -na Ghostty --args --working-directory="<dir>" -e "claude --dangerously-skip-permissions"
```
If `-e` is unsupported by the installed Ghostty, fall back to launching Ghostty
in the dir and printing the exact `claude` command to paste.

## set-node [version]
Set the default Node via nvm. With no version, read `.nvmrc`/`package.json` engines
in cwd and use that; else default `v24.10.0`.
```
nvm install <version> && nvm alias default <version> && nvm use <version>
```
Confirm with `node -v`.
