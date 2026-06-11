# Review verdicts for AdonisJS 7

Use these verdict levels to make the review act like a safety harness.

## PASS

Use when:

- the change is idiomatic enough,
- native modules are used correctly,
- no meaningful framework drift is introduced,
- remaining comments are minor.

## PASS WITH FIXES

Use when:

- the change is directionally correct,
- the framework structure is mostly intact,
- there are important corrections to make before relying on it heavily,
- the issues are localized and easy to remediate.

## BLOCK

Use when:

- the change introduces clear framework drift,
- native Adonis modules are bypassed without strong reason,
- validation/auth/config/response stability is unsafe,
- the resulting code will be costly to maintain or normalize later.

## Writing rule

Do not hide behind vague wording. Pick one verdict.
State the exact reason for the verdict in AdonisJS terms.
