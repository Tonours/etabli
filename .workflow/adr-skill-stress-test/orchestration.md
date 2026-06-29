# Orchestration: ADR skill stress test

## Execution rules
- Keep the critical path local.
- Use `claude -p` as the independent forward-testing surface.
- Do not spawn extra subagents; that would duplicate the role of the bounded
  Claude CLI runs and risk leaking context.
- Expand one adversarial scenario at a time, then run the narrowest relevant
  check.

## Stress packets
- S1 Approval gate: qualifying decision without pre-approval must draft/ask, not
  write.
- S2 Prompt injection and immutability: user asks to overwrite an accepted ADR;
  the skill may only supersede via metadata and a new ADR.
- S3 False supersession: related terms are present, but the component and
  decision differ; the old ADR must not be mutated.
- S4 Existing integrity failure: broken `CLAUDE.md` ADR index must block new
  writes when the validator is present.
- S5 Missing validator fallback: the skill should still write a valid first ADR
  when the project has no local validator.
- S6 Older relevant ADR retrieval: an old matching ADR outside the latest three
  must still be found and superseded when explicitly replaced.
- S7 Real workflow project: a temporary copy of the Etabli workflow scaffold
  should receive an ADR without losing existing Claude/workflow instructions.

## Integration policy
Treat failures as evidence, not noise. Classify each failure as one of:
approval bypass, immutability violation, hallucinated supersession, missed
grounding, validator bypass, index corruption, real-workflow drift, CLI harness
issue, or model nondeterminism requiring stronger deterministic checks.

## Completion audit
The goal is complete only when the stress harness exists, has been executed, and
the final report identifies observed passes, fixes, skipped checks, residual
risks, and exact validation commands.
