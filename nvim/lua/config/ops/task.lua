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

local function list_items(items)
  if not items or #items == 0 then
    return {}
  end

  local result = {}
  for _, item in ipairs(items) do
    if item ~= "none" then
      table.insert(result, item)
    end
  end
  return result
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

local function identity_source(worktree)
  if branch_name(worktree) then
    return "branch"
  end
  if worktree and worktree.tail and worktree.tail ~= "" then
    return "worktree"
  end
  return "cwd"
end

local function sanitize_id(value)
  local normalized = (value or ""):gsub("[^A-Za-z0-9%._%-]+", "-")
  normalized = normalized:gsub("%-+", "-")
  normalized = normalized:gsub("^%-", "")
  normalized = normalized:gsub("%-$", "")
  return normalized
end

local function title_source(root, plan, worktree)
  if plan.subject and plan.subject ~= "" then
    return "plan-subject"
  end

  if branch_name(worktree) then
    return "branch"
  end

  if worktree and worktree.tail and worktree.tail ~= "" then
    return "worktree"
  end

  return "repo"
end

local function task_title(root, plan, worktree, source)
  local resolved = source or title_source(root, plan, worktree)
  if resolved == "plan-subject" then
    return plan.subject
  end
  if resolved == "branch" then
    return branch_name(worktree)
  end
  if resolved == "worktree" then
    return worktree.tail
  end
  return basename(root)
end

local function task_id(repo_name, root, worktree, source)
  local resolved = source or identity_source(worktree)
  local suffix = ""

  if resolved == "branch" then
    suffix = sanitize_id(branch_name(worktree))
  elseif resolved == "worktree" then
    suffix = sanitize_id(worktree and worktree.tail or "")
  else
    suffix = state.status_file_name(root)
  end

  if suffix == "" then
    return repo_name .. ":" .. state.status_file_name(root)
  end
  return repo_name .. ":" .. suffix
end

local function lifecycle_state(plan, review, runtime)
  if not plan.exists or plan.status == "DRAFT" or plan.status == "CHALLENGED" then
    return "planning"
  end
  if review.actionable and review.actionable > 0 then
    return "blocked-review"
  end
  if first_item(plan.tracking["Pending checks"]) ~= nil then
    return "awaiting-checks"
  end
  if runtime.phase == "running" then
    return "running"
  end
  if first_item(plan.tracking["Active slice"]) ~= nil then
    return "implementing"
  end
  if plan.status == "READY" then
    return "ready"
  end
  return "idle"
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
  local task_identity_source = identity_source(worktree)
  local task_title_source = title_source(root, plan, worktree)

  return {
    taskId = task_id(repo_name, root, worktree, task_identity_source),
    title = task_title(root, plan, worktree, task_title_source),
    repo = repo_name,
    worktreePath = root,
    branch = to_json_value(branch_name(worktree)),
    identitySource = task_identity_source,
    titleSource = task_title_source,
    lifecycleState = lifecycle_state(plan, review, runtime),
    mode = mode_state.mode,
    planStatus = to_json_value(plan.status),
    runtimePhase = to_json_value(runtime.phase),
    reviewSummary = review.line or "review unavailable",
    nextAction = next_action.value or "no actionable OPS state",
    activeSlice = to_json_value(first_item(plan.tracking["Active slice"])),
    completedSlices = list_items(plan.tracking["Completed slices"]),
    pendingChecks = list_items(plan.tracking["Pending checks"]),
    lastValidatedState = to_json_value(first_item(plan.tracking["Last validated state"])),
    revision = to_json_value(inputs and inputs.revision or nil),
    updatedAt = (inputs and inputs.updated_at) or now_iso(),
  }
end

local function strip_metadata(task_state)
  local copy = vim.deepcopy(task_state)
  copy.updatedAt = nil
  copy.revision = nil
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

function M.read(cwd)
  return read_existing(M.path(cwd))
end

function M.same(left, right)
  return vim.deep_equal(strip_metadata(left), strip_metadata(right))
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

  if previous and M.same(previous, task_state) then
    return previous, false
  end

  local previous_revision = previous and type(previous.revision) == "number" and previous.revision or 0
  task_state.updatedAt = type(task_state.updatedAt) == "string" and task_state.updatedAt or now_iso()
  task_state.revision = type(task_state.revision) == "number" and task_state.revision or (previous_revision + 1)
  write_atomic(path, vim.split(vim.json.encode(task_state), "\n", { plain = true }))
  return task_state, true
end

return M
