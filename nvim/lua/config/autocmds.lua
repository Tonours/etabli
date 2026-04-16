local group = vim.api.nvim_create_augroup("etabli_core", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    if vim.b.large_file then
      return
    end
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

-- Single FileType autocmd for all formatoptions + markdown handling
local formatoptions_fts = {
  javascript = true, typescript = true, javascriptreact = true, typescriptreact = true,
  json = true, jsonc = true, yaml = true, lua = true, html = true, css = true, scss = true,
  markdown = true, hbs = true, handlebars = true, ["html.handlebars"] = true,
}

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    if formatoptions_fts[ft] then
      vim.opt_local.formatoptions:remove({ "c", "r", "o" })
    end
    if ft == "markdown" then
      vim.opt_local.wrap = true
      vim.opt_local.linebreak = true
    end
  end,
})

-- Large file protection
local large_file_threshold = 3 * 1024 * 1024
local medium_file_threshold = 512 * 1024

local function mark_large_file(bufnr)
  local bo = vim.bo[bufnr]

  bo.syntax = "off"
  bo.undolevels = -1
  bo.swapfile = false
  bo.bufhidden = "unload"
  vim.b[bufnr].large_file = true

  if vim.api.nvim_get_current_buf() == bufnr then
    vim.wo.foldmethod = "manual"
  end
end

vim.api.nvim_create_autocmd("BufReadPre", {
  group = group,
  callback = function(args)
    local bufnr = args.buf
    local bo = vim.bo[bufnr]

    if bo.buftype ~= "" or not bo.buflisted then
      return
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == "" then
      return
    end

    local ok, stats = pcall(vim.uv.fs_stat, bufname)
    if not ok or not stats then
      return
    end

    if stats.size > large_file_threshold then
      mark_large_file(bufnr)
      return
    end

    if stats.size > medium_file_threshold then
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        mark_large_file(bufnr)
      end)
    end
  end,
})
