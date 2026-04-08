local agent_layout = require("config.ops.agent_layout")
local mode = require("config.ops.mode")
local snapshot = require("config.ops.snapshot")
local state = require("config.ops.state")
local task = require("config.ops.task")

local M = {}

local function first_value(items)
  if not items or #items == 0 then
    return "none"
  end
  return items[1]
end

local function join_values(items)
  if not items or #items == 0 then
    return "none"
  end
  return table.concat(items, " | ")
end

local function truncate(text, max_len)
  if #text <= max_len then
    return text
  end
  return text:sub(1, max_len - 1) .. "…"
end

local function plan_label(plan)
  if not plan.exists then
    return "missing"
  end
  return plan.status or "invalid"
end

local function runtime_label(runtime)
  if not runtime.exists then
    return "unavailable"
  end

  local parts = { runtime.phase or "invalid" }
  if runtime.tool and runtime.tool ~= "" then
    table.insert(parts, runtime.tool)
  end
  if runtime.model and runtime.model ~= "" then
    table.insert(parts, runtime.model)
  end

  return table.concat(parts, " · ")
end

local function handoff_label(handoff)
  if not handoff.available then
    return "none"
  end
  return handoff.kind
end

local function mode_label(mode_state)
  local value = mode_state.mode
  if not mode_state.explicit then
    value = value .. " (default)"
  end
  return value
end

local function mode_hint(mode_state)
  return string.format("%s · %s", mode_state.description.roles, mode_state.description.review)
end

local function task_label(task_state)
  return string.format("%s (%s)", task_state.title, task_state.taskId)
end

local function thread_label(threads_state)
  if not threads_state.activeThreadId then
    return "none"
  end

  for _, thread in ipairs(threads_state.threads or {}) do
    if thread.id == threads_state.activeThreadId then
      return string.format("%s [%s] %s", thread.title or thread.id, thread.provider, thread.status)
    end
  end

  return threads_state.activeThreadId
end

local function workspace_label(layout_state)
  local layout = layout_state or agent_layout.state()
  if not layout.enabled then
    return "disabled"
  end

  return string.format("enabled · tree=%s", layout.tree_side or "left")
end

local function agent_help_label(layout_state)
  if not layout_state.enabled then
    return "<leader>at to enable"
  end

  return "<leader>aT threads · <leader>aI diffs · <leader>ri focus"
end

local function agents_label(agents)
  if not agents.exists or agents.total == 0 then
    return "none"
  end

  local parts = {}
  if agents.running > 0 then
    table.insert(parts, string.format("%d running", agents.running))
  end
  if agents.waitingHuman > 0 then
    table.insert(parts, string.format("%d waiting-human", agents.waitingHuman))
  end
  if agents.failed > 0 then
    table.insert(parts, string.format("%d failed", agents.failed))
  end
  if #parts == 0 then
    return string.format("%d tracked", agents.total)
  end
  return table.concat(parts, " | ")
end

local function waiting_human_detail(agents)
  for _, item in ipairs(agents.items or {}) do
    if item.status == "waiting_human" then
      return item.question or item.task or "human input required", item.resumePrompt
    end
  end
  return nil, nil
end

local function optional_label(value)
  if value == nil or value == vim.NIL or value == "" then
    return "none"
  end
  return tostring(value)
end

local function append_prefixed_warnings(lines, prefix, warnings)
  for _, warning in ipairs(warnings or {}) do
    table.insert(lines, string.format("%s %s", prefix, warning))
  end
end

local function slice_label(plan)
  local active_slice = first_value(plan.tracking["Active slice"])
  if active_slice ~= "none" then
    return active_slice
  end
  if plan.planned_slice then
    return "planned → " .. plan.planned_slice
  end
  return "none"
end

function M.next_action(plan, review, runtime, handoff, agents)
  return snapshot.next_action_details(plan, review, runtime, handoff, agents).value
end

