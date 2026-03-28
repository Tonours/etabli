local M = {}

local function action_instructions(action)
  if action == "explain" then
    return {
      "Explain what this hunk changes, why it may exist, and any risks or follow-up questions.",
      "Stay focused on this hunk only.",
    }
  end

  return {
    "Revise only this hunk.",
    "Do not change unrelated parts of the file.",
    "Return a concrete patch or replacement snippet for this hunk.",
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

  return {
    "Revise each hunk separately.",
    "Do not change unrelated parts of the file.",
    "Return one concrete patch or replacement snippet per hunk, grouped by hunk number and file path.",
  }
end

local function append_hunk(lines, item, index)
  -- Build hunk lines in a temporary table for batch insertion
  local hunk_lines = {
    string.format("Hunk %d:", index),
    string.format("- File: %s", item.path),
    string.format("- Scope: %s", item.scope),
    string.format("- Hunk: %s", item.hunk_header),
    string.format("- Current review status: %s", item.status or "new"),
  }

  if item.stale then
    table.insert(hunk_lines, "- Warning: this stored review entry is stale relative to the current diff")
  end

  if item.note and item.note ~= "" then
    table.insert(hunk_lines, string.format("- Reviewer note: %s", item.note))
  end

  table.insert(hunk_lines, "- Diff:")
  table.insert(hunk_lines, "```diff")

  local patch_lines = vim.split(item.patch, "\n", { plain = true })
  vim.list_extend(hunk_lines, patch_lines)

  table.insert(hunk_lines, "```")

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
    "Focus only on the diff hunk below.",
    "",
    "Context:",
    string.format("- File: %s", item.path),
    string.format("- Scope: %s", item.scope),
    string.format("- Hunk: %s", item.hunk_header),
    string.format("- Current review status: %s", item.status or "new"),
  }

  if item.stale then
    table.insert(lines, "- Warning: this stored review entry is stale relative to the current diff")
  end

  if item.note and item.note ~= "" then
    table.insert(lines, string.format("- Reviewer note: %s", item.note))
  end

  vim.list_extend(lines, { "", "Task:" })

  local instructions = action_instructions(action)
  for _, instruction in ipairs(instructions) do
    table.insert(lines, string.format("- %s", instruction))
  end

  vim.list_extend(lines, { "", "Diff hunk:", "```diff" })

  local patch_lines = vim.split(item.patch, "\n", { plain = true })
  vim.list_extend(lines, patch_lines)

  table.insert(lines, "```")

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
    string.format("Work through the %d diff hunks below one by one.", #items),
    "Do not invent changes outside the provided hunks.",
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
