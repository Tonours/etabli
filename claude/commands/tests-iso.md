---
description: Add or complete tests that are indistinguishable from the existing test suite
argument-hint: [file, module, or "last commit"]
allowed-tools: [Read, Glob, Grep, Bash, Write, Edit]
---

# Tests Iso

User request: $ARGUMENTS

Write tests that match the local test culture exactly. A reviewer must not be
able to tell which tests are new.

## Steps

1. Resolve the target: explicit file/module, or the files touched by the last
   commit when asked.
2. Read 2-3 neighboring test files for the same layer and extract the local
   conventions before writing anything:
   - runner and config actually used (do not assume);
   - structure: `describe('when ...')` for context, `it('should ...')` for
     behavior, or whatever the neighbors do;
   - setup style: mocks, factories, fixtures, mirage, sinon — reuse the
     existing helpers, never introduce a new mocking approach;
   - selectors: `data-test-*` wherever the suite uses them.
3. Enumerate the missing cases: happy path, edge cases, error paths. List them
   before writing.
4. Write the tests iso-style.
5. Run the narrowest matching test command; iterate to green. Never weaken an
   assertion to pass.

## Rules

- The diff contains test files only.
- No new test dependencies without asking.
- Failing pre-existing tests are reported, not silently fixed.

End with the exact test command run, its result, and the list of covered and
deliberately uncovered cases.
