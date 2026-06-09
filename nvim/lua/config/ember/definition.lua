local resolver = require("config.ember.resolver")

local M = {}

---@class EmberTag
---@field name_start number 1-indexed
---@field name_end number 1-indexed
---@field tag_start number 1-indexed position of '<' or opening '{{'
---@field name string

--- Find all angle bracket tag names on a line
---@param line string
---@return EmberTag[]
local function find_angle_tags(line)
  local tags = {}
  local i = 1
  while i <= #line do
    if line:sub(i, i) == "<" then
      local name_start = i + 1
      -- Skip '/' for closing tags
      if line:sub(name_start, name_start) == "/" then
        name_start = name_start + 1
      end
      local name_end = name_start
      while name_end <= #line and line:sub(name_end, name_end):match("[%w%-%:%./_]") do
        name_end = name_end + 1
      end
      name_end = name_end - 1

      if name_end >= name_start then
        local tag_name = line:sub(name_start, name_end)
        if tag_name:match("^%u") and not tag_name:match("^%@") then
          table.insert(tags, {
            tag_start = i,
            name_start = name_start,
            name_end = name_end,
            name = tag_name,
          })
        end
      end
      i = name_end + 1
    else
      i = i + 1
    end
  end
  return tags
end

--- Find all mustache/block component names on a line
---@param line string
---@return EmberTag[]
local function find_mustache_tags(line)
  local tags = {}
  local i = 1
  while i <= #line - 1 do
    if line:sub(i, i + 1) == "{{" then
      local content_start = i + 2
      -- Skip # for block open, / for block close
      if line:sub(content_start, content_start) == "#" then
        content_start = content_start + 1
      elseif line:sub(content_start, content_start) == "/" then
        content_start = content_start + 1
      end
      -- Skip whitespace
      while content_start <= #line and line:sub(content_start, content_start):match("%s") do
        content_start = content_start + 1
      end

      -- Find end of component name
      local name_end_pos = content_start
      while name_end_pos <= #line do
        local c = line:sub(name_end_pos, name_end_pos)
        if c:match("[%s%|%}]") then
          break
        end
        name_end_pos = name_end_pos + 1
      end
      local name = line:sub(content_start, name_end_pos - 1)

      if
        name ~= ""
        and name:match("^[a-z]")
        and (name:match("/") or name:match("-"))
        and not name:match("%.")
      then
        table.insert(tags, {
          tag_start = i,
          name_start = content_start,
          name_end = name_end_pos - 1,
          name = name,
        })
      end
      i = name_end_pos
    else
      i = i + 1
    end
  end
  return tags
end

--- Find which tag the cursor column falls inside
---@param tags EmberTag[]
---@param col number 1-indexed cursor position
---@return string|nil, string|nil
local function match_tag_at_col(tags, col)
  for _, tag in ipairs(tags) do
    if col >= tag.name_start and col <= tag.name_end + 1 then
      return tag.name, nil -- type set by caller
    end
  end
  return nil, nil
end

--- Get the component name under cursor in an HBS buffer
---@return string|nil name, string|nil type ("angle"|"mustache")
function M.get_component_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  -- Try angle bracket tags first
  local angle_tags = find_angle_tags(line)
  for _, tag in ipairs(angle_tags) do
    if col >= tag.name_start and col <= tag.name_end + 1 then
      return tag.name, "angle"
    end
  end

  -- Then mustache tags
  local mustache_tags = find_mustache_tags(line)
  for _, tag in ipairs(mustache_tags) do
    if col >= tag.tag_start and col <= tag.name_end then
      return tag.name, "mustache"
    end
  end

  return nil, nil
end

--- Find the project root (directory with ember-cli-build.js)
---@param filepath string
---@return string|nil
local function find_project_root(filepath)
  local dir = vim.fn.fnamemodify(filepath, ":h")
  while dir ~= "/" and dir ~= "" do
    if vim.fn.filereadable(dir .. "/ember-cli-build.js") == 1 then
      return dir
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return nil
end

--- Main "go to definition" handler for HBS files
---@return boolean whether a definition was found and opened
function M.goto_definition()
  local bufname = vim.api.nvim_buf_get_name(0)

  if not bufname:match("%.hbs$") then
    return false
  end

  local root = find_project_root(bufname)
  if not root then
    return false
  end

  local component_name = M.get_component_at_cursor()
  if not component_name then
    return false
  end

  local classic_name = resolver.normalize_to_classic(component_name)
  local candidates = resolver.resolve_candidates(root .. "/app", classic_name)

  -- Also try the name as-is
  if classic_name ~= component_name then
    vim.list_extend(candidates, resolver.resolve_candidates(root .. "/app", component_name))
  end

  -- Filter to existing files, deduplicate
  local files = {}
  local seen = {}
  for _, p in ipairs(candidates) do
    if not seen[p] and vim.fn.filereadable(p) == 1 then
      seen[p] = true
      table.insert(files, p)
    end
  end

  if #files == 0 then
    return false
  end

  -- Sort: .hbs first, then .ts, then .js
  table.sort(files, function(a, b)
    local function priority(p)
      if p:match("%.hbs$") then return 1 end
      if p:match("%.ts$") then return 2 end
      if p:match("%.js$") then return 3 end
      return 4
    end
    return priority(a) < priority(b)
  end)

  vim.cmd("edit " .. vim.fn.fnameescape(files[1]))

  if #files > 1 then
    vim.fn.setqflist({}, "r", {
      title = "Ember: " .. component_name,
      items = vim.tbl_map(function(f)
        return { filename = f, lnum = 1, col = 1, text = vim.fn.fnamemodify(f, ":~:.") }
      end, files),
    })
  end

  return true
end

return M
