severity: high
file: users.js
line: 3
issue: getUser(id).name dereferences a possibly-null return; add a null guard.
impact: displayName crashes with a TypeError whenever getUser returns null.
review_comment: the caller contract requires a null check before dereferencing.
suggested_fix: Restore the null guard before reading user.name.

severity: low
file: users.js
line: 1
issue: function name displayName should be getDisplayName for consistency.
impact: naming inconsistency with no behavioral effect.
review_comment: style-only churn is out of Logic scope.
suggested_fix: Consider renaming in a style pass, not in this review.
