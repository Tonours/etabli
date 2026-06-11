# Codex Collaboration Operating System

This organization matches the observed working pattern: direct execution when the target is clear, explicit goals for long work, review/CI loops, risk gates for ops, and compact handoffs.

## Lanes

### SHIP

- Profile: Issue Implementation Worker
- Purpose: Implementation work with one behavior, one issue, one PR when possible.

### REVIEW

- Profile: PR Review Auditor
- Purpose: Find bugs, regressions, drift, weak tests, and issue/PR misalignment.

### GATE

- Profile: CI / PR Gatekeeper
- Purpose: CI, PR status, review threads, retests, merge readiness.

### OPS

- Profile: Ops & Runtime Safety Scout
- Purpose: SSH, services, homelab, local runtime, browser/computer-use, safety checks.

### RESEARCH

- Profile: Product / Workflow Research Analyst
- Purpose: Market/product/workflow research with evidence, alternatives, MVP, kill criteria.

### SYSTEM

- Profile: No subagent by default
- Purpose: Prompting, skills, Codex configuration, automations, handoffs, organization.

### LAB

- Profile: Use a domain skill first
- Purpose: CAD, 3D, image, UI exploration, prototypes, one-off creative work.

### ARCHIVE

- Profile: No subagent by default
- Purpose: Done, stale, duplicate, or too small for workflow orchestration.

## Thread Shape

- One control thread per active project for status, handoff, and queue decisions.
- One SHIP thread per issue or behavior.
- One REVIEW thread per PR, issue set, or change-set review.
- One GATE thread per PR when CI/review state becomes the main blocker.
- One OPS thread per host, service, runtime, or incident.
- One RESEARCH thread per product/workflow decision.
- Archive or reference everything else quickly; do not let one-off browser, CAD, or social tasks become project control threads.

## Naming Convention

```text
SHIP - <project> - issue #N - <behavior>
REVIEW - <project> - PR #N or issues A-B
GATE - <project> - PR #N - CI/review
OPS - <target> - <incident or check>
RESEARCH - <topic> - <decision>
SYSTEM - codex - <workflow/config>
REF - <topic> - <reusable context>
ARCHIVE - <workspace> - <old title>
```

## Parent Thread Rule

The parent thread owns the objective, integration, final validation, commit/push/merge policy, and risky approvals. Subagents own bounded packets only.

## When Resuming

Before continuing a thread, ask:

1. Is this a control, ship, review, gate, ops, research, system, lab, or archive thread?
2. What is the single current objective?
3. Which profile, if any, should be delegated?
4. What evidence proves done?
5. What must not be touched?
