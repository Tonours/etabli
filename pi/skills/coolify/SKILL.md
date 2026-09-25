---
name: coolify
description: Manage Coolify Cloud via its official CLI (servers, apps, databases, deployments, logs, env, backups). Use only when explicitly asked via /skill:coolify; not for non-Coolify infra.
disable-model-invocation: true
---
<!-- GENERATED:adapter-sync:start -->
skill: coolify
harness: pi
canonical: pi/skills/coolify/SKILL.md
name: coolify
description: Manage Coolify Cloud via its official CLI (servers, apps, databases, deployments, logs, env, backups). Use only when explicitly asked via /skill:coolify; not for non-Coolify infra.
pointer: Adapter for the `coolify` skill. Read and follow the shared contract in `pi/skills/coolify/SKILL.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# Coolify

The official Coolify CLI (`coolify`, coollabsio/coolify-cli, installed via
Homebrew) drives the user's Coolify Cloud instance. The `cloud` context is
already configured in `~/.config/coolify/config.json`.

## Before first use in a session

Read `llms.txt` in this folder (official quick instructions): output formats,
UUID rules, context handling, command map.

## Rules

- Use `--format json` whenever output is parsed or scripted.
- Identify resources by UUID (teams are the only numeric-ID exception). Find
  UUIDs with `coolify resources list` / `app list` / `database list` /
  `service list`. Deploys also accept names: `coolify deploy name <name>`.
- Sensitive fields (IPs, users, tokens) are masked by default. Add
  `-s/--show-sensitive` only on explicit user request.
- Never print, echo, or commit API tokens. Rotation is
  `coolify context set-token cloud <token>`.

## Safety rails (non-negotiable)

- Destructive commands (`app delete`, `database delete`, `service delete`,
  `server remove`, `projects …`, `app previews delete`, `backup delete`,
  `env delete`, `storage delete`) require explicit user confirmation naming
  the exact target before running. Never add `-f/--force` on your own.
- `database delete` defaults `--delete-volumes=true`,
  `--delete-configurations=true`, `--docker-cleanup=true`: always treat it as
  data-destroying.
- Lifecycle actions (`stop`, `restart`, `deploy`) on shared services affect
  production apps: name the target and its current status before acting.
- `deploy batch` touches many resources at once: confirm the full list first.

## Exhaustive flag catalog

Only when needed: https://raw.githubusercontent.com/coollabsio/coolify-cli/main/llms-full.txt
(138 KB — fetch on demand, never inline wholesale).

## Quick reference

```bash
coolify context verify                 # connection + auth health
coolify server list                    # servers (add -s for masked fields)
coolify resources list                 # all resources + health status
coolify app logs <uuid> -f             # follow logs
coolify app start|stop|restart <uuid>  # lifecycle
coolify deploy name <name> [--force]   # deploy by name
coolify deployments list|get|cancel    # deployment control
coolify app env list <uuid>            # env vars
```
