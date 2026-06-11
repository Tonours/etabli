# Review UI/UX Research

Date: 2026-06-06

## Scope

This research focuses on improving Etabli's Neovim review Inbox, inline comments, and Pi/Claude first-pass review flow while preserving terminal-native speed.

The target is not to copy a web pull-request UI. The useful patterns are review state, navigation, evidence, batch submission, and attention management adapted to a dense keyboard-first TUI.

## Source Map

- GitHub pull request comments: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/commenting-on-a-pull-request
- GitHub files changed comments panel, 2026 changelog: https://github.blog/changelog/2026-02-19-access-all-pull-request-comments-without-leaving-the-new-files-changed-page/
- GitHub viewed files: https://github.blog/news-insights/product-news/mark-files-as-viewed/
- GitHub PR accessibility guide: https://accessibility.github.com/documentation/guide/pull-requests/
- GitLab merge request reviews: https://docs.gitlab.com/user/project/merge_requests/reviews/
- Bitbucket pull request code review: https://support.atlassian.com/bitbucket-cloud/docs/review-code-in-a-pull-request/
- JetBrains IDE pull request review: https://www.jetbrains.com/help/idea/work-with-github-pull-requests.html
- Gerrit attention set: https://gerrit-review.googlesource.com/Documentation/user-attention-set.html
- Reviewable docs: https://docs.reviewable.io/
- Review Board: https://www.reviewboard.org/
- Graphite PR review: https://graphite.com/docs/review-pull-requests
- Phabricator Differential inline comments: https://secure.phabricator.com/book/phabricator/article/differential_inlines/
- CodeRabbit review and Change Stack: https://docs.coderabbit.ai/pr-reviews/coderabbit-review
- CodeRabbit review overview: https://docs.coderabbit.ai/guides/code-review-overview/
- Claude Code Review docs: https://code.claude.com/docs/en/code-review
- Claude Code Review announcement: https://claude.com/blog/code-review
- tuicr terminal review UI: https://tuicr.dev/
- CorgReview local AI-code review: https://corgreview.com/
- gh-review.nvim overview: https://neovimcraft.com/plugin/gh-tui-tools/gh-review.nvim/
- Code suggestions study: https://arxiv.org/abs/2502.04835
- AI review impact study: https://arxiv.org/abs/2508.18771
- Agentic AI-authored code review study: https://arxiv.org/abs/2601.19287

## Patterns Worth Keeping

### 1. Review is a transaction, not only comments

GitHub, GitLab, Bitbucket, and Phabricator all separate immediate comments from a review batch. The strongest pattern is a draft review transaction: collect inline comments, preview them, then submit with a verdict.

Etabli should treat comments and agent findings as draftable review objects until the user explicitly exports, resolves, accepts, or reruns.

### 2. The Inbox needs attention, not only status

Gerrit's attention set and Graphite's review queue point at the same problem: reviewers need to know what requires action now. A flat hunk list is insufficient once comments, stale hunks, agent findings, and human notes coexist.

Etabli should add an "attention" layer on top of existing statuses:

- `needs-human`: unresolved human comment or question
- `needs-agent-check`: hunk changed after a prior agent review
- `needs-recheck`: stale actionable comment exists
- `ready-to-accept`: comments resolved and no blocking agent finding
- `muted`: ignored or accepted and unchanged

### 3. Inline comments need a compact and expanded mode

GitHub and JetBrains expose comments at the line/range, but large reviews become noisy. JetBrains also exposes comments in editor gutters and lets users collapse/open them. In a TUI, always-expanded virtual lines will become expensive and visually heavy.

Etabli should render a compact marker by default and expand only the active thread or current file context.

### 4. File and hunk progress matters

GitHub and Bitbucket both use viewed/reviewed state, and GitHub resets that state when a file changes. Reviewable tracks which revision was reviewed so new revisions do not hide work.

Etabli should track hunk/file reviewed state by diff signature. If the signature changes, mark the item as changed since review.

### 5. Comments should be reachable from one place

GitHub's 2026 Files Changed update explicitly addresses the cost of switching between conversation and diff views. Bitbucket has a comments dropdown divided by unresolved/resolved/outdated. Graphite has a right-side timeline and file tree.

Etabli's Inbox should become the central comment navigation surface:

- unresolved first
- resolved collapsed
- stale/outdated labeled
- agent findings grouped separately but navigable like comments
- jump from any comment/finding to file and range

### 6. Agent review output needs severity, confidence, and evidence

Claude Code Review uses parallel agents, verifies findings, ranks severity, and emits an overview plus inline comments. CodeRabbit uses severity levels. Recent research on AI review actions found concise, hunk-level, manually triggered comments with code snippets are more likely to lead to code changes.

Etabli should force Pi/Claude review findings into a schema:

- provider: `pi` or `claude`
- severity: `critical`, `major`, `minor`, `info`
- confidence: `high`, `medium`, `low`
- file/range
- evidence
- suggested fix, optional
- status: `new`, `accepted`, `rejected`, `resolved`, `stale`

