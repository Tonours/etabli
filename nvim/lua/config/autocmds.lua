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

-- Protect editing responsiveness without hiding syntax in medium-sized source files.
local large_file_threshold = 3 * 1024 * 1024
local medium_file_threshold = 512 * 1024

local function mark_performance_file(bufnr)
  local bo = vim.bo[bufnr]

  bo.undolevels = -1
  bo.swapfile = false
  bo.bufhidden = "unload"
  vim.b[bufnr].large_file = true

  if vim.api.nvim_get_current_buf() == bufnr then
    vim.wo.foldmethod = "manual"
  end
end

local function mark_large_file(bufnr)
  mark_performance_file(bufnr)
  vim.b[bufnr].disable_syntax = true
end

vim.api.nvim_create_autocmd("BufReadPre", {
  group = group,
  callback = function(args)
    local bufnr = args.buf
    local bo = vim.bo[bufnr]

    if bo.buftype ~= "" then
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
    elseif stats.size > medium_file_threshold then
      mark_performance_file(bufnr)
    end
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  callback = function(args)
    if not vim.b[args.buf].disable_syntax then
      return
    end

    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(args.buf) and vim.b[args.buf].disable_syntax then
        vim.bo[args.buf].syntax = "off"
      end
    end)
  end,
})
