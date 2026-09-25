# Screening task s5 — Logic hunter on pp-null-deref

Review the pinned patch below (Logic axis).

Stated caller contract: `getUser` returns `User | null` (documented nullable);
callers must null-check before dereferencing.

Tool surface: `--tools read,grep` (read-only).

Output: real Logic hunter output — template finding blocks
(`severity / file / line / issue / impact / review_comment / suggested_fix`)
or exactly `No findings.`

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
