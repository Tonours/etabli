# Screening task s7 — Logic hunter on pp-clean-1

Review the pinned patch below (Logic axis).

Tool surface: `--tools read,grep` (read-only).

Output: real Logic hunter output — template finding blocks
(`severity / file / line / issue / impact / review_comment / suggested_fix`)
or exactly `No findings.`

Pinned patch (pp-clean-1):

```diff
--- a/math.js
+++ b/math.js
@@ -0,0 +1,3 @@
+export function add(a, b) {
+  return a + b;
+}
```
