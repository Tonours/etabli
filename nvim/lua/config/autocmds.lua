local group = vim.api.nvim_create_augroup("etabli_core", { clear = true })

-- Async copilot-cmp setup: defer loading until after first InsertEnter
local copilot_cmp_setup_done = false
vim.api.nvim_create_autocmd("InsertEnter", {
  group = group,
  once = true,
  callback = function()
    if copilot_cmp_setup_done or vim.bo.filetype == "markdown" then
      return
    end
    vim.defer_fn(function()
      if copilot_cmp_setup_done then
        return
      end
      copilot_cmp_setup_done = true
      local ok_lazy, lazy = pcall(require, "lazy")
      if ok_lazy then
        lazy.load({ plugins = { "copilot-cmp" } })
      end
    end, 150)
  end,
})

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
      bo.syntax = "off"
      bo.foldmethod = "manual"
      bo.undolevels = -1
      bo.swapfile = false
      bo.bufhidden = "unload"
      vim.b[bufnr].large_file = true
      return
    end

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
