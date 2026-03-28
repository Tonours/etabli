local M = {}

local plugin_name = "telescope.nvim"
local loaded = false
local load_attempted = false

function M.load()
  if loaded or package.loaded.telescope then
    loaded = true
    return true
  end

  if not load_attempted then
    load_attempted = true

    local ok_lazy, lazy = pcall(require, "lazy")
    if ok_lazy then
      lazy.load({ plugins = { plugin_name } })
    end
  end

  local ok = pcall(require, "telescope")
  loaded = ok
  return ok
end

function M.require(module)
  if not M.load() then
    return nil
  end

  local ok, loaded = pcall(require, module)
  if not ok then
    return nil
  end

  return loaded
end

return M
