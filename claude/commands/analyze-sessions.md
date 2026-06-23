---
description: Mine ~/.claude conversation logs for recurring prompt patterns and propose skills/commands to automate them
argument-hint: "[optional: project filter or N days]"
allowed-tools: [Read, Glob, Grep, Bash, Task, AskUserQuestion]
---

# Analyze Sessions

User request: $ARGUMENTS

Scan past Claude Code conversations, find what the user repeats by hand, and
propose skills/commands to kill the repetition. Read-only. Propose before
building — never create a skill/command without confirmation.

Logs live in `~/.claude/projects/<encoded-cwd>/<session>.jsonl`. Top-level
sessions are the direct `.jsonl`; `subagents/*.jsonl` are sub-agent transcripts
(noise for this purpose).

Phases:

1. Inventory. Count top-level sessions, exclude `*/subagents/*`. Honor any
   project/date filter in $ARGUMENTS.

2. Extract human prompts. From `type=="user"` records take string `message.content`
   only, then strip the noise: pasted shell output, `<task-notification>`,
   `<system-reminder>`, hook attachments, agent result dumps, command-output XML.
   Keep lines that read like a real ask (length 8–600). Write them to a scratch file.
   Note `du -sh` / record counts so you don't read 200M into context.

3. Cluster. If the ask file is large, `split` it and fan out subagents (Task tool),
   one per chunk. Each returns themed buckets: pattern name, approx frequency,
   2-3 verbatim examples, and whether it's already tooled. In parallel, grep the
   whole corpus for intent verbs and tech themes to get global counts.

4. Already-invoked commands. Extract `<command-name>` records and count them —
   shows what's already tooled and used.

5. Synthesize. Merge the buckets. Order by ROI (frequency × manual effort).
   Separate: (a) recurring tics to fold into existing skills, (b) genuine gaps
   worth a new skill/command, (c) patterns already well covered.

6. Cross-check against installed skills/commands (`~/.claude/skills`,
   `~/.claude/commands`, `~/work/etabli/claude/commands`) so you don't propose a
   duplicate. Note recalibrations to existing artifacts where the pattern shows
   the current default is off.

7. Present the ranked candidates with `AskUserQuestion`: which to build now.
   Then implement only the confirmed ones, following the repo's conventions
   (commands in `etabli/claude/commands/` + symlink into `~/.claude/commands`;
   skills as `~/.claude/skills/<name>/SKILL.md`). Do not commit unless asked.

End on the ranked list and what was built. Surface any silent caps (chunks
dropped, sampling) explicitly.
