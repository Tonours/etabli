# Screening task s11 — pointer variant (slot file: workflow/templates/review-logic-hunter.md)

1. Resolve the template pointer: the baseline reads the Logic hunter template
   directly; the candidate resolves it through the runner's `resolve_pointer`
   causal trace span before emission.
2. Then run the REAL Logic hunter on the pinned patch pp-swallowed-error
   below (candidate: `--patch-first` USER-concat patch-head construction).

Stated module contract: "throw on missing file" (callers rely on try/catch
upstream).

Pinned patch (pp-swallowed-error):

```diff
--- a/loader.js
+++ b/loader.js
@@ -1,3 +1,7 @@
 async function loadConfig(path) {
-  return await readFile(path);
+  try {
+    return await readFile(path);
+  } catch {
+    return null;
+  }
 }
```

Tool surface: `--tools read,grep` (read-only) for the hunter run.

Output: real Logic hunter output — template finding blocks
(`severity / file / line / issue / impact / review_comment / suggested_fix`)
or exactly `No findings.`
