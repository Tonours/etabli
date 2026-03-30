local M = {}

local uv = vim.uv or vim.loop
local cache_ttl_ms = 750

local plan_cache = {
  path = nil,
  checked_at = 0,
  mtime = nil,
  value = nil,
}

local runtime_cache = {
  path = nil,
  checked_at = 0,
  mtime = nil,
  value = nil,
}

local commands_registered = false

local tracking_fields = {
  "Active slice",
  "Completed slices",
  "Pending checks",
  "Last validated state",
  "Next recommended action",
}

local function now_ms()
  return vim.loop.now()
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
  return cwd:gsub("[^%w%._%-]+", "_")
end

local function plan_path(cwd)
  return vim.fs.normalize(cwd .. "/PLAN.md")
end

local function runtime_status_path(cwd)
  return vim.fn.expand("~/.pi/status/" .. sanitize_status_file_name(vim.fs.normalize(cwd)) .. ".json")
end

local function parse_tracking(content)
  local tracking = {}
  for _, field in ipairs(tracking_fields) do
    tracking[field] = {}
  end

  local lines = vim.split(content, "\n", { plain = true })
  local in_tracking = false
  local current_field = nil

  for _, line in ipairs(lines) do
    if not in_tracking then
      if vim.trim(line) == "## Implementation Tracking" then
        in_tracking = true
      end
    else
      if vim.startswith(line, "## ") then
        break
      end

      local field = line:match("^%- (.-):%s*$")
      if field and tracking[field] then
        current_field = field
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
  end

  return tracking
end

local function parse_plan(content)
  local status = nil
  for _, line in ipairs(vim.split(content, "\n", { plain = true })) do
    local matched = line:match("^%- Status:%s*(.-)%s*$")
    if matched then
      status = matched
      break
    end
  end

  return {
    status = status,
    tracking = parse_tracking(content),
  }
end

local function parse_runtime(content)
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

local function cached_read(cache, path, parser)
  local now = now_ms()
  if cache.path == path and (now - cache.checked_at) < cache_ttl_ms then
    return cache.value
  end

  cache.checked_at = now
  cache.path = path

  local mtime = file_mtime(path)
  if not mtime then
    cache.mtime = nil
    cache.value = nil
    return nil
  end

  if cache.mtime == mtime and cache.value ~= nil then
    return cache.value
  end

  local content = read_file(path)
  if not content then
    cache.mtime = nil
    cache.value = nil
    return nil
  end

  cache.mtime = mtime
  cache.value = parser(content)
  return cache.value
end

function M.invalidate()
  plan_cache.checked_at = 0
  plan_cache.mtime = nil
  plan_cache.value = nil
  runtime_cache.checked_at = 0
  runtime_cache.mtime = nil
  runtime_cache.value = nil
end

function M.plan_state(cwd)
  return cached_read(plan_cache, plan_path(cwd or vim.fn.getcwd()), parse_plan)
end

function M.runtime_state(cwd)
  return cached_read(runtime_cache, runtime_status_path(cwd or vim.fn.getcwd()), parse_runtime)
end

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

function M.info_lines(cwd)
  local lines = {}
  local plan = M.plan_state(cwd)
  local runtime = M.runtime_state(cwd)

  if plan then
    table.insert(lines, "ADE plan:   " .. (plan.status or "unknown"))
    table.insert(lines, "Slice:      " .. first_value(plan.tracking["Active slice"]))
    table.insert(lines, "Completed:  " .. join_values(plan.tracking["Completed slices"]))
    table.insert(lines, "Checks:     " .. join_values(plan.tracking["Pending checks"]))
    table.insert(lines, "Next:       " .. first_value(plan.tracking["Next recommended action"]))
  else
    table.insert(lines, "ADE plan:   unavailable")
  end

  if runtime then
    local runtime_line = "Runtime:    " .. (runtime.phase or "unknown")
    if runtime.tool and runtime.tool ~= "" then
      runtime_line = runtime_line .. " · " .. runtime.tool
    end
    if runtime.model and runtime.model ~= "" then
      runtime_line = runtime_line .. " · " .. runtime.model
    end
    table.insert(lines, runtime_line)
    if runtime.updatedAt and runtime.updatedAt ~= "" then
      table.insert(lines, "Updated:    " .. runtime.updatedAt)
    end
  else
    table.insert(lines, "Runtime:    unavailable")
  end

  return lines
end

function M.project_info_lines(cwd)
  local info = M.info_lines(cwd)
  local lines = { "ADE:" }
  for _, line in ipairs(info) do
    table.insert(lines, "  " .. line)
  end
  return lines
end

local function truncate(text, max_len)
  if #text <= max_len then
    return text
  end
  return text:sub(1, max_len - 1) .. "…"
end

function M.statusline_label()
  local plan = M.plan_state(vim.fn.getcwd())
  local runtime = M.runtime_state(vim.fn.getcwd())

  if not plan and not runtime then
    return ""
  end

  local parts = { "ADE" }
  if plan and plan.status then
    table.insert(parts, plan.status)
    local active = first_value(plan.tracking["Active slice"])
    if active ~= "none" then
      table.insert(parts, truncate(active, 18))
    end
  end
  if runtime and runtime.phase then
    table.insert(parts, runtime.phase)
  end

  return table.concat(parts, " · ")
end

function M.statusline_color()
  local plan = M.plan_state(vim.fn.getcwd())
  if not plan or not plan.status then
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

function M.show_status()
  vim.notify(table.concat(M.info_lines(), "\n"), vim.log.levels.INFO, { title = "ADEStatus" })
end

function M.setup_commands()
  if commands_registered then
    return
  end

  commands_registered = true

  vim.api.nvim_create_user_command("ADEStatus", function()
    M.show_status()
  end, { desc = "Show ADE plan/runtime status" })

  vim.api.nvim_create_user_command("ADE", function()
    M.show_status()
  end, { desc = "Show ADE plan/runtime status" })

  local group = vim.api.nvim_create_augroup("etabli_ade_runtime", { clear = true })
  vim.api.nvim_create_autocmd({ "DirChanged", "BufWritePost" }, {
    group = group,
    pattern = { "*", "PLAN.md" },
    callback = function()
      M.invalidate()
    end,
  })
end

return M
