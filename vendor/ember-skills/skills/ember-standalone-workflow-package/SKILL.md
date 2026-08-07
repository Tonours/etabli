---
name: ember-standalone-workflow-package
description: Maintain the standalone framework-agnostic workflow execution package without leaking Ember or external IO.
version: 0.2.0
author: employer Team
license: Proprietary
---

# Ember Standalone Workflow Package

Use this skill for `app/features/workflow/services/standalone-package`.

## Objective

This package is a framework-agnostic workflow execution engine. It must execute workflows identically on frontend Ember and backend Node.js. Same code, different interface implementations.

## Golden rule

The package never calls the outside world directly. Every external interaction goes through an interface supplied by the consumer.

External interactions include:
- persisting state.
- tracking activity.
- calling an LLM.
- fetching/updating records.
- notifying consumers.
- handling escalation.

## Structure

```text
interfaces/      # IO boundary contracts, .d.ts, default export, JSDoc
types/           # pure data/enums/interfaces/classes/type guards
services/        # engine core, AI module, parser module
step-modules/    # one folder per step type
```

Main services:
- `workflow-engine.ts` — orchestrates execution through injected interfaces.
- `ai-module/` — AI service/prompts/tool execution/record selection.
- `parser-module/` — BPMN parser and warnings.

Step module structure:
- `step-type.ts` — extends `WorkflowStep`, declares type, builds execution service.
- `context.ts` — step-specific context result/params types.
- `execution-service.ts` — extends `AbstractStepExecutionService`, implements execution and context creation.

## Interfaces

Known interface roles:
- `StateInterface` — read/write workflow run state.
- `ActivityTrackerInterface` — log workflow activity.
- `LlmInterface` — provide model/tools via abstraction.
- `AgentInterface` — collection/record operations.
- `RunListenerInterface` — notify consumer on run updates.
- `EscalationInterface` — handle human intervention/approval.

## Hard rules

- Relative imports only inside the package.
- No absolute imports like `client/...` that reference code outside the package.
- No new Ember/framework imports. Existing `@tracked` is temporary; do not expand it.
- Constructor dependency injection for interfaces; no decorators.
- Business logic lives in this package; IO is passed in.
- Interfaces are contracts only, never concrete implementations.
- Types contain data and type guards, not side-effectful logic.

## Adding an external dependency

1. Create `interfaces/[name]-interface.d.ts` with the contract.
2. Accept it through constructor/options when needed.
3. Consumer provides implementation.
4. Update the package `CLAUDE.md` interface table.

## Definition of done

- Engine remains framework-agnostic.
- No direct IO imports or calls were introduced.
- New step follows step module structure.
- Interfaces/types/docs are updated.
