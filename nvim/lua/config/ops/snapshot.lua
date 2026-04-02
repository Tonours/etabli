local mode = require("config.ops.mode")
local state = require("config.ops.state")
local task = require("config.ops.task")

local M = {}

local uv = vim.uv or vim.loop
local JSON_NULL = vim.NIL
local SNAPSHOT_KIND = "ops-snapshot"
local SNAPSHOT_VERSION = 1
local pending = {
  token = 0,
}

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%S.000Z")
end

local function ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

local function basename(path)
  return vim.fs.basename(vim.fs.normalize(path))
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

local function review_focus(review)
  local counts = review.counts or {}
  local parts = {}
  local needs_rework = counts["needs-rework"] or 0
  local questions = counts.question or 0

  if needs_rework > 0 then
    table.insert(parts, string.format("%d needs-rework", needs_rework))
  end
  if questions > 0 then
    table.insert(parts, string.format("%d question%s", questions, questions == 1 and "" or "s"))
  end
  if #parts == 0 and review.actionable and review.actionable > 0 then
    table.insert(parts, string.format("%d review item(s)", review.actionable))
  end

  return table.concat(parts, " / ")
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

local function plan_state_kind(plan)
  if not plan.exists then
    return "missing"
  end
  if plan.status == nil then
    return "invalid"
  end
  return "available"
end

local function runtime_state_kind(runtime)
  if not runtime.exists then
    return "missing"
  end
  if runtime.phase == nil then
    return "invalid"
  end
  return "available"
end

local function next_action_details(plan, review, runtime, handoff)
  local active_slice = first_item(plan.tracking["Active slice"])
  local pending_check = first_item(plan.tracking["Pending checks"])
  local last_validated = first_item(plan.tracking["Last validated state"])

  if not plan.exists then
    return {
      value = "create a plan",
      reason = "PLAN.md missing",
      derivedFrom = "plan",
    }
  end
  if plan.status == "DRAFT" or plan.status == "CHALLENGED" then
    return {
      value = "harden the plan",
      reason = "plan not ready",
      derivedFrom = "plan",
    }
  end
  if review.actionable > 0 then
    local focus = review_focus(review)
    local prefix = review.source ~= "live" and review.mayBeStale and "refresh review inbox and handle " or "handle "
    return {
      value = prefix .. focus,
      reason = review.source ~= "live" and review.mayBeStale and "stored review blockers may be stale" or "review blockers present",
      derivedFrom = "review",
    }
  end
  if runtime.phase == "running" then
    if pending_check then
      return {
        value = "worker active — prepare check: " .. pending_check,
        reason = "runtime running with validation pending",
        derivedFrom = "runtime",
      }
    end
    return {
      value = "worker active — review/QA while waiting",
      reason = "runtime running",
      derivedFrom = "runtime",
    }
  end
  if pending_check then
    return {
      value = "run check: " .. pending_check,
      reason = last_validated and ("pending checks after " .. last_validated) or "pending checks present",
      derivedFrom = "plan",
    }
  end
  if plan.status == "READY" and active_slice == nil then
    if plan.planned_slice then
      return {
        value = "start " .. plan.planned_slice,
        reason = "ready plan with no active slice",
        derivedFrom = "plan",
      }
    end
    return {
      value = "start implementation",
      reason = "ready plan with no planned slice label",
      derivedFrom = "plan",
    }
  end
  if plan.status == "READY" and active_slice ~= nil then
    return {
      value = "continue " .. active_slice,
      reason = "active slice present",
      derivedFrom = "plan",
    }
  end
  if handoff.available then
    return {
      value = "handoff available for continuation",
      reason = "handoff present",
      derivedFrom = "handoff",
    }
  end
  return {
    value = "no actionable OPS state",
    reason = "no bounded signal available",
    derivedFrom = "mixed",
  }
end

local function max_revision(previous_snapshot, previous_task)
  local revision = 0
  if previous_snapshot and type(previous_snapshot.revision) == "number" and previous_snapshot.revision > revision then
    revision = previous_snapshot.revision
  end
  if previous_task and type(previous_task.revision) == "number" and previous_task.revision > revision then
    revision = previous_task.revision
  end
  return revision
end

M.next_action_details = next_action_details

local function project_plan(root)
  local plan = state.plan_state(root)
  return plan, {
    state = plan_state_kind(plan),
    path = to_json_value(plan.path),
    status = to_json_value(plan.status),
    plannedSlice = to_json_value(plan.planned_slice),
    activeSlice = to_json_value(first_item(plan.tracking["Active slice"])),
    completedSlices = list_items(plan.tracking["Completed slices"]),
    pendingChecks = list_items(plan.tracking["Pending checks"]),
    lastValidatedState = to_json_value(first_item(plan.tracking["Last validated state"])),
    nextRecommendedAction = to_json_value(first_item(plan.tracking["Next recommended action"])),
    warnings = vim.deepcopy(plan.warnings or {}),
  }
