local util = require("config.review.util")

local M = {}

local function comment_range_label(comment)
  local line = tonumber(comment.line)
  local end_line = tonumber(comment.end_line) or line

  if line and end_line and end_line ~= line then
    return string.format("lines %d-%d", line, end_line)
  end

  return string.format("line %s", line or "?")
end

local function append_comment_body(lines, body)
  local body_lines = vim.split(body or "", "\n", { plain = true })

  for _, body_line in ipairs(body_lines) do
    table.insert(lines, string.format("    %s", body_line))
  end
end

local function append_multiline_field(lines, label, value)
  if not value or value == "" then
    return
  end

  table.insert(lines, label .. ":")
  append_comment_body(lines, value)
end

local function append_repo_context(lines, item)
  if item.repo and item.repo ~= "" then
    table.insert(lines, string.format("- Repo: %s", item.repo))
  end

  if item.branch and item.branch ~= "" then
    table.insert(lines, string.format("- Branch: %s", item.branch))
  end
end

local function append_review_comments(lines, item)
  local comments = item.comments or {}
  if vim.tbl_isempty(comments) then
    return
  end

  table.insert(lines, "- Existing review comments:")
  for _, comment in ipairs(comments) do
    table.insert(
      lines,
      string.format(
        "  - %s %s [%s]:",
        comment.id or "?",
        comment_range_label(comment),
        comment.resolved and "resolved" or "unresolved"
      )
    )
    append_comment_body(lines, comment.body)
  end
end

local function action_instructions(action)
  if action == "explain" then
    return {
      "Explain what this hunk changes, why it may exist, and any risks or follow-up questions.",
      "Stay focused on this hunk only.",
    }
  end

  if action == "review" then
    return {
      "Perform a first-pass code review of this hunk.",
      "Do not edit files or apply fixes during this pass.",
      "Use bounded read-only inspection of nearby code, tests, or config only when it materially confirms or rejects a suspected finding.",
      "Do not run broad scans, install dependencies, or perform slow validation unless the user explicitly asked for it.",
      "Use this review stack: self-check the diff, check scope/plan consistency when context is present, then run an adversarial review for edge cases and regressions.",
      "Prioritize correctness bugs, regressions, security issues, missing validation, missing tests, and maintainability risks that affect behavior.",
      "Treat existing review comments as reviewer context; do not duplicate resolved conversations unless the issue still exists.",
      "Ignore style nits unless they affect correctness or future maintenance.",
      "Only report findings grounded in the supplied diff. Verify every reported line or range exists in the supplied diff before you include it.",
      "Findings must come first. For each finding, use severity high|medium|low, file, line or range, why it matters, and the smallest concrete fix.",
      "For each finding, include review_comment: one concise inline-ready comment suitable for a GitHub-style review thread.",
      "Then add open questions or assumptions only when they change the decision.",
      "If you find no actionable issue, put exactly `No findings.` as the only finding, then still include the final verdict.",
      "If human arbitration is needed, include human_checkpoint: yes and the reason.",
      "End with exactly one verdict: GO, GO WITH NOTES, or BLOCK.",
    }
  end

  return {
    "Revise only this hunk.",
    "Apply the change directly in the workspace instead of only replying with a patch.",
    "Save every touched file before you stop.",
    "Do not change unrelated parts of the file.",
    "If you are blocked from editing, explain the blocker explicitly.",
  }
end

local function batch_action_instructions(action)
  if action == "explain" then
    return {
      "Explain each hunk separately.",
      "Call out risks, missing context, and follow-up questions per hunk.",
      "Keep the response grouped by hunk number and file path.",
    }
  end

  if action == "review" then
    return {
      "Perform a first-pass code review across the selected hunks.",
      "Do not edit files or apply fixes during this pass.",
      "Use bounded read-only inspection of nearby code, tests, or config only when it materially confirms or rejects a suspected finding.",
      "Do not run broad scans, install dependencies, or perform slow validation unless the user explicitly asked for it.",
      "Use this review stack: self-check the diff, check scope/plan consistency when context is present, run an adversarial review for edge cases and regressions, then trigger a human checkpoint only for accepted risk or ambiguous tradeoffs.",
      "Prioritize correctness bugs, regressions, security issues, missing validation, missing tests, and maintainability risks that affect behavior.",
      "Check whether changes across hunks are semantically consistent; call out missing paired edits when one hunk implies another should exist.",
      "Treat existing review comments as reviewer context; do not duplicate resolved conversations unless the issue still exists.",
      "Ignore style nits unless they affect correctness or future maintenance.",
      "Only report findings grounded in the supplied hunks. Verify every reported line or range exists in the supplied diff before you include it.",
      "Findings must come first, grouped by severity. For each finding, include severity high|medium|low, file, hunk number, line or range if inferable, why it matters, and the smallest concrete fix.",
      "For each finding, include review_comment: one concise inline-ready comment suitable for a GitHub-style review thread.",
      "Then add open questions or assumptions only when they change the decision.",
      "If you find no actionable issue, put exactly `No findings.` as the only finding, then still include the final verdict.",
      "If human arbitration is needed, include human_checkpoint: yes and the reason.",
      "End with exactly one verdict: GO, GO WITH NOTES, or BLOCK.",
    }
  end

  return {
    "Revise each hunk separately.",
    "Apply the changes directly in the workspace instead of only replying with patches.",
    "Save every touched file before you stop.",
    "Do not change unrelated parts of the file.",
    "If you are blocked from editing, explain the blocker explicitly per affected hunk.",
  }
