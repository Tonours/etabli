# Screening task s8 — Logic hunter on pp-clean-2

Review the pinned patch below (Logic axis).

Tool surface: `--tools read,grep` (read-only).

Output: real Logic hunter output — template finding blocks
(`severity / file / line / issue / impact / review_comment / suggested_fix`)
or exactly `No findings.`

Pinned patch (pp-clean-2):

```diff
--- a/users.js
+++ b/users.js
@@ -1,4 +1,4 @@
 function displayName(id) {
-  const user = getUser(id);
-  return user == null ? "anon" : user.name;
+  const user = getUser(id);
+  return user?.name ?? "anon";
 }
```
