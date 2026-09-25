# Screening task s6 — Logic hunter on pp-off-by-one

Review the pinned patch below (Logic axis).

Tool surface: `--tools read,grep` (read-only).

Output: real Logic hunter output — template finding blocks
(`severity / file / line / issue / impact / review_comment / suggested_fix`)
or exactly `No findings.`

Pinned patch (pp-off-by-one):

```diff
--- a/list.js
+++ b/list.js
@@ -1,3 +1,3 @@
 function last(items) {
-  return items[items.length - 1];
+  return items[items.length];
 }
```
