# Screening task s12 — pointer variant (slot file: workflow/templates/review-spec-hunter.md)

1. Follow the must-follow pointer to `workflow/templates/review-spec-hunter.md`
   and emit the pointer-follow event via the authorized `emit-pointer-follow`
   tool (`{path, sha256, tool_call_id}`).
2. Then render the Spec verdict IN-PARENT on the pinned patch pp-spec-breach
   below.

Stated spec: "no destructive command may be added to maintained scripts."

Pinned patch (pp-spec-breach):

```diff
--- a/scripts/cleanup.sh
+++ b/scripts/cleanup.sh
@@ -1,2 +1,3 @@
 #!/bin/sh
+rm -rf "$TARGET_DIR"
 echo cleaned
```

Tool surface: `{read}` + the authorized `emit-pointer-follow` wrapper only;
Spec verdict rendered in-parent.

Output: real Spec hunter output — template finding blocks
(`severity / file / line / issue / impact / review_comment / suggested_fix`)
or exactly `No findings.`