end

local function project_review(root)
  local review = state.review_summary(root)
  return review, {
    state = review.available and "available" or "unavailable",
    source = to_json_value(review.source),
    mayBeStale = review.source ~= "live",
    refreshedAt = to_json_value(review.refreshedAt),
    actionable = review.actionable or 0,
    line = review.line or "review unavailable",
    warnings = vim.deepcopy(review.warnings or {}),
  }
end

local function project_runtime(root)
  local runtime = state.runtime_state(root)
  return runtime, {
    state = runtime_state_kind(runtime),
    source = runtime.exists and "file" or JSON_NULL,
    phase = to_json_value(runtime.phase),
    tool = to_json_value(runtime.tool),
    model = to_json_value(runtime.model),
    thinking = to_json_value(runtime.thinking),
    updatedAt = to_json_value(runtime.updatedAt),
    warnings = vim.deepcopy(runtime.warnings or {}),
  }
end

local function project_handoff(root)
  local handoff = state.handoff_state(root)
  return handoff, {
    state = handoff.available and "available" or "missing",
    kind = to_json_value(handoff.kind),
    path = to_json_value(handoff.path),
  }
end

local function project_mode(root)
  local mode_state = mode.read(root)
  return mode_state, {
    state = "available",
    mode = mode_state.mode,
    explicit = mode_state.explicit,
    hint = {
      roles = mode_state.description.roles,
      review = mode_state.description.review,
      scope = mode_state.description.scope,
    },
    warnings = vim.deepcopy(mode_state.warnings or {}),
  }
end

function M.snapshot_path(cwd)
  return state.snapshot_status_path(cwd)
end

function M.project(cwd)
  local root = vim.fs.normalize(cwd or vim.fn.getcwd())
  local plan_raw, plan = project_plan(root)
  local review_raw, review = project_review(root)
  local runtime_raw, runtime = project_runtime(root)
  local handoff_raw, handoff = project_handoff(root)
  local mode_raw, mode_block = project_mode(root)
  local next_action = next_action_details(plan_raw, review_raw, runtime_raw, handoff_raw)
  local paths = state.handoff_paths(root)
  local task_block = task.project(root, {
    plan = plan_raw,
    review = review_raw,
    runtime = runtime_raw,
    mode_state = mode_raw,
    next_action = next_action,
  })

  return {
    kind = SNAPSHOT_KIND,
    version = SNAPSHOT_VERSION,
    project = basename(root),
    cwd = root,
    paths = {
      snapshot = M.snapshot_path(root),
      task = task.path(root),
      plan = state.plan_path(root),
      runtime = state.runtime_status_path(root),
      handoffImplement = paths.implement,
      handoffGeneric = paths.generic,
    },
    task = task_block,
    plan = plan,
    review = review,
    runtime = runtime,
    handoff = handoff,
    mode = mode_block,
    nextAction = next_action,
  }
end

local function strip_metadata(snapshot)
  local copy = vim.deepcopy(snapshot)
  copy.generatedAt = nil
  copy.updatedAt = nil
  copy.revision = nil
  if copy.task then
    copy.task.updatedAt = nil
    copy.task.revision = nil
  end
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
  return read_existing(M.snapshot_path(cwd))
end

local function write_atomic(path, lines)
  ensure_dir(vim.fs.dirname(path))
  local tmp = string.format("%s.tmp.%d", path, uv.hrtime())
  vim.fn.writefile(lines, tmp)
  local ok, err = uv.fs_rename(tmp, path)
  if not ok then
    pcall(uv.fs_unlink, tmp)
    error(err or "failed to rename OPS snapshot temp file")
  end
end

function M.write(cwd)
  local root = vim.fs.normalize(cwd or vim.fn.getcwd())
  local path = M.snapshot_path(root)
  local snapshot = M.project(root)
  local previous = read_existing(path)
  local previous_task = task.read(root)

  if previous and previous_task and vim.deep_equal(strip_metadata(previous), strip_metadata(snapshot)) and task.same(previous_task, snapshot.task) then
    return previous, false
  end

  local revision = max_revision(previous, previous_task) + 1
  local updated_at = now_iso()
  snapshot.generatedAt = updated_at
  snapshot.updatedAt = snapshot.generatedAt
  snapshot.revision = revision
  snapshot.task.updatedAt = updated_at
  snapshot.task.revision = revision
  task.write(root, snapshot.task)
  write_atomic(path, vim.split(vim.json.encode(snapshot), "\n", { plain = true }))
  return snapshot, true
end

function M.schedule_write(cwd)
  local root = vim.fs.normalize(cwd or vim.fn.getcwd())
  pending.token = pending.token + 1
  local token = pending.token
  vim.defer_fn(function()
    if token ~= pending.token then
      return
    end
    pcall(M.write, root)
  end, 120)
end

return M