### 7. Suggestions are useful but costly

GitHub, GitLab, and Bitbucket all support suggested changes. A 2025 empirical study found suggestions are actionable and can improve merge outcomes, but can increase resolution time. For Etabli, suggestions should be second-phase: first capture high-quality findings, then add suggestion blocks with preview/apply.

### 8. TUI-native tools converge on exportable structured feedback

tuicr and CorgReview both emphasize local/terminal review with structured markdown that can be submitted to GitHub or handed to an agent. This aligns strongly with Etabli's Pi/Claude flow.

Etabli should keep export as a first-class action:

- export selected comments as markdown
- export selected hunks and comments to Pi/Claude
- export agent findings back into review state
- optionally emit JSON later for reliable ingestion

## Recommended Etabli Direction

### Inbox IA

Keep the Telescope picker, but make the visible model more review-oriented:

```text
ATTN  SCOPE    STATUS        COMMENTS  AGENT  REVIEWED  FILE:LINE
!     WORKING  needs-rework  2 open    C:1    changed   nvim/lua/...
?     STAGED   question      1 open    -      viewed    pi/extensions/...
      WORKING  accepted      none      P:ok   viewed    docs/...
```

Recommended filters:

- `attention`
- `unresolved`
- `agent`
- `stale`
- `changed-since-review`
- `needs-rework`
- `question`
- `current-file`
- `reviewed:false`

Recommended sorts:

- attention first
- file order
- status/severity
- recent activity
- provider finding severity

### Inbox Preview

The preview should be structured for decision speed:

1. metadata row: repo, branch, scope, status, file/range
2. attention reason
3. unresolved human comments
4. unresolved agent findings
5. compact diff
6. available actions

The preview should not start with raw diff when there is an unresolved comment or agent finding. The decision context comes first.

### Inline Comments

Default render:

```text
R  review: 2 unresolved, 1 agent finding  [open: <leader>ro]
```

Expanded render at cursor:

```text
| review #12 lines 44-51 unresolved
| major · claude · high confidence
| This cache can return stale branch state after checkout...
| actions: reply resolve reject open-in-inbox
```

Recommended behavior:

- compact by default
- expand current thread under cursor
- expand all comments in current hunk on command
- never render unlimited virtual lines
- truncate long comments with an explicit continuation action
- show status by text and sign, not color alone

### Comment Composer

Current multiline support is the right base. Add a small metadata header before body entry:

```text
Type: issue | question | suggestion | note
Severity: critical | major | minor | info
Range: file.lua:44-51
Draft: yes
```

This improves downstream agent prompts because feedback is typed at creation time.

### Review Transaction

Add a local pending review layer:

- `:ReviewStart`
- add comments and agent findings into pending state
- `:ReviewPreview`
- `:ReviewSubmit comment|approve|request-changes`
- `:ReviewExport markdown|json`

This maps GitHub/GitLab/Phabricator's draft review model to local Neovim.

### Pi/Claude Review Flow

Treat each review run as a first-class object:

```text
provider: claude
mode: review
scope: all | selected | status:needs-rework
prompt_hash: ...
diff_signature: ...
started_at: ...
completed_at: ...
result: pending | running | done | failed
findings: [...]
```

Inbox additions:

- show `P:n` and `C:n` counts for Pi/Claude findings
- show stale agent findings when the hunk changes
- let the user compare Pi vs Claude findings on the same hunk
- allow `accept finding`, `reject finding`, `convert to comment`, `resolve`

Important constraint: keep Claude interactive. Do not move back to `claude -p` for this flow.

### Performance Budget

Recommended budgets:

- Inbox warm open: under 50 ms for common repos
- Inbox cold open: under 200 ms for medium diffs
- Annotation refresh warm: under 2 ms for visible buffers
- Agent finding ingestion: O(number of findings), not O(number of files)
- No Git calls while moving cursor line-by-line
- No unlimited virtual-line rendering

Implementation constraints:

- cache by diff signature and branch hash
- invalidate on shell command, write, checkout, focus, and explicit refresh
- compute comments/finding counts in state layer, not render layer
- lazy-render expanded thread content only for visible/current buffers
- cap preview diff lines in picker, with explicit open-full-diff action

## Proposed Roadmap

### Phase 1: Inbox Attention Model

- Add reviewed/changed-since-review state.
- Add attention reason computation.
- Add filters and sort modes.
- Put comments and agent findings before diff in preview.
- Add persistent review cursor.

### Phase 2: Inline Thread UX

- Add compact/expanded inline modes.
- Add current-thread expansion.
- Add typed comment metadata.
- Add resolved/stale/outdated labels inline.
- Add explicit actions for reply, resolve, reject, open in Inbox.

### Phase 3: Agent Review Integration

- Persist Pi/Claude review run records.
- Parse agent output into structured findings.
- Show provider counts in Inbox.
- Add compare Pi/Claude action.
- Add rerun selected/changed-only review.

### Phase 4: Suggested Changes

