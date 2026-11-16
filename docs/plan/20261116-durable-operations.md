# Implemented: Durable production operations

## Metadata
- Archived: 2026-11-16
- Source plan: `PLAN.md` - production MCP and daily monitoring
- Source plan SHA-256: `880067abdaefbee50ce1f2083845639eab51fcd387c9876a1251c05721966e36`
- Status: IMPLEMENTED
- Commit / branch: PR #114, merge `790c1c8e808284fc019345c5cbc47b8b405edc57`
- Workflow initiative: durable-operations

## Outcome
Production now loads the personal vault and isolated headless Chrome MCP servers.
A user timer collects read-only operational evidence daily at 08:00 Europe/Paris.
Reports propose improvements without model calls, repository changes or automatic repair.
Private daily JSON records retain 30 observations; generated Markdown is not machine state.

## Decisions
- Use the existing native MCP adapter and an owned exact Chrome1.7.0 installation. Disable usage statistics, CrUX and update checks explicitly.
- Separate production startup readiness from actual callable configuration: a transient native adapter proof uses the exact configuration without a production model run.
- Use trusted application invocation journal metadata and server-side exact filtering before bounded capture. The earlier manager-field assumption was disproved by a native probe.
- Compare observed daily aggregates; unavailable data is never rendered as zero. Historical blocked runs are not new failures. Restart counter increases survive invocation changes.
- Use systemd, Unix GET-only collection, a nonblocking OS lock and atomic private files rather than a daily write-capable agent.

## Validation Evidence
- Full final core: 17/17, durable284/284 with2072 assertions; focused monitor11/11 with67 assertions; strict typecheck and cumulative secret scan passed.
- Four regression failures before fixes passed afterward. Wrong journal field, one-prior and same-day mutants failed decisive assertions; restored controls passed. Automated mutation unavailable on Linux.
- Independent T2 full and D1 documentary closing reviews: GO WITH NOTES; GitHub review GO and CI passed on14d1bb35.
- Fresh owned0700 activation evidence directory: `/tmp/etabli-operations-activation-m0vualvg`. Native preflight six calls passed and owned children exited. Production journal reports both servers ready.
- Before/after hashes and API evidence preserve run rows, documents, keys and Serve. Unrelated canonical user edits retained their hashes.
- Two actual monitor executions: all sources healthy, one same-day record; report files0600 and root0700. Next timer17November2026 08:00CET.
- Actual Mac mini HTTPS API/WSS/static/session/push-key/logout checks passed, with revoked session401.
- Separate0400 SQLite deployment snapshot restored in isolated scratch with identical hash/integrity; private config exact-byte rollback rehearsed in scratch. Production rollback was not needed or performed.

## Follow-up State
Report: `~/.local/state/etabli-durable-monitor/latest.md`.
Disable only monitoring: `systemctl --user disable --now etabli-durable-monitor.timer`.
Readiness is startup evidence from the cgroup, not continuous health or confinement; same-cgroup forged messages remain a low reporting risk. Use a fresh private proof destination because creation mode does not change existing file permissions. The launcher requires Node26 on the service PATH. Generated reports explicitly distinguish resets from improvements; runbook wording remains terser. Symlink pre-write guard test uses an unchanged sample and is weaker than a mutation-specific assertion. One cosmetic missing space remains in symlink-layout documentation. No additional runtime work is pending.
