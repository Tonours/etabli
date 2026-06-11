# Workflow Routing

Use this file to pick the profile before spawning subagents or creating packets.

## Router

| User intent | Lane | Profile | Default action |
| --- | --- | --- | --- |
| Implement one issue or behavior | SHIP | Issue Implementation Worker | Spawn worker only for disjoint files; parent integrates |
| Review code, PR, issues, commits | REVIEW | PR Review Auditor | Spawn explorer; read-only by default |
| CI, checks, retest, merge readiness | GATE | CI / PR Gatekeeper | Spawn explorer; promote to worker only for narrow fix |
| SSH, service, runtime, computer-use | OPS | Ops & Runtime Safety Scout | Spawn explorer; read-only first with rollback |
| Product, market, workflow research | RESEARCH | Product / Workflow Research Analyst | Spawn explorer; label claims by evidence strength |
| Prompting, skills, organization | SYSTEM | No subagent by default | Keep local unless there are independent research/docs packets |
| CAD, 3D, image, UI prototype | LAB | Use a domain skill first | Use installed skill; subagent only for independent QA/review |

## Prompt Prefix

```text
Use codex-dynamic-workflows.
Lane: <SHIP|REVIEW|GATE|OPS|RESEARCH|SYSTEM|LAB>.
Profile: <profile name or none>.
Objective: <one concrete outcome>.
Out of scope: <what not to touch>.
Validation: <commands, checks, sources, or artifacts>.
Delegation: <allowed subagents and ownership>.
Stop condition: <evidence done or blocked handoff>.
```
