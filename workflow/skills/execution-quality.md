# Execution Quality

Before implementation, enumerate the behavior's input domain and bounds. Start
from the failing case and cover a valid neighbor, an invalid neighbor, retained
behavior and the deciding runtime/corpus. Repeated findings from one family
require a method reassessment, not another isolated exception.

Reconcile acceptance criteria, approach and Decision Log before a review brief.
Spec/adversary/lead receive the current plan and decisions automatically through
the evidence pack; Logic stays intent-blind. Unavailable plan evidence is explicit.

A new `plan_created` event with a real root plan binds its semantic contract.
Capture `scripts/plan-review-check --hash PLAN.md` from the frozen reviewed input
before dispatch; append that exact `plan_contract_sha256` with plan adversary
provenance and verdict. Never stamp the current hash onto an old verdict. The
latest plan pass governs. Material edits need fresh approval.

The hash retains normalized source bytes in all sections, including command
escapes, unknown prose, link targets and code examples. It excludes only simple single-line Meta Status/Last revised/
Archive fields, simple nested check last-run results, and list task completion
markers. Operational progress and handoff belong in ledger events. Confined
active-run `.md`/`.patch` preparation and fixed read-only plan-review runner argv
remain available before approval; no shell chains, expansion or outside capture.

Pi helper executions use native capture by default (private temporary receipts
when no directory is supplied). Default runs retain transport semantics when
usage is unmeasured; explicit captures still require complete usage.

Native Read/Grep errors are inspection evidence. A positive verdict is refused
while any attempted inspection is unresolved or inspection identity, input or result content is malformed.
Only a successful retry of the same tool/input clears an error. Transport and
usage measurement remain separate; successful observed reads do not prove full
coverage. BLOCK reports and ordinary successful no-match searches remain valid.

An implemented archive matching the current root plan's exact byte hash is
bookkeeping: append `archive_written`, never `file_changed`. Use `plan-cleanup`
then `plan_removed`; archive naming, Source PLAN, IMPLEMENTED status and hash
follow the existing cleanup contract. Tests prove guards on fixtures; reduced
review count requires a later comparable live measurement.
