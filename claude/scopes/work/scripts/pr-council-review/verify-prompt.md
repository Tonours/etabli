{{VERIFY_SKILL}} {{PR_NUMBER}} {{REPO}}

This run is unattended: nobody answers questions, so the skill withholds its own approval offer.
Run the skill to the end, then judge the pull request as its reviewer, on what you verified.
An empty finding set is legitimate here when the earlier review raised nothing: report reviewed=0.

You are confident only if all of these hold: every finding is settled with evidence you
executed or read, not on the author's word; the commits since {{SINCE_SHORT}} add no risk you can
name; nothing you saw makes you hesitate to merge. Any doubt means not confident.

End your final message with exactly these two lines, nothing after them:
VERIFY_VERDICT reviewed=<n> reopened=<n> regressions=<n> complete=<true|false> confident=<true|false>
CONFIDENCE <one sentence: why you would or would not approve this pull request now>
