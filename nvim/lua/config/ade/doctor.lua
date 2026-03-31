local mode = require("config.ade.mode")
local state = require("config.ade.state")

local M = {}

local function line(status, label, message)
  return string.format("%s %-8s %s", status, label .. ":", message)
end

local function first_warning(messages)
  if not messages or #messages == 0 then
    return nil
  end
  return messages[1]
end

function M.lines(cwd)
  local root = vim.fs.normalize(cwd or vim.fn.getcwd())
  local lines = { "ADE doctor:" }
  local projects = require("config.projects")
  local worktrees = require("config.worktrees")
  local review_diff = require("config.review.diff")
  local review_state = require("config.review.state")

  local repo = review_diff.repo_root(root)
  local worktree = worktrees.current(root)
  local plan = state.plan_state(root)
  local runtime = state.runtime_state(root)
  local review = state.review_summary(root)
  local handoff = state.handoff_state(root)
  local mode_state = mode.read(root)
  local session_exists = projects.session_exists(root)

  if repo then
    table.insert(lines, line("PASS", "repo", repo))
  else
    table.insert(lines, line("FAIL", "repo", "not inside a git repo"))
  end

  if worktree then
    table.insert(lines, line("PASS", "worktree", worktree.branch ~= "" and worktree.branch or worktree.tail))
  else
    table.insert(lines, line("WARN", "worktree", "no named worktree detected"))
  end

  if session_exists then
    table.insert(lines, line("PASS", "session", "saved session available"))
  else
    table.insert(lines, line("WARN", "session", "no saved session"))
  end

  if not plan.exists then
    table.insert(lines, line("FAIL", "plan", "PLAN.md missing"))
  elseif #plan.warnings > 0 then
    table.insert(lines, line("WARN", "plan", first_warning(plan.warnings)))
  else
    table.insert(lines, line("PASS", "plan", plan.status or "invalid"))
  end

  if not runtime.exists then
    table.insert(lines, line("WARN", "runtime", "runtime status unavailable"))
  elseif #runtime.warnings > 0 then
    table.insert(lines, line("WARN", "runtime", first_warning(runtime.warnings)))
  else
    table.insert(lines, line("PASS", "runtime", runtime.phase or "invalid"))
  end

  if repo then
    local context, err = review_state.context_for_repo(repo)
    if not context then
      table.insert(lines, line("WARN", "review", err or "review state unavailable"))
    elseif review.actionable > 0 then
      table.insert(lines, line("WARN", "review", review.line))
    else
      table.insert(lines, line("PASS", "review", review.line))
    end
  else
    table.insert(lines, line("WARN", "review", "no git repo"))
  end

  if handoff.available then
    table.insert(lines, line("PASS", "handoff", handoff.kind))
  else
    table.insert(lines, line("WARN", "handoff", "no handoff file"))
  end

  local mode_message = mode_state.mode
  if not mode_state.explicit then
    mode_message = mode_message .. " (default)"
  end
  mode_message = mode_message .. " · " .. mode_state.description.roles
  if #mode_state.warnings > 0 then
    table.insert(lines, line("WARN", "mode", mode_state.warnings[1]))
  else
    table.insert(lines, line("PASS", "mode", mode_message))
  end

  if mode_state.mode == "option-compare" and repo then
    local entries = worktrees.entries(root)
    if #entries < 2 then
      table.insert(lines, line("WARN", "mode", "option-compare expects isolated option worktrees"))
    end
  end

  return lines
end

return M
