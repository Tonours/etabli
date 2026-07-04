local function fail(message)
  vim.api.nvim_err_writeln("nvim keymap collision smoke failed: " .. message)
  vim.cmd("cquit 1")
end

local config_root = vim.fn.stdpath("config")

local function read_file(relative_path)
  local path = config_root .. "/" .. relative_path
  local lines = vim.fn.readfile(path)
  if type(lines) ~= "table" or #lines == 0 then
    fail("could not read " .. path)
  end
  return lines
end

local function collect_keymaps(lines)
  local entries = {}
  for line_number, line in ipairs(lines) do
    local mode, lhs = line:match('map%(%s*"(%a)"%s*,%s*"(<leader>[^"]+)"')
    if mode and lhs then
      table.insert(entries, { mode = mode, lhs = lhs, line = line_number })
    end
  end
  return entries
end

local keymap_entries = collect_keymaps(read_file("lua/config/keymaps.lua"))
if #keymap_entries == 0 then
  fail("no leader keymaps found in keymaps.lua; pattern out of date")
end

local seen = {}
for _, entry in ipairs(keymap_entries) do
  local key = entry.mode .. " " .. entry.lhs
  if seen[key] then
    fail(string.format("duplicate keymap %s (lines %d and %d in keymaps.lua)", key, seen[key], entry.line))
  end
  seen[key] = entry.line
end

local lsp_lhs = {}
for _, line in ipairs(read_file("lua/config/lsp.lua")) do
  local lhs = line:match('map%(%s*"(<leader>[^"]+)"')
  if lhs then
    table.insert(lsp_lhs, lhs)
  end
end
if #lsp_lhs == 0 then
  fail("no leader keymaps found in lsp.lua; pattern out of date")
end

for _, lhs in ipairs(lsp_lhs) do
  if seen["n " .. lhs] then
    fail(string.format("keymap %s is shadowed: buffer-local LSP mapping in lsp.lua overrides keymaps.lua", lhs))
  end
end
