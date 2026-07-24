# vNext eval results (inspectable)

| File | Contents |
| --- | --- |
| `inventory.json` | Population inventory from `scripts/vnext-suite --inventory` |
| `baseline-run.json` | Full baseline trial records + metrics |
| `baseline-summary.json` | Compact metrics + meta invariant |
| `candidate-1-reward-hack.json` | Rejected candidate comparison |
| `live-blocked.json` | Mechanical live gate when budget unset |
| `goal-completion.json` | Goal done record (user may waive live) |
| `residual-risks.md` | Remaining risks |

Regenerate baseline:

```bash
scripts/vnext-suite --json --strategy baseline --out workflow/vnext/results/baseline-run.json
```

Live path requires `LIVE_EVAL_BUDGET_USD` and explicit spend authorization.
