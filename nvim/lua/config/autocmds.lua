local group = vim.api.nvim_create_augroup("etabli_core", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    -- Skip highlight for large files
    if vim.b.large_file then
      return
    end
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

-- Optimize formatoptions only for specific filetypes using single autocmd with lookup table
local formatoptions_fts = {
  javascript = true, typescript = true, javascriptreact = true, typescriptreact = true,
  json = true, jsonc = true, yaml = true, lua = true, html = true, css = true, scss = true,
  markdown = true, hbs = true, handlebars = true, ["html.handlebars"] = true,
}
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  callback = function(args)
    if formatoptions_fts[vim.bo[args.buf].filetype] then
      vim.opt_local.formatoptions:remove({ "c", "r", "o" })
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

-- Performance: Disable syntax highlighting and other features for large files
-- Use a single autocmd with optimized early returns
local large_file_threshold = 3 * 1024 * 1024 -- 3MB (reduced from 5MB)
local medium_file_threshold = 512 * 1024 -- 512KB (reduced from 1MB)

vim.api.nvim_create_autocmd({ "BufReadPre" }, {
  group = group,
  callback = function(args)
    local bufnr = args.buf
    local bo = vim.bo[bufnr]

    -- Skip special buffers immediately (fast path)
    if bo.buftype ~= "" or not bo.buflisted then
      return
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == "" then
      return
    end

    -- Quick synchronous check for very large files
    local ok, stats = pcall(vim.uv.fs_stat, bufname)
    if not ok or not stats then
      return
    end

    -- Large file: disable features immediately
    if stats.size > large_file_threshold then
      bo.syntax = "off"
      bo.foldmethod = "manual"
      bo.undolevels = -1
      bo.swapfile = false
      bo.bufhidden = "unload"
      vim.b[bufnr].large_file = true
      return
    end

    -- Medium file: use schedule for deferred handling
    if stats.size > medium_file_threshold then
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end
        local b = vim.bo[bufnr]
        b.syntax = "off"
        b.foldmethod = "manual"
        b.undolevels = -1
        b.swapfile = false
        b.bufhidden = "unload"
        vim.b[bufnr].large_file = true
      end)
    end
  end,
})
