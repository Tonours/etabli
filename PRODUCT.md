# Product

## Register

product

## Users

Etabli is for an expert developer working inside a personal AI-assisted development environment across Neovim, Pi, Claude Code, Ghostty, and tmux. The user is usually reviewing local changes, triaging hunks, writing or resolving review comments, and delegating first-pass review work to local agent CLIs without leaving the terminal workflow.

## Product Purpose

The review interface should make local code review feel as fast and deliberate as a strong pull-request review, while staying native to Neovim. Success means the user can scan changed hunks, inspect comments inline, run Pi or Claude for read-only first-pass review, resolve or revise issues, and keep review state trustworthy without adding latency or hiding critical context.

## Brand Personality

Precise, restrained, efficient.

## Anti-references

- A web UI copied into a terminal without adapting to keyboard-first constraints.
- Decorative dashboards, marketing-style cards, or animated surfaces that slow review.
- Modal-heavy flows that interrupt triage.
- Agent output that looks authoritative without line-level evidence.
- Hidden keyboard-only behavior with no discoverable path from the review inbox.

## Design Principles

- Keep review state visible at the point of decision.
- Optimize for scanning first, deep inspection second, editing third.
- Treat every agent recommendation as evidence to evaluate, not as an instruction to accept.
- Prefer stable dense layouts over decorative hierarchy.
- Preserve performance budgets even when adding richer review affordances.

## Accessibility & Inclusion

The interface is terminal-first and keyboard-first. It should preserve readable contrast through Neovim highlight groups, avoid relying on color alone for status, expose text labels for status and actions, keep motion out of the critical path, and remain usable in narrow terminal splits.
