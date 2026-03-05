# Agentic Dev Flow (Pi)

This project uses a staged flow:

1. **Reliable overnight execution** (`nightshift`)
2. **Manual plan/review/verify workflow** (`/skill:plan`, `/skill:plan-review`, `/skill:verify`, `/skill:review`)
3. **Portable Pi settings** (relative paths + linked extension dirs)
4. **Weekly metrics** (`agent-scorecard`)
5. **Coordinator/workers fanout** (`agent-fanout` + coordinator/worker skills)

## 1) Workflow Pipeline

```bash
/skill:plan "Implement X"
/skill:plan-review
# ... implement ...
/skill:verify
/skill:review
# ... commit ...
```

## 2) Weekly Scorecard

```bash
agent-scorecard weekly --repo /path/to/repo
```

Outputs a markdown report with:
- Nightshift task success/failure
- Commit activity by conventional commit type

## 3) Coordinator / Workers

```bash
agent-fanout init
# edit ~/.local/state/pi-agentic/workers.md
agent-fanout run --tasks ~/.local/state/pi-agentic/workers.md
# optional: skip coordinator window
agent-fanout run --tasks ~/.local/state/pi-agentic/workers.md --no-coordinator
```

This creates one tmux worker window per task and launches Pi in each worker,
and creates a coordinator window per repo unless disabled.

## 4) Skills

- `/skill:coordinator` for orchestration and integration control
- `/skill:worker` for single-slice delivery in worker sessions

## 5) Recommended Operating Cadence

- **Morning**: review overnight report, fix failures
- **Day**: run plan → review → implement → verify → review per feature/fix
- **End of day**: prepare 1–3 nightshift tasks
- **Weekly**: generate scorecard and tune prompts/models/process
