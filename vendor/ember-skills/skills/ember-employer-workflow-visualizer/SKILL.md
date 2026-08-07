---
name: ember-employer-workflow-visualizer
description: "Work safely inside employer workflow visualizer: orchestrator/executor split, state, services, and step UI."
version: 0.2.0
author: employer Team
license: Proprietary
---

# Ember employer Workflow Visualizer

Use this skill for `app/features/workflow-visualizer`.

## Mental model

The workflow engine is split so client data never leaves client infrastructure:

- Executor: runs in client infrastructure, executes AI steps, reads/writes records, stores result data locally.
- Orchestrator: employer server, owns state machine, workflow history, step definitions, and sees outcome metadata only.
- Frontend: displays the running workflow, relays user interactions to orchestrator, pulls execution data from executor for display.

APIs:
- Orchestrator: `/api/workflow-orchestrator`, employer JWT, start/resume/continue/revise/abort runs.
- Executor: `/employer/_internal/workflow-executions`, proxied employer JWT, wake executor/fetch step result data.

## Service map

- `services/feature.ts` — public API; all component actions go through here.
- `state.ts` — reactive state; only `feature.ts` writes it.
- `services/internal-business/orchestrator.ts` — orchestrator HTTP calls.
- `services/internal-business/executor.ts` — executor HTTP calls.
- `services/internal-business/step-hydrator.ts` — merges server history and executor steps.
- `services/internal-business/subscription.ts` — WebSocket subscription `workflowRunUpdated`.
- `services/internal-business/utils.ts` — derived views like card steps/current step/substeps.

## State highlights

Server data:
- `workflowRunId`, `workflowId`, `workflowName`, `collectionId`, `runState`.
- `serverHistory` raw orchestrator history.
- `executorSteps` display data from executor.

UI data:
- side panel visibility/collapse.
- open step indices.
- selected workflow records.
- async flags for start/abort/revise/manual/pending data.
- `continuingFromStepIndex` optimistic state.

Derived:
- `history` hydrated from server + executor.
- `isInteractive`.
- `pendingExecutorStep`.

## Adding step UI

1. Create `components/step/[step-name]/component.ts`, `template.hbs`, `style.scss`.
2. Read step data from `@stepHistory.executorStep` and narrow with `StepExecutionTypeEnum`.
3. Wire user actions through `featureService.*()` only.
4. Use loading/error patterns from `stepHistory.isLoading` and `stepHistory.context?.error`.
5. Add to `CARD_STEP_TYPES` in `feature.ts` if it should render as a card.
6. Add or update tests for hydration, card visibility, and user actions when behavior changes.

## Step types

Task types with display result data include:
- `GetData` / executor `ReadRecord`
- `UpdateRecord`
- `TriggerAction`
- `LoadRelatedRecord`
- `Mcp`
- `Guidance`

`Condition` is routing-only and has no display data.

## Gotchas

- `reviseStep` and `submitPendingData` are no-ops when `!state.isInteractive`; check `isInteractive` before showing actions.
- Methods in feature service should catch failures so components do not repeat error handling.
- Use selector prefix: `data-test-feature-workflow-visualizer-[component]-[element]`.
- CSS prefix: `.c-feature-workflow-visualizer-[component]`.

## Definition of done

- Orchestrator/executor concerns remain separated.
- Component actions go through `services/feature.ts`.
- Hydration logic remains in business service.
- New step type updates docs/types/tests.
- Executor payload display never leaks client record data to orchestrator calls.
