-- Override built-in ftplugin/lua.lua to defer treesitter for faster file opening
-- The built-in version calls vim.treesitter.start() synchronously which blocks the UI
-- We defer it so the buffer content is visible immediately
vim.schedule(function()
  if vim.api.nvim_buf_is_valid(0) and vim.bo.filetype == "lua" and not vim.b.large_file then
    vim.treesitter.start(0, "lua")
  end
end)

-- These can run immediately (cheap)
vim.bo.includeexpr = [[v:lua.require'vim._ftplugin.lua'.includeexpr(v:fname)]]
vim.bo.omnifunc = "v:lua.vim.lua_omnifunc"
vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or "")
  .. "\n call v:lua.vim.treesitter.stop()"
  .. "\n setl omnifunc< foldexpr< includeexpr<"