function M.info_lines(cwd)
  local lines = {}
  local plan = state.plan_state(cwd)
  local runtime = state.runtime_state(cwd)
  local review = state.review_summary(cwd)
  local agents = state.agents_state(cwd)
  local handoff = state.handoff_state(cwd)
  local mode_state = mode.read(cwd)
  local layout_state = agent_layout.state()
  local threads_state = state.threads_state(cwd)
  local task_state = task.project(cwd, {
    plan = plan,
    review = review,
    runtime = runtime,
    mode_state = mode_state,
    next_action = snapshot.next_action_details(plan, review, runtime, handoff, agents),
  })

  table.insert(lines, "Task:       " .. task_label(task_state))
  table.insert(lines, "State:      " .. task_state.lifecycleState)
  table.insert(lines, "OPS plan:   " .. plan_label(plan))
  table.insert(lines, "Mode:       " .. mode_label(mode_state))
  table.insert(lines, "Mode hint:  " .. mode_hint(mode_state))
  table.insert(lines, "Workspace:  " .. workspace_label(layout_state))
  table.insert(lines, "Agent keys: " .. agent_help_label(layout_state))
  table.insert(lines, "Thread:     " .. thread_label(threads_state))
  table.insert(lines, "Slice:      " .. slice_label(plan))
  table.insert(lines, "Completed:  " .. join_values(task_state.completedSlices))
  table.insert(lines, "Checks:     " .. join_values(task_state.pendingChecks))
  table.insert(lines, "Validated:  " .. optional_label(task_state.lastValidatedState))
  table.insert(lines, "Next:       " .. first_value(plan.tracking["Next recommended action"]))
  table.insert(lines, "Review:     " .. review.line)
  table.insert(lines, "Agents:     " .. agents_label(agents))
  local human_question = waiting_human_detail(agents)
  if human_question then
    table.insert(lines, "Human:      " .. human_question)
  end
  table.insert(lines, "Runtime:    " .. runtime_label(runtime))
  if runtime.updatedAt and runtime.updatedAt ~= "" then
    table.insert(lines, "Updated:    " .. runtime.updatedAt)
  end
  table.insert(lines, "Handoff:    " .. handoff_label(handoff))

  append_prefixed_warnings(lines, "Plan warn:  ", plan.warnings)
  append_prefixed_warnings(lines, "Runtime warn:", runtime.warnings)
  append_prefixed_warnings(lines, "Review warn:", review.warnings)
  append_prefixed_warnings(lines, "Agent warn: ", agents.warnings)
  append_prefixed_warnings(lines, "Mode warn:  ", mode_state.warnings)

  return lines
end

function M.project_info_lines(cwd)
  local info = M.info_lines(cwd)
  local lines = { "OPS:" }
  for _, line in ipairs(info) do
    table.insert(lines, "  " .. line)
  end
  return lines
end

function M.next_lines(cwd)
  local lines = { "OPS next:" }
  local plan = state.plan_state(cwd)
  local runtime = state.runtime_state(cwd)
  local review = state.review_summary(cwd)
  local agents = state.agents_state(cwd)
  local handoff = state.handoff_state(cwd)
  local mode_state = mode.read(cwd)
  local layout_state = agent_layout.state()
  local threads_state = state.threads_state(cwd)
  local task_state = task.project(cwd, {
    plan = plan,
    review = review,
    runtime = runtime,
    mode_state = mode_state,
    next_action = snapshot.next_action_details(plan, review, runtime, handoff, agents),
  })

  table.insert(lines, "Task:       " .. task_label(task_state))
  table.insert(lines, "State:      " .. task_state.lifecycleState)
  table.insert(lines, "Action:     " .. M.next_action(plan, review, runtime, handoff, agents))
  table.insert(lines, "Mode:       " .. mode_label(mode_state))
  table.insert(lines, "Mode hint:  " .. mode_hint(mode_state))
  table.insert(lines, "Workspace:  " .. workspace_label(layout_state))
  table.insert(lines, "Agent keys: " .. agent_help_label(layout_state))
  table.insert(lines, "Thread:     " .. thread_label(threads_state))
  table.insert(lines, "Plan:       " .. plan_label(plan))
  table.insert(lines, "Slice:      " .. slice_label(plan))
  table.insert(lines, "Checks:     " .. join_values(task_state.pendingChecks))
  table.insert(lines, "Validated:  " .. optional_label(task_state.lastValidatedState))
  table.insert(lines, "Plan next:  " .. first_value(plan.tracking["Next recommended action"]))
  table.insert(lines, "Review:     " .. review.line)
  table.insert(lines, "Agents:     " .. agents_label(agents))
  local human_question = waiting_human_detail(agents)
  if human_question then
    table.insert(lines, "Human:      " .. human_question)
  end
  table.insert(lines, "Runtime:    " .. runtime_label(runtime))
  table.insert(lines, "Handoff:    " .. handoff_label(handoff))

  append_prefixed_warnings(lines, "Plan warn:  ", plan.warnings)
  append_prefixed_warnings(lines, "Runtime warn:", runtime.warnings)
  append_prefixed_warnings(lines, "Review warn:", review.warnings)
  append_prefixed_warnings(lines, "Agent warn: ", agents.warnings)
  append_prefixed_warnings(lines, "Mode warn:  ", mode_state.warnings)

  return lines
