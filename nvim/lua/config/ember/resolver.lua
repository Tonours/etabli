local M = {}

--- Normalize angle bracket component name to classic (dasherized) form
---@param name string Angle bracket name like "Feature::WorkflowEditor::Header"
---@return string classic Classic name like "feature/workflow-editor/header"
function M.normalize_to_classic(name)
  local s = name:gsub("::", "/")
  local result = s:gsub("(%l)(%u)", function(lower, upper)
    return lower .. "-" .. upper:lower()
  end)
  result = result:gsub("^%u", function(c)
    return c:lower()
  end)
  result = result:gsub("/(%u)", function(c)
    return "/" .. c:lower()
  end)
  return result
end

--- Split a string by separator
---@param str string
---@param sep string default "/"
---@return string[]
function M.split_path(str, sep)
  sep = sep or "/"
  -- Escape regex magic chars in separator
  local escaped = sep:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
  local parts = {}
  for part in str:gmatch("[^" .. escaped .. "]+") do
    table.insert(parts, part)
  end
  return parts
end

--- Resolve a component name to candidate file paths
--- Covers: features, shared, routes, legacy pods, classic, data, helpers, services, modifiers
---@param app_dir string Absolute path to the app/ directory
---@param classic_name string Dasherized name like "feature/workflow-editor/header"
---@return string[] candidates Ordered list of candidate file paths
function M.resolve_candidates(app_dir, classic_name)
  local name = classic_name
  local paths = {}

  local function add(path)
    table.insert(paths, path)
  end

  local function add_pod(base)
    add(base .. "template.hbs")
    add(base .. "component.ts")
    add(base .. "component.js")
    add(base .. "index.hbs")
    add(base .. "index.ts")
    add(base .. "index.js")
  end

  -- 1. Feature: feature/{feature}/components/{rest}/{type}
  if name:match("^feature/") then
    local rest = name:gsub("^feature/", "")
    local parts = M.split_path(rest)
    if #parts >= 1 then
      local feature = parts[1]
      local component_parts = {}
      for i = 2, #parts do
        table.insert(component_parts, parts[i])
      end
      local component_path = table.concat(component_parts, "/")
      if component_path ~= "" then
        add_pod(app_dir .. "/features/" .. feature .. "/components/" .. component_path .. "/")
      end
    end
  end

  -- 2. Shared: shared/components/{name}/{type}
  if name:match("^shared/") then
    local rest = name:gsub("^shared/", "")
    add_pod(app_dir .. "/shared/components/" .. rest .. "/")
  end

  -- 3. Routes: routes/{name}/{type}
  local route_base = app_dir .. "/routes/" .. name .. "/"
  add(route_base .. "template.hbs")
  add(route_base .. "route.ts")
  add(route_base .. "route.js")
  add(route_base .. "controller.ts")
  add(route_base .. "controller.js")

  -- 4. Legacy pods
  local legacy_base = app_dir .. "/legacy/pods/" .. name .. "/"
  add(legacy_base .. "template.hbs")
  add(legacy_base .. "route.ts")
  add(legacy_base .. "route.js")
  add(legacy_base .. "controller.ts")
  add(legacy_base .. "controller.js")
  -- Legacy pod components
  add_pod(app_dir .. "/legacy/pods/components/" .. name .. "/")

  -- 5. Classic components
  local classic_base = app_dir .. "/components/" .. name
  add(classic_base .. ".hbs")
  add(classic_base .. ".ts")
  add(classic_base .. ".js")
  add_pod(classic_base .. "/")

  -- 6. Classic templates/components
  add(app_dir .. "/templates/components/" .. name .. ".hbs")

  -- 7. Data: data/{folder}/{name}
  for _, folder in ipairs({ "models", "adapters", "serializers", "transforms" }) do
    local p = app_dir .. "/data/" .. folder .. "/" .. name
    add(p .. ".ts")
    add(p .. ".js")
  end

  -- 8. Helpers, services, modifiers (flat)
  for _, folder in ipairs({ "helpers", "services", "modifiers" }) do
    local p = app_dir .. "/" .. folder .. "/" .. name
    add(p .. ".ts")
    add(p .. ".js")
  end

  -- 9. Shared helpers/services/modifiers
  for _, folder in ipairs({ "helpers", "services", "modifiers" }) do
    local p = app_dir .. "/shared/" .. folder .. "/" .. name
    add(p .. ".ts")
    add(p .. ".js")
  end

  -- 10. Feature services and state
  if name:match("^feature/") then
    local rest = name:gsub("^feature/", "")
    local parts = M.split_path(rest)
    if #parts >= 1 then
      local feature = parts[1]
      add(app_dir .. "/features/" .. feature .. "/services/feature.ts")
      add(app_dir .. "/features/" .. feature .. "/services/feature.js")
      if #parts == 1 or (#parts == 2 and parts[2] == "state") then
        add(app_dir .. "/features/" .. feature .. "/state.ts")
        add(app_dir .. "/features/" .. feature .. "/state.js")
      end
    end
  end

  return paths
end

return M
