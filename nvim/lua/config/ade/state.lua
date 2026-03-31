local M = {}

local uv = vim.uv or vim.loop
local cache_ttl_ms = 750

local tracking_fields = {
  "Active slice",
  "Completed slices",
  "Pending checks",
  "Last validated state",
  "Next recommended action",
}

local valid_plan_statuses = {
  DRAFT = true,
  CHALLENGED = true,
  READY = true,
}

local valid_runtime_phases = {
  idle = true,
  running = true,
  offline = true,
}

local plan_cache = {
  key = nil,
  checked_at = 0,
  mtime = nil,
  value = nil,
}

local runtime_cache = {
  key = nil,
  checked_at = 0,
  mtime = nil,
  value = nil,
}

local review_cache = {
  key = nil,
  checked_at = 0,
  live_until = 0,
  value = nil,
}

local function now_ms()
  return uv.now()
end

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%S.000Z")
end

local function file_mtime(path)
  local stat = uv.fs_stat(path)
  if not stat or not stat.mtime then
    return nil
  end

  return string.format("%s:%s", stat.mtime.sec or 0, stat.mtime.nsec or 0)
end

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()
  return content
end

local function sanitize_status_file_name(cwd)
  return cwd:gsub("[^A-Za-z0-9%._%-]+", "_")
end

function M.status_file_name(cwd)
  local normalized = vim.fs.normalize(cwd or vim.fn.getcwd())
  return sanitize_status_file_name(normalized)
end

local function empty_tracking()
  local tracking = {}
  for _, field in ipairs(tracking_fields) do
    tracking[field] = {}
  end
  return tracking
end

local function add_warning(warnings, message)
  table.insert(warnings, message)
end

local function inspect_cached_file(cache, key, path, parser, missing_factory)
  local now = now_ms()
  if cache.key == key and (now - cache.checked_at) < cache_ttl_ms then
    return cache.value
  end

  cache.checked_at = now
  cache.key = key

  local mtime = file_mtime(path)
  if not mtime then
    cache.mtime = nil
    cache.value = missing_factory(path)
    return cache.value
  end

  if cache.mtime == mtime and cache.value ~= nil then
    return cache.value
  end

  local content = read_file(path)
  if not content then
    cache.mtime = nil
    cache.value = missing_factory(path)
    return cache.value
  end

  cache.mtime = mtime
  cache.value = parser(content, path)
  return cache.value
end

function M.plan_path(cwd)
  return vim.fs.normalize((cwd or vim.fn.getcwd()) .. "/PLAN.md")
end

function M.runtime_status_path(cwd)
  return vim.fn.expand("~/.pi/status/" .. M.status_file_name(cwd) .. ".json")
end

function M.snapshot_status_path(cwd)
  return vim.fn.expand("~/.pi/status/" .. M.status_file_name(cwd) .. ".ade.json")
end

function M.handoff_paths(cwd)
  local root = vim.fs.normalize(cwd or vim.fn.getcwd())
  return {
    implement = vim.fs.normalize(root .. "/.pi/handoff-implement.md"),
    generic = vim.fs.normalize(root .. "/.pi/handoff.md"),
  }
end

