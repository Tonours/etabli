local M = {}

local statuses = {
  "new",
  "accepted",
  "needs-rework",
  "question",
  "ignore",
}

local labels = {
  ["needs-rework"] = "REWORK",
  question = "QUESTION",
  new = "NEW",
  accepted = "ACCEPT",
  ignore = "IGNORE",
}

local highlights = {
  ["needs-rework"] = "DiagnosticError",
  question = "DiagnosticWarn",
  new = "DiagnosticInfo",
  accepted = "DiagnosticOk",
  ignore = "Comment",
}

local priority = {
  ["needs-rework"] = 1,
  question = 2,
  new = 3,
  accepted = 4,
  ignore = 5,
}

local actionable = {
  ["needs-rework"] = true,
  question = true,
}

function M.statuses()
  return vim.deepcopy(statuses)
end

function M.is_valid_status(status)
  return vim.tbl_contains(statuses, status)
end

function M.label(status)
  return labels[status or "new"] or string.upper(status or "new")
end

function M.highlight(status)
  return highlights[status or "new"] or "Normal"
end

function M.priority(status)
  return priority[status or "new"] or 99
end

function M.is_actionable(status)
  return actionable[status or "new"] == true
end

function M.actionable_count(counts)
  return (counts["needs-rework"] or 0) + (counts.question or 0)
end

function M.actionable_summary(counts, source)
  local suffix = source and (" (" .. source .. ")") or ""
  if M.actionable_count(counts) > 0 then
    return string.format("needs-rework %d | question %d%s", counts["needs-rework"] or 0, counts.question or 0, suffix)
  end

  return source and ("clear (" .. source .. ")") or "clear"
end

return M