end

local function session_line(session_state)
  if session_state == "loaded" then
    return "loaded"
  end
  if session_state == "blocked" then
    return "blocked by modified buffers"
  end
  if session_state == "cancelled" then
    return "cancelled"
  end
  return "none"
end

function M.resume_lines(cwd, session_state)
  local lines = { "OPS resume:" }
  local root = vim.fs.normalize(cwd or vim.fn.getcwd())
  local review = state.review_summary(root)
  local runtime = state.runtime_state(root)
  local agents = state.agents_state(root)
  local handoff = state.handoff_state(root)
  local mode_state = mode.read(root)
  local layout_state = agent_layout.state()
  local threads_state = state.threads_state(root)
  local plan = state.plan_state(root)
  local task_state = task.project(root, {
    plan = plan,
    review = review,
    runtime = runtime,
    mode_state = mode_state,
    next_action = snapshot.next_action_details(plan, review, runtime, handoff, agents),
  })

  table.insert(lines, "Session:    " .. session_line(session_state))
  table.insert(lines, "Task:       " .. task_label(task_state))
  table.insert(lines, "State:      " .. task_state.lifecycleState)
  table.insert(lines, "Mode:       " .. mode_label(mode_state))
  table.insert(lines, "Workspace:  " .. workspace_label(layout_state))
  table.insert(lines, "Agent keys: " .. agent_help_label(layout_state))
  table.insert(lines, "Thread:     " .. thread_label(threads_state))
  table.insert(lines, "Action:     " .. M.next_action(plan, review, runtime, handoff, agents))
  table.insert(lines, "Checks:     " .. join_values(task_state.pendingChecks))
  table.insert(lines, "Validated:  " .. optional_label(task_state.lastValidatedState))
  table.insert(lines, "Review:     " .. review.line)
  table.insert(lines, "Agents:     " .. agents_label(agents))
  local human_question = waiting_human_detail(agents)
  if human_question then
    table.insert(lines, "Human:      " .. human_question)
  end
  table.insert(lines, "Runtime:    " .. runtime_label(runtime))
  table.insert(lines, "Handoff:    " .. handoff_label(handoff))

  return lines
end

function M.agent_lines(cwd)
  local lines = { "OPS agents:" }
  local agents = state.agents_state(cwd)
  table.insert(lines, "Agents:     " .. agents_label(agents))
  for _, item in ipairs(agents.items or {}) do
    local suffix = item.question and (" | Q: " .. item.question) or ""
    table.insert(lines, string.format("#%d %-13s %-8s %s%s", item.id or 0, item.status or "unknown", item.role or "-", item.task or "", suffix))
  end
  append_prefixed_warnings(lines, "Agent warn: ", agents.warnings)
  return lines
end

function M.human_lines(cwd)
  local lines = { "OPS human checkpoint:" }
  local agents = state.agents_state(cwd)
  local question, resume_prompt = waiting_human_detail(agents)
  if not question then
    table.insert(lines, "State:      none")
    return lines
  end
  table.insert(lines, "State:      waiting_human")
  table.insert(lines, "Question:   " .. question)
  table.insert(lines, "Resume:     " .. (resume_prompt or "use subagent_continue with the human decision"))
  return lines
end

local function tilldone_label()
  local ok, tilldone = pcall(require, "config.ops.tilldone")
  if not ok then
    return nil
  end
  
  local status = tilldone.get_statusline()
  return status
end

function M.statusline_label()
  local plan = state.plan_state(vim.fn.getcwd())
  local runtime = state.runtime_state(vim.fn.getcwd())

  if not plan.exists and not runtime.exists then
    -- Still show TillDone if available
    local td = tilldone_label()
    if td then
      return td
    end
    return ""
  end

  local parts = { "OPS" }
  if plan.exists then
    table.insert(parts, plan_label(plan))
    local active = first_value(plan.tracking["Active slice"])
    if active ~= "none" then
      table.insert(parts, truncate(active, 18))
    end
  end
  if runtime.phase then
    table.insert(parts, runtime.phase)
  end
  
  -- Add TillDone info if available
  local td = tilldone_label()
  if td then
    table.insert(parts, "| " .. td)
  end

  return table.concat(parts, " · ")
end

function M.statusline_color()
  local plan = state.plan_state(vim.fn.getcwd())
  if not plan.exists or not plan.status then
    return { fg = "#6c7086" }
  end

  if plan.status == "READY" then
    return { fg = "#a6e3a1" }
  end
  if plan.status == "CHALLENGED" then
    return { fg = "#f9e2af" }
  end
  return { fg = "#f38ba8" }
end

return M
