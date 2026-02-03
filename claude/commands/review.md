Read ./PLAN.md as a staff engineer conducting design review.

Context:

```bash
git diff --stat HEAD~5..HEAD 2>/dev/null || echo "No recent commits"
```

For each issue found:

- **Severity**: blocking / important / suggestion
- **Description**: Clear explanation of the concern
- **Recommended fix**: Specific, actionable

Focus areas:

- Logic gaps and missed edge cases
- Architectural concerns
- Performance implications
- Security vulnerabilities
- Regression risks
- Over-engineering (can it be simpler?)
- Missing verification steps

Write review to ./REVIEW.md
