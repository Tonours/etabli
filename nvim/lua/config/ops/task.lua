local mode = require("config.ops.mode")
local state = require("config.ops.state")
local review_diff = require("config.review.diff")
local worktrees = require("config.worktrees")

local M = {}

local uv = vim.uv or vim.loop
local JSON_NULL = vim.NIL

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%S.000Z")
end

local function basename(path)
  return vim.fs.basename(vim.fs.normalize(path))
end

local function ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

local function first_item(items)
  if not items or #items == 0 then
    return nil
  end
  local value = items[1]
  if value == "none" then
    return nil
  end
  return value
end

local function to_json_value(value)
  if value == nil then
    return JSON_NULL
  end
  return value
end

local function branch_name(worktree)
  if not worktree or not worktree.branch or worktree.branch == "" then
    return nil
  end
  return worktree.branch
end

local function sanitize_id(value)
  local normalized = (value or ""):gsub("[^A-Za-z0-9%._%-]+", "-")
  normalized = normalized:gsub("%-+", "-")
  normalized = normalized:gsub("^%-", "")
  normalized = normalized:gsub("%-$", "")
  return normalized
end

local function task_title(root, plan, worktree)
  if plan.subject and plan.subject ~= "" then
    return plan.subject
  end

  local branch = branch_name(worktree)
  if branch then
    return branch
  end

  if worktree and worktree.tail and worktree.tail ~= "" then
    return worktree.tail
  end

  return basename(root)
end

local function task_id(repo_name, root, worktree)
  local suffix = sanitize_id(branch_name(worktree) or (worktree and worktree.tail) or basename(root))
  if suffix == "" then
    return repo_name .. ":" .. state.status_file_name(root)
  end
  return repo_name .. ":" .. suffix
end

function M.path(cwd)
  local root = vim.fs.normalize(cwd or vim.fn.getcwd())
  return vim.fn.expand("~/.pi/status/" .. state.status_file_name(root) .. ".task.json")
end

function M.project(cwd, inputs)
  local root = vim.fs.normalize(cwd or vim.fn.getcwd())
  local plan = (inputs and inputs.plan) or state.plan_state(root)
  local review = (inputs and inputs.review) or state.review_summary(root)
  local runtime = (inputs and inputs.runtime) or state.runtime_state(root)
  local mode_state = (inputs and inputs.mode_state) or mode.read(root)
  local next_action = (inputs and inputs.next_action) or { value = "no actionable OPS state" }
  local worktree = (inputs and inputs.worktree) or worktrees.current(root)
  local repo_root = (inputs and inputs.repo_root) or review_diff.repo_root(root) or root
  local repo_name = basename(repo_root)

  return {
    taskId = task_id(repo_name, root, worktree),
    title = task_title(root, plan, worktree),
    repo = repo_name,
    worktreePath = root,
    branch = to_json_value(branch_name(worktree)),
    mode = mode_state.mode,
    planStatus = to_json_value(plan.status),
    runtimePhase = to_json_value(runtime.phase),
    reviewSummary = review.line or "review unavailable",
    nextAction = next_action.value or "no actionable OPS state",
    activeSlice = to_json_value(first_item(plan.tracking["Active slice"])),
    completedSlices = vim.deepcopy(plan.tracking["Completed slices"] or {}),
    pendingChecks = vim.deepcopy(plan.tracking["Pending checks"] or {}),
    updatedAt = (inputs and inputs.updated_at) or now_iso(),
  }
end

local function strip_metadata(task_state)
  local copy = vim.deepcopy(task_state)
  copy.updatedAt = nil
  return copy
end

local function read_existing(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

local function write_atomic(path, lines)
  ensure_dir(vim.fs.dirname(path))
  local tmp = string.format("%s.tmp.%d", path, uv.hrtime())
  vim.fn.writefile(lines, tmp)
  local ok, err = uv.fs_rename(tmp, path)
  if not ok then
    pcall(uv.fs_unlink, tmp)
    error(err or "failed to rename OPS task-state temp file")
  end
end

function M.write(cwd, payload)
  local root = vim.fs.normalize(cwd or vim.fn.getcwd())
  local path = M.path(root)
  local task_state = vim.deepcopy(payload or M.project(root))
  local previous = read_existing(path)

  if previous and vim.deep_equal(strip_metadata(previous), strip_metadata(task_state)) then
    return previous, false
  end

  task_state.updatedAt = now_iso()
  write_atomic(path, vim.split(vim.json.encode(task_state), "\n", { plain = true }))
  return task_state, true
end

return M