- Add suggestion block support in comments/findings.
- Preview patch before apply.
- Apply only inside the original hunk/range unless explicitly expanded.
- Track suggestion applied/rejected/resolved.

## Non-Goals

- Do not build a full PR hosting clone.
- Do not make the Inbox visually decorative.
- Do not render every comment fully inline all the time.
- Do not make agent output auto-authoritative.
- Do not add always-on background agent runs without explicit cost and state visibility.

## Open Questions

- Should `reviewed` apply at file level, hunk level, or both?
- Should agent findings be stored as comments, or as a separate finding type with optional conversion to comment?
- Should Pi and Claude findings share a normalized severity taxonomy, or preserve provider-native labels and map them for display?
- Should `:ReviewSubmit` target local markdown only, or eventually GitHub PR reviews via `gh`?

## 2026-06-09 Addendum: Minimal TUI Direction

### Additional sources

- OpenCode TUI: https://opencode.ai/docs/tui/
- OpenCode keybinds: https://opencode.ai/docs/keybinds/
- OpenCode TUI config: https://opencode.ai/docs/config/
- OpenCode agents: https://opencode.ai/docs/agents/
- OpenTUI: https://github.com/anomalyco/opentui
- Hunk: https://github.com/modem-dev/hunk
- Warp terminal/agent modes: https://docs.warp.dev/agent-platform/local-agents/interacting-with-agents/terminal-and-agent-modes/
- Warp AI-generated code review workflow: https://docs.warp.dev/guides/agent-workflows/how-to-review-ai-generated-code/
- Lip Gloss terminal styling: https://github.com/charmbracelet/lipgloss

### Facts verified

- OpenCode's terminal surface is the primary interaction surface: running `opencode`
  starts a TUI for the current project, while CLI commands remain available for
  automation.
- OpenCode exposes TUI configuration separately through `tui.json`, including
  keybinds, scrolling, diff style, mouse, and attention notifications. This
  supports a strong split between behavior and terminal presentation.
- OpenCode agents separate planning/review work from build work: the Plan agent
  is explicitly positioned for analyzing code and reviewing suggestions without
  modifying files.
- OpenTUI, which powers OpenCode, emphasizes correctness, stability, high
  performance, componentized layout, and flexible terminal layouts.
- Hunk is explicitly review-first: multi-file stream, sidebar navigation, inline
  AI/agent annotations beside code, split/stack/auto layouts, watch mode, and
  keyboard/mouse support.
- GitHub's PR review model keeps line/range comments, pending review batches,
  and multi-line suggestions close to the diff. Existing Etabli multiline
  comment support already matches the most important primitive.
- Warp's agent UX separates a clean terminal mode from a richer agent
  conversation mode, with contextual hints rather than permanently visible
  controls.
- Mobbin MCP was not available in the current Codex tool surface during this
  pass. Research confidence therefore comes from primary docs and local code
  inspection, not Mobbin screenshots.

### Moodboard

Generated visual reference: local moodboard image, intentionally not tracked
with a user-specific filesystem path.

Direction extracted from the moodboard: graphite terminal surface, thin borders,
high-density split panes, status text before color, restrained semantic accents,
agent indicators as small evidence tags, and inline comment threads rendered as
review objects rather than chat bubbles.

### Local UX findings

- The review Inbox already has the right data model for a compact review queue:
  attention marker, scope, status, activity, reviewed state, location, preview,
  and actions. The weakness is wording: `attn`, `chg`, `old`, `idx`, `work`,
  `C:1`, and `P:1` are dense but not self-explanatory.
- The picker preview puts decision context before the diff, which is correct,
  but the first lines read as implementation metadata rather than review state.
- Inline annotations are already compact by default and expanded on demand. The
  weak point is the label `review:` plus raw counts, which does not read like a
  GitHub-style review thread.
- Agent terminals are interactive and prompt-pasted, which preserves the desired
  Claude/Pi behavior. The floating border is visually heavier than the rest of
  the TUI.
- Comment composers are functional and persistent through `:write`, `<C-s>`,
  `ZZ`, and `ZQ`. The rounded border and centered long title feel less aligned
  with the thinner OpenCode/Hunk direction, but changing the editor model would
  be higher risk than changing presentation.

### Implementation plan for this pass

- Make Inbox labels clearer while staying dense: replace ambiguous abbreviations
  with short review terms (`index`, `tree`, `stale`, `changed`, `reviewed`,
  `cN`, `note`, `claudeN`, `piN`) and update picker titles.
- Improve preview hierarchy without adding new state: use `State`, `Activity`,
  `Note`, `Draft comments`, `Open comments`, `Agent findings`, and `Diff`
  sections.
- Make inline annotations read like review threads: compact label should say
  `review thread` with comment/agent/draft counts and the open action.
- Use thinner `single` float borders for review agent terminals and Hunk comment
  editors to align with terminal-native minimalism.
- Preserve every existing command, keymap, persistence path, provider flow,
  Hunk sync behavior, multiline behavior, and performance cap.
