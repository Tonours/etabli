---
name: playwright-test-generation
description: Convert human-readable specs into executable Playwright tests with planner, generator and healer roles.
---

# Playwright Test Generation

Use this skill when turning product behavior into executable Playwright coverage.

## Planner

Read the app, seed test and product context. Write a Markdown plan in `specs/` with behavior, preconditions, steps, expected results, data and tags.

## Generator

Convert one plan into a Playwright test. Use `fixtures/base.ts`, helpers from `support/`, accessible locators and `test.step`.

## Healer

Run the test. If it fails, read artifacts before editing. Heal only test drift, setup drift or locator drift. Do not hide a product bug.

## Validation

Run the narrowest command first. Then run the relevant tag suite. Finish with changed files, commands and remaining risk.
