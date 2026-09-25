# Screening task s10 — pointer variant (slot file: workflow/skills/review.md)

1. Follow the must-follow pointer to `workflow/skills/review.md` and emit the
   pointer-follow event via the authorized `emit-pointer-follow` tool
   (`{path, sha256, tool_call_id}`).
2. Then CALL the runner-provided `dispatch-review` tool on the pinned patch
   pp-null-deref below. The tool pins the patch to temp, spawns the Logic
   child, runs Spec in-parent, applies the lead filter, and records each
   phase with chained ids in the trace. The functional result is the
   EXECUTION verdict over those phases, never a dispatch plan.

Pinned patch (pp-null-deref):

```diff
--- a/users.js
+++ b/users.js
@@ -1,4 +1,3 @@
 function displayName(id) {
-  const user = getUser(id);
-  return user == null ? "anon" : user.name;
+  return getUser(id).name;
 }
```

Tool surface: `{read}` + the authorized `emit-pointer-follow` wrapper +
the authorized `dispatch-review` tool.

Output: the executed dispatch verdict judging the recorded phase outputs.
