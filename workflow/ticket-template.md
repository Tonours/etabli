# Ticket Template

One ticket = one behavior = one PR. If you hesitate between two things, write two tickets.

---

## As a [role], I want [action] so that [benefit]

### Context
- **Files**: `path/to/file.ts`, `path/to/other.ts`
- **Existing pattern**: [brief description or link to reference implementation]
- **Dependencies**: [what must be in place first]

### Rules
- [constraint 1]
- [constraint 2]
- Do NOT: [anti-pattern to avoid]

### Examples

**Input**: [concrete data or scenario]  
**Expected output**: [concrete result or behavior]

### Acceptance criteria
- [ ] [verifiable predicate 1]
- [ ] [verifiable predicate 2]
- [ ] Validation: `bun test path/to/test`

### Done
- [ ] Code implemented
- [ ] Tests passing
- [ ] No regression on `bun test`

---

## Writing guidelines

1. **Atomic** — one ticket delivers one user-facing behavior. Split aggressively.
2. **Embedded context** — put files, patterns, and dependencies directly in the ticket. No "see wiki" or "refer to doc X".
3. **Concrete examples** — one input/output pair eliminates 90% of ambiguity for both humans and LLMs.
4. **Verifiable predicates** — every acceptance criterion is answerable with yes/no or pass/fail.
5. **Bounded scope** — if you can't list the likely files, the ticket is too broad.
6. **No prose padding** — every line carries information. Remove anything that doesn't.