local function parse_tracking(content)
  local tracking = empty_tracking()
  local warnings = {}
  local seen_fields = {}
  local lines = vim.split(content, "\n", { plain = true })
  local start_index = nil

  for index, line in ipairs(lines) do
    if vim.trim(line) == "## Implementation Tracking" then
      start_index = index
      break
    end
  end

  if not start_index then
    add_warning(warnings, "Missing Implementation Tracking section")
    return tracking, warnings
  end

  local current_field = nil
  for index = start_index + 1, #lines do
    local line = lines[index]:gsub("\r$", "")
    if vim.startswith(line, "## ") then
      break
    end

    local field, remainder = line:match("^%- (.-):%s*(.-)%s*$")
    if field and tracking[field] ~= nil then
      current_field = field
      seen_fields[field] = true
      if remainder ~= "" then
        table.insert(tracking[field], remainder)
      end
    elseif current_field then
      local bullet = line:match("^%s%s%-%s+(.*)$")
      if bullet and bullet ~= "" then
        table.insert(tracking[current_field], vim.trim(bullet))
      else
        local continuation = line:match("^%s%s%s%s(.*)$")
        if continuation and continuation ~= "" and #tracking[current_field] > 0 then
          tracking[current_field][#tracking[current_field]] = tracking[current_field][#tracking[current_field]] .. "\n" .. vim.trim(continuation)
        end
      end
    end
  end

  for _, field in ipairs(tracking_fields) do
    if not seen_fields[field] then
      add_warning(warnings, "Missing tracking field: " .. field)
    end
  end

  return tracking, warnings
end

local function parse_first_execution_slice(content)
  local lines = vim.split(content, "\n", { plain = true })
  local in_execution_slices = false

  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed == "## Execution Slices" then
      in_execution_slices = true
    elseif in_execution_slices and vim.startswith(trimmed, "## ") then
      break
    elseif in_execution_slices then
      local slice = trimmed:match("^###%s+(.+)$")
      if slice and slice ~= "" then
        return slice
      end
    end
  end

  return nil
end

function M.inspect_plan_content(content)
  local warnings = {}
  local status = nil

  for _, line in ipairs(vim.split(content, "\n", { plain = true })) do
    local matched = line:match("^%- Status:%s*(.-)%s*$")
    if matched then
      status = matched
      break
    end
  end

  if not status then
    add_warning(warnings, "Missing plan status")
  elseif not valid_plan_statuses[status] then
    add_warning(warnings, "Invalid plan status: " .. status)
    status = nil
  end

  local tracking, tracking_warnings = parse_tracking(content)
  vim.list_extend(warnings, tracking_warnings)

  return {
    exists = true,
    status = status,
    planned_slice = parse_first_execution_slice(content),
    tracking = tracking,
    warnings = warnings,
  }
end

function M.plan_state(cwd)
  local path = M.plan_path(cwd)
  local key = vim.fs.normalize(cwd or vim.fn.getcwd())

  return inspect_cached_file(plan_cache, key, path, function(content, target)
    local parsed = M.inspect_plan_content(content)
    parsed.path = target
    return parsed
  end, function(target)
    return {
      exists = false,
      path = target,
      status = nil,
      planned_slice = nil,
      tracking = empty_tracking(),
      warnings = {},
    }
  end)
end

local function read_required_string(decoded, key, warnings)
  local value = decoded[key]
  if type(value) ~= "string" or vim.trim(value) == "" then
    add_warning(warnings, string.format("Runtime status %s must be a non-empty string", key))
    return nil
  end
  return value
end

function M.inspect_runtime_content(content)
  local warnings = {}
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    return {
      exists = true,
      version = nil,
      project = nil,
      cwd = nil,
      phase = nil,
      tool = nil,
      model = nil,
      thinking = nil,
      updatedAt = nil,
      warnings = { "Runtime status is not valid JSON" },
    }
  end

  local version = decoded.version
  if version ~= nil and version ~= 1 then
    add_warning(warnings, "Runtime status version must be 1")
  end

  local phase = read_required_string(decoded, "phase", warnings)
  if phase and not valid_runtime_phases[phase] then
    add_warning(warnings, "Runtime status phase must be one of: idle, running, offline")
    phase = nil
  end

  local tool = decoded.tool
  if tool ~= nil and type(tool) ~= "string" then
    add_warning(warnings, "Runtime status tool must be a string when present")
    tool = nil
  end

  local model = decoded.model
  if model ~= nil and type(model) ~= "string" then
    add_warning(warnings, "Runtime status model must be a string when present")
    model = nil
  end

  return {
    exists = true,
    version = version,
    project = read_required_string(decoded, "project", warnings),
    cwd = read_required_string(decoded, "cwd", warnings),
    phase = phase,
    tool = tool,
    model = model,
    thinking = read_required_string(decoded, "thinking", warnings),
    updatedAt = read_required_string(decoded, "updatedAt", warnings),
    warnings = warnings,
  }
end

function M.runtime_state(cwd)
  local path = M.runtime_status_path(cwd)
  local key = vim.fs.normalize(cwd or vim.fn.getcwd())

  return inspect_cached_file(runtime_cache, key, path, function(content, target)
    local parsed = M.inspect_runtime_content(content)
    parsed.path = target
    return parsed
  end, function(target)
    return {
      exists = false,
      path = target,
      version = nil,
      project = nil,
      cwd = nil,
      phase = nil,
      tool = nil,
      model = nil,
      thinking = nil,
      updatedAt = nil,
      warnings = {},
    }
  end)
end

local function zero_counts(statuses)
  local counts = { total = 0 }
  for _, status in ipairs(statuses) do
    counts[status] = 0
  end
  return counts
end

function M.review_summary(cwd)
  local key = vim.fs.normalize(cwd or vim.fn.getcwd())
  local now = now_ms()
  if review_cache.key == key and ((now - review_cache.checked_at) < cache_ttl_ms or now < (review_cache.live_until or 0)) then
    return review_cache.value
  end

  review_cache.key = key
  review_cache.checked_at = now
  review_cache.live_until = 0

  local review_diff = require("config.review.diff")
  local review_state = require("config.review.state")
  local repo = review_diff.repo_root(key)
  if not repo then
    review_cache.value = {
      available = false,
      counts = zero_counts(review_state.statuses()),
      actionable = 0,
      line = "no git repo",
      warnings = {},
    }
    return review_cache.value
  end

  local context, err = review_state.context_for_repo(repo)
  if not context then
    review_cache.value = {
      available = false,
      counts = zero_counts(review_state.statuses()),
      actionable = 0,
      line = "no git repo",
      warnings = err and { err } or {},
    }
    return review_cache.value
  end

  local counts = review_state.status_counts(context)
  local actionable = (counts["needs-rework"] or 0) + (counts.question or 0)
  local line
  if actionable > 0 then
    line = string.format("needs-rework %d | question %d (stored, may be stale)", counts["needs-rework"] or 0, counts.question or 0)
  else
    line = "clear in stored state"
  end

  review_cache.value = {
    available = true,
    counts = counts,
    actionable = actionable,
    context = context,
    line = line,
    warnings = {},
    source = "stored",
    refreshedAt = nil,
  }
  return review_cache.value
end

function M.refresh_review_summary(cwd)
  local key = vim.fs.normalize(cwd or vim.fn.getcwd())
  local review_diff = require("config.review.diff")
  local review_state = require("config.review.state")
  local repo = review_diff.repo_root(key)
  if not repo then
    local summary = {
      available = false,
      counts = zero_counts(review_state.statuses()),
      actionable = 0,
      line = "no git repo",
      warnings = {},
      source = "live",
    }
    review_cache.key = key
    review_cache.checked_at = now_ms()
    review_cache.live_until = now_ms() + 5000
    review_cache.value = summary
    return summary
  end

  local context, err = review_state.context_for_repo(repo)
  if not context then
    local summary = {
      available = false,
      counts = zero_counts(review_state.statuses()),
      actionable = 0,
      line = "no git repo",
      warnings = err and { err } or {},
      source = "live",
    }
    review_cache.key = key
    review_cache.checked_at = now_ms()
    review_cache.live_until = now_ms() + 5000
    review_cache.value = summary
    return summary
  end

  review_diff.clear_cache()
  local items, collect_err = review_diff.collect_all(repo)
  if not items then
    local summary = {
      available = false,
      counts = zero_counts(review_state.statuses()),
      actionable = 0,
      line = "review refresh failed",
      warnings = collect_err and { collect_err } or {},
      source = "live",
    }
    review_cache.key = key
    review_cache.checked_at = now_ms()
    review_cache.live_until = now_ms() + 5000
    review_cache.value = summary
    return summary
  end

  local merged = review_state.merge_items(context, items)
  local counts = zero_counts(review_state.statuses())
  local stale_blockers = 0

  for _, item in ipairs(merged) do
    local status = item.status or "new"
    if item.stale then
      if status == "needs-rework" or status == "question" then
        stale_blockers = stale_blockers + 1
      end
    elseif counts[status] ~= nil then
      counts[status] = counts[status] + 1
      counts.total = counts.total + 1
    end
  end

  local actionable = (counts["needs-rework"] or 0) + (counts.question or 0)
  local warnings = {}
  if stale_blockers > 0 then
    table.insert(warnings, string.format("Ignored %d stale blocker(s) during live refresh", stale_blockers))
  end

  local line
  if actionable > 0 then
    line = string.format("needs-rework %d | question %d (live)", counts["needs-rework"] or 0, counts.question or 0)
  else
    line = "clear (live)"
  end

  local summary = {
    available = true,
    counts = counts,
    actionable = actionable,
    context = context,
    line = line,
    warnings = warnings,
    source = "live",
    refreshedAt = now_iso(),
  }
  review_cache.key = key
  review_cache.checked_at = now_ms()
  review_cache.live_until = now_ms() + 5000
  review_cache.value = summary
  return summary
end

function M.handoff_state(cwd)
  local paths = M.handoff_paths(cwd)
  if uv.fs_stat(paths.implement) then
    return {
      available = true,
      kind = "implement",
      path = paths.implement,
    }
  end

  if uv.fs_stat(paths.generic) then
    return {
      available = true,
      kind = "generic",
      path = paths.generic,
    }
  end

  return {
    available = false,
    kind = nil,
    path = nil,
    missing = { paths.implement, paths.generic },
  }
end

function M.invalidate()
  plan_cache.key = nil
  plan_cache.checked_at = 0
  plan_cache.mtime = nil
  plan_cache.value = nil

  runtime_cache.key = nil
  runtime_cache.checked_at = 0
  runtime_cache.mtime = nil
  runtime_cache.value = nil

  review_cache.key = nil
  review_cache.checked_at = 0
  review_cache.live_until = 0
  review_cache.value = nil
end

return M
