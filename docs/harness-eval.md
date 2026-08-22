# Etabli harness eval

Frozen **harness-behavior** tasks for the Etabli workflow, graded by executable
oracles. The method follows DeepSWE (original tasks, behavior verifiers, a
fixed runner so the score is the cell): https://deepswe.datacurve.ai/ /
arXiv 2607.07946. This suite does **not** run DeepSWE's SWE tasks and does
**not** claim DeepSWE scores.

## Runners

- Pi: `pi -p --no-session --approve --model zai/glm-5.3 --thinking max`
- Grok: `grok --cwd <dir> -m grok-4.6 --reasoning-effort xhigh --permission-mode acceptEdits -p <prompt>`

Live cells are kept under a printed directory (or `ETABLI_HARNESS_EVAL_DIR`); they are not deleted on exit.

Review-hunter tasks are Pi-only (`workflow/skills/review.md` has no Grok hunter).
Grok cells are plan/implement/read-only tasks.

## Commands

```bash
# hermetic (CI / PR): no pi, no grok
bash tests/etabli-harness-eval-smoke.sh

# inspect argv without invoking a model
scripts/etabli-harness-eval print-argv --runner pi
scripts/etabli-harness-eval print-argv --runner grok

# live canary (billing; not a PR gate)
ETABLI_HARNESS_EVAL=1 scripts/etabli-harness-eval run \
  --runner pi --task review-isolation-sentinel

# full matrix (explicit)
ETABLI_HARNESS_EVAL=1 scripts/etabli-harness-eval run --runner all --output /tmp/harness.jsonl
scripts/etabli-harness-eval report /tmp/harness.jsonl
```

Live profile row `etabli-harness-eval-live` skips with exit 0 unless
`ETABLI_HARNESS_EVAL=1`. Default live cell is the Pi isolation canary.

## Layout

`tests/fixtures/harness-v1/` — manifest, overlays, oracles, synthetic
pass/fail transcripts. Kept out of `workflow/` so oracles are not on the live
symlink surface.
