# Agentic Dev Flow (Pi)

This project uses a staged flow:

1. **Reliable overnight execution** (`nightshift`)
2. **Orchestrated ship pipeline** (`/ship`)
3. **Portable Pi settings** (relative paths + linked extension dirs)
4. **Weekly metrics** (`agent-scorecard`)
5. **Coordinator/workers fanout** (`agent-fanout` + coordinator/worker skills)

## 1) Ship Pipeline

```bash
/ship start --task "Implement X"
# runs /skill:plan + /skill:plan-review when auto=true

# after implementation
/skill:verify
/skill:review
/ship mark --result go --notes "ready"
```

Use:
- `/ship status` to inspect active run and recent GO/BLOCK outcomes.

## 2) Weekly Scorecard

```bash
agent-scorecard weekly --repo /path/to/repo
```

Outputs a markdown report with:
- Nightshift task success/failure
- Ship GO/BLOCK decisions
- Commit activity by conventional commit type

## 3) Coordinator / Workers

```bash
agent-fanout init
# edit ~/.local/state/pi-agentic/workers.md
agent-fanout run --tasks ~/.local/state/pi-agentic/workers.md
```

This creates one tmux worker window per task and starts Pi + `/ship` automatically.

## 4) Skills

- `/skill:coordinator` for orchestration and integration control
- `/skill:worker` for single-slice delivery in worker sessions

## 5) Recommended Operating Cadence

- **Morning**: review overnight report, fix failures
- **Day**: run ship pipeline per feature/fix
- **End of day**: prepare 1–3 nightshift tasks
- **Weekly**: generate scorecard and tune prompts/models/process
