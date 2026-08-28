# Implemented Plan Archives

This directory stores completed Etabli workflow plans after implementation and
validation. It is a memory shelf, not an active planning workspace.

Canonical contract: [`workflow/plan-archive.md`](../../workflow/plan-archive.md).

## Rules

- Keep active work in the repository root `PLAN.md`.
- Archive only implemented and validated plans.
- Use one file per implemented plan, named `YYYYMMDD-short-slug.md`.
- Do not store drafts, challenged plans, abandoned ready plans, raw chat logs,
  or backlog ideas here.

## How To Read This Directory

- Start with the newest archive when investigating current workflow behavior.
- Treat older archives as decision history unless a current source-of-truth file
  still points to them.
- Prefer current contracts for execution rules:
  - workflow routing: [`workflow/spec.md`](../../workflow/spec.md)
  - archive format: [`workflow/plan-archive.md`](../../workflow/plan-archive.md)
  - review rules: [`workflow/review-rubric.md`](../../workflow/review-rubric.md)
  - shared skill contracts: [`workflow/skills/`](../../workflow/skills/)

## Maintenance Areas

Recent archives mostly cluster around:

- workflow routing, implementation loops, and self-improvement harnesses;
- Claude and Pi adapter alignment (Codex harness removed; see ADR-0011);
- pstack task-skill vendoring (ADR-0020, ADR-0021);
- PR maintenance, review, CI, and validation helpers;
- ADR capture and project-scaffold behavior;
- local knowledge-base and durable-memory conventions.

If a plan produces a reusable rule, put the rule in the relevant source of
truth and keep the archive as the explanation of why it changed.