end

local function append_hunk(lines, item, index)
  -- Build hunk lines in a temporary table for batch insertion
  local hunk_lines = {
    string.format("Hunk %d:", index),
  }
  append_repo_context(hunk_lines, item)
  vim.list_extend(hunk_lines, {
    string.format("- File: %s", item.path),
    string.format("- Scope: %s", item.scope),
    string.format("- Hunk: %s", item.hunk_header),
    string.format("- Current review status: %s", item.status or "new"),
  })

  if item.stale then
    table.insert(hunk_lines, "- Warning: this stored review entry is stale relative to the current diff")
  end

  if item.note and item.note ~= "" then
    append_multiline_field(hunk_lines, "- Reviewer note", item.note)
  end

  append_review_comments(hunk_lines, item)

  table.insert(hunk_lines, "- Diff:")
  util.append_fenced_block(hunk_lines, "diff", item.patch)

  -- Batch extend main lines table
  vim.list_extend(lines, hunk_lines)
end

function M.build(item, opts)
  local options = opts or {}
  local provider = options.provider or "LLM"
  local action = options.action or "revise"

  -- Build lines efficiently with pre-allocation
  local lines = {
    string.format("You are preparing a %s request for %s.", action, provider),
    action == "review" and "Review only the diff hunk below." or "Focus only on the diff hunk below.",
    "",
    "Context:",
  }
  append_repo_context(lines, item)
  vim.list_extend(lines, {
    string.format("- File: %s", item.path),
    string.format("- Scope: %s", item.scope),
    string.format("- Hunk: %s", item.hunk_header),
    string.format("- Current review status: %s", item.status or "new"),
  })

  if item.stale then
    table.insert(lines, "- Warning: this stored review entry is stale relative to the current diff")
  end

  if item.note and item.note ~= "" then
    append_multiline_field(lines, "- Reviewer note", item.note)
  end

  append_review_comments(lines, item)

  vim.list_extend(lines, { "", "Task:" })

  local instructions = action_instructions(action)
  for _, instruction in ipairs(instructions) do
    table.insert(lines, string.format("- %s", instruction))
  end

  vim.list_extend(lines, { "", "Diff hunk:" })
  util.append_fenced_block(lines, "diff", item.patch)

  return table.concat(lines, "\n")
end

function M.build_batch(items, opts)
  local options = opts or {}
  local provider = options.provider or "LLM"
  local action = options.action or "revise"
  local selection_label = options.selection_label or (options.status and string.format("review status: %s", options.status))

  -- Build lines efficiently with pre-allocation
  local lines = {
    string.format("You are preparing a %s request for %s.", action, provider),
    action == "review"
        and string.format("Review the %d diff hunks below as one local changeset.", #items)
      or string.format("Work through the %d diff hunks below one by one.", #items),
    action == "review" and "Do not invent findings outside the provided hunks; put context gaps in open questions or assumptions, not findings."
      or "Do not invent changes outside the provided hunks.",
    "",
    "Batch context:",
    string.format("- Hunk count: %d", #items),
  }

  if selection_label then
    table.insert(lines, string.format("- Selection: %s", selection_label))
  end

  vim.list_extend(lines, { "", "Task:" })

  local instructions = batch_action_instructions(action)
  for _, instruction in ipairs(instructions) do
    table.insert(lines, string.format("- %s", instruction))
  end

  for index, item in ipairs(items) do
    table.insert(lines, "")
    append_hunk(lines, item, index)
  end

  return table.concat(lines, "\n")
end

return M
