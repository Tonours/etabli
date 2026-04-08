local M = {}

function M.patch()
  local ok, notices = pcall(require, "lualine.utils.notices")
  if not ok or type(notices.show_notices) ~= "function" then
    return
  end

  if notices.__etabli_flatten_patch_applied then
    return
  end

  local original_show_notices = notices.show_notices

  notices.show_notices = function(...)
    local original_flatten = vim.tbl_flatten
    vim.tbl_flatten = function(items)
      if vim.iter then
        return vim.iter(items):flatten(math.huge):totable()
      end
      return original_flatten(items)
    end

    local ok_show, result = pcall(original_show_notices, ...)
    vim.tbl_flatten = original_flatten

    if not ok_show then
      error(result)
    end

    return result
  end

  notices.__etabli_flatten_patch_applied = true
end

return M
