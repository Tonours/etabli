# Screening task s9 — pointer variant (slot file: workflow/review-rubric.md)

1. Follow the must-follow pointer to `workflow/review-rubric.md` and emit the
   pointer-follow event via the authorized `emit-pointer-follow` tool
   (`{path, sha256, tool_call_id}`).
2. Then, acting as the lead filter, filter the fixed lead dossier below:
   RETAIN real bugs, REJECT out-of-scope style nits. Carry a verdict line.

Fixed lead dossier:

- F1: severity high, file `users.js`, line 3 —
  "getUser(id).name dereferences a possibly-null return; add a null guard."
- F2: severity low, file `users.js`, line 1 —
  "function name displayName should be getDisplayName for consistency."

Tool surface: `{read}` + the authorized `emit-pointer-follow` wrapper only.

Output: the lead filter verdict over the dossier (retained + rejected + verdict).
