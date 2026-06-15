# Integration Decisions

## Accepted

- Name the system "boucle de travail agentique" or "agentic workflow loop".
- Treat "agents" primarily as role contracts inside Pi skills/templates:
  router, planner, challenger, implementer, verifier, reviewer, reporter.
- Keep Pi as the interaction surface. Use Pi skills for visible workflows and Pi
  extensions for mechanical lifecycle nudges.
- Keep `PLAN.md` as the single active work artifact. Do not add a second
  mandatory planning document.
- Add a verifier role because validation is currently duplicated inside
  implementation behavior and not independently reusable.
- Add a small evaluation fixture suite for prompts/routing/stop conditions before
  attempting more automation.
- Improve `tasks-till-done` incrementally so it understands workflow evidence,
  not just task status.

## Rejected

- Wrapping Pi in Python, LangGraph, AutoGen, ADK, or another runner.
- Creating many always-on specialist agents before there is fixture evidence that
  role separation improves outcomes.
- Putting all rules into one large system prompt.
- Using hidden prompts as the only source of truth.

## Main Trade-Off

The most deterministic layer is not another LLM role; it is a narrow contract
plus a check. Therefore each proposed layer must answer:

1. What decision surface does this reduce?
2. What evidence proves it worked?
3. What does it stop doing when it fails?
