# RTK

The guard rewrites a simple display command, optionally piped to
`head`/`tail`/`cat`; other compounds stay raw.

- Parent/writer: `rtk git -C <path> status`; trusted compound:
  `cd <path> && rtk git status`.
- Parent/writer exact evidence, structured data, program pipelines and file output:
  `rtk proxy <cmd>`; never compact data another program parses.
- Read-only: Read/Grep/Glob or approved simple Bash, e.g.
  `rtk git log --oneline -3`. Interior `rtk` prefixes and `rtk grep` are denied.
