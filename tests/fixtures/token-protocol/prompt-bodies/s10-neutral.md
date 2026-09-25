# Screening task s10 — neutral variant (extra hunter on pp-swallowed-error)

Review the pinned patch below (Logic axis).

Stated module contract: "throw on missing file" (callers rely on try/catch
upstream).

Tool surface: `--tools read,grep` (read-only).

Output: real Logic hunter output — template finding blocks
(`severity / file / line / issue / impact / review_comment / suggested_fix`)
or exactly `No findings.`

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
