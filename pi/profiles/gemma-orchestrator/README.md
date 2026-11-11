# Gemma orchestration profile

An opt-in Pi profile for short tasks with five tools and execution receipts. It uses the main Etabli model catalogue and the existing authenticated Mac mini API. It does not change the default Pi model, the ordinary Pi toolset or the inference/network services.

Start in the project directory:

```sh
gemma-orchestrate-pi
gemma-orchestrate-pi --gemma-target gromarchy
gemma-orchestrate-pi --thinking high
```

The installed settings directory defaults to `$HOME/Library/Application Support/gemma-orchestrator/orchestration/pi`. Set `GEMMA_PROFILE_DIR` to an existing profile directory for Linux, an XDG layout or another installation location. It must contain `settings.json` and a readable `models.json`; the launcher checks both before starting Pi.

`/gemma-target local` or `/gemma-target <SSH alias>` changes the target between tasks. The owner selects it; the model cannot change it. There is no persistent shell between calls. On a remote target, every `execute` uses SSH with strict host-key checking and returns framed identity and exit-status facts. SSH failure never falls back to local execution.

The tools are `execute`, `read_file`, `write_file`, `open_page` and `finish_task`. File tools are local-only and stay inside the launch directory after resolving symlinks. `execute` retains normal owner shell authority: this profile is not a sandbox, and a receipt attests the outer execution target, not the semantics of arbitrary nested subprocesses. The controller waits at most60s plus250ms cancellation grace, with64KiB output. Escaped descendants can outlive their local process group; cancellation does not attest their termination. File reads/writes are bounded to64KiB. The obvious nested-SSH check is a usability guard, not shell containment.

Receipts have controller-generated task/receipt IDs. A `done` completion requires matching successful current-task receipts. A `done` claim rejects failed or truncated receipts. Stale, forged or wrong-kind evidence is always rejected. A `blocked` response may cite a real failed command as diagnostic evidence; it does not claim success. There are eight total tool calls and one validation correction per owner task, shared by missing and rejected completion attempts. Provider transport retries are disabled in this profile. Abort and the240s task deadline stop only the current provider request and owned subprocesses; they do not restart inference services. Cancelling SSH stops the local SSH process; it does not prove that a command already started remotely has stopped. Interrupted transport never supplies successful evidence. No effects are automatically replayed on resume/reload. Owner follow-ups start a new evidence scope even when the previous task stopped without an accepted completion; steering keeps the current task. Invalid target flags are refused instead of falling back to local. New sessions take their target from the current process flag, not previous receipts.

`finish_task` must be first and alone. Accepted completion ends the loop; later calls are blocked/aborted before effects. The status distinguishes `done`, `answer`, `blocked`, `unvalidated` and interruption. The optional model note is not verified. Receipts establish which actions ran and where; they do not establish general task correctness. A file write/read does not prove a functioning Svelte project. `open_page` establishes an opening request, not a rendered page. Use actual build/browser checks for those claims.

This specialized mode disables ambient extensions, MCP discovery, skills and project context files. Use ordinary Etabli Pi when its full workflow/skills are needed. Read any relevant project instructions explicitly for work inside a project. The main catalogue is symlinked into a small separate profile settings directory, so the existing private API-key command continues to resolve without copying credentials. The launcher is pinned to the Gemma model and five tools. It starts at thinkinglow; minimal128, low512, medium1024 and high2048 are distinct budgets, with4096 maximum output tokens. Unsupported xhigh/max clamp to high through the installed resolver.

Local installation evidence and rollback instructions live in `/Volumes/Crucial/work/fleet-gemma-pi-profile-20261110-evidence`. The local command is a symlink to `scripts/gemma-orchestrate-pi`. The daily-use decision and2026-12-10 review date are in ADR-0044. No claim that the original Fleet25/25 report oracle has been achieved follows from this profile's tests.
