# Screening task s11 — neutral variant (extra hunter on pp-clean-3)

Review the pinned patch below (Logic axis).

Tool surface: `--tools read,grep` (read-only).

Output: real Logic hunter output — template finding blocks
(`severity / file / line / issue / impact / review_comment / suggested_fix`)
or exactly `No findings.`

Pinned patch (pp-clean-3):

```diff
--- a/list.js
+++ b/list.js
@@ -1,3 +1,4 @@
 function last(items) {
+  if (items.length === 0) return undefined;
   return items[items.length - 1];
 }
```
