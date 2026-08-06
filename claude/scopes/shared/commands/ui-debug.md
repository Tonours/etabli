---
description: Repro-first UI debugging - reproduce, instrument, one hypothesis per measurement
argument-hint: [symptom description, optionally with URL or screenshot]
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion]
---

# UI Debug

User request: $ARGUMENTS

Debug a UI symptom (rendering, lag, interaction, layout) without guess-fix
loops. The failure mode this command exists to prevent: shipping fix after fix
while the user repeats "toujours le soucis".

## Protocol

1. **Reproduce first.** Drive the real page with the available browser tooling
   (Claude in Chrome / chrome-devtools MCP) and observe the symptom yourself
   before forming any hypothesis. If the symptom needs a specific environment,
   ask for the exact URL once. No repro = no fix; say so.
2. **Instrument.** Console logging read back through the browser tools,
   performance traces for lag/jank, DOM inspection for layout. Capture a
   before-state (screenshot or measurement).
3. **One hypothesis, one measurement.** State the hypothesis, define the
   measurement that would confirm or kill it, run it. No fix until a
   measurement confirms the cause.
4. **Minimal fix**, then re-run the exact repro from step 1 and capture the
   after-state.
5. **Two failed fixes = stop.** Summarize eliminated hypotheses, remaining
   candidates, and the instrumentation already in place. Do not attempt a
   third blind fix.

## Rules

- Remove all instrumentation before handing back.
- Performance claims need numbers from a trace, not adjectives.
- If the bug does not reproduce, report that as the finding — with the exact
  steps tried — instead of fixing blind.

End with: symptom, root cause (measured), fix, before/after evidence.
