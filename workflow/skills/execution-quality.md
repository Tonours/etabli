# Execution Quality

Before implementation, enumerate the behavior's input domain and bounds. Start
from the failing case and cover a valid neighbor, an invalid neighbor, retained
behavior and the deciding runtime/corpus. Repeated findings from one family
require a method reassessment, not another isolated exception.

Reconcile acceptance criteria, approach and Decision Log before a review brief.
Spec/adversary/lead receive the current plan and decisions automatically through
the evidence pack; Logic stays intent-blind. Unavailable plan evidence is explicit.

Capture `shasum -a 256 PLAN.md` from the frozen reviewed input before dispatch;
record that exact hash with plan adversary provenance and verdict in
§ Review Changes. Never stamp the current hash onto an old verdict. The latest
plan pass governs. The hash identifies the dispatched snapshot, not the
current file: later operational updates change it. Material edits need fresh approval. Operational progress and
handoff belong in `PLAN.md` (Checks `last run`, Notes / Handoff).

An implemented archive matching the current root plan's exact byte hash is
bookkeeping, not a code change. Use `plan-cleanup`; archive naming, Source PLAN, IMPLEMENTED status and hash
follow the existing cleanup contract.
