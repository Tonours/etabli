# RTK - Rust Token Killer

`rtk-guard` compacts only a simple Bash command, optionally piped to
`head`/`tail`/`cat`; the rest runs raw (`workflow/runtime/rtk-data-flow.mjs`).

- `rtk proxy <cmd>`: run one command raw when compacted output would mislead.
- `rtk gain -p [--history]`: token savings for the current project.
- `rtk discover`: commands that ran raw and could have been rewritten.
