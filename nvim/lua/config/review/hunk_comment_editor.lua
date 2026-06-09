local M = {}

local function sanitize_segment(value)
  return tostring(value):gsub("[^%w%-_.]", "_")
end

local function geometry()
  local available_width = math.max(30, vim.o.columns - 6)
  local width = math.min(math.max(72, math.floor(vim.o.columns * 0.72)), available_width)
  local available_height = math.max(8, vim.o.lines - 6)
  local height = math.min(math.max(10, math.floor(vim.o.lines * 0.38)), available_height)

  return {
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2)),
    width = width,
  }
end

local function open_window(target, on_submit, opts)
  local options = opts or {}
  local origin_win = vim.api.nvim_get_current_win()
  local size = geometry()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid = vim.api.nvim_open_win(bufnr, true, {
    border = "rounded",
    col = size.col,
    height = size.height,
    relative = "editor",
    row = size.row,
    style = "minimal",
    title = string.format("Hunk review comment %s", target),
    title_pos = "center",
    width = size.width,
    zindex = 95,
  })

  pcall(
    vim.api.nvim_buf_set_name,
    bufnr,
    string.format("hunk-review-comment://%s-%d", sanitize_segment(target), bufnr)
  )
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })

  local closed = false
  local group = vim.api.nvim_create_augroup(string.format("etabli_hunk_review_comment_%d", bufnr), { clear = true })

  local function close()
    if winid and vim.api.nvim_win_is_valid(winid) then
      pcall(vim.api.nvim_win_close, winid, true)
    end

    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end

    if origin_win and vim.api.nvim_win_is_valid(origin_win) then
      pcall(vim.api.nvim_set_current_win, origin_win)
    end
  end

  local function comment_body()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    return table.concat(lines, "\n")
  end

  local function has_comment_body()
    return vim.trim(comment_body()) ~= ""
  end

  local function submit(submit_opts)
    local submit_options = submit_opts or {}
    if closed then
      return
    end

    closed = true
    local body = comment_body()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.bo[bufnr].modified = false
    end

    on_submit(body)

    if submit_options.defer_close then
      vim.schedule(close)
    else
      close()
    end
  end

  local function cancel(force)
    if closed then
      return
    end

    if force ~= true and has_comment_body() then
      vim.notify("Review comment not saved. Use :write or ZZ to save, ZQ to discard.", vim.log.levels.WARN)
      return
    end

    closed = true
    close()
    if options.on_cancel then
      options.on_cancel()
    end
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    group = group,
    callback = function()
      submit({ defer_close = true })
    end,
  })

  for _, mode in ipairs({ "n", "i" }) do
    vim.keymap.set(mode, "<C-s>", submit, {
      buffer = bufnr,
      desc = "Save Hunk review comment",
      nowait = true,
      silent = true,
    })
  end

  vim.keymap.set("n", "ZZ", submit, { buffer = bufnr, desc = "Save Hunk review comment", nowait = true, silent = true })
  vim.keymap.set("n", "ZQ", function()
    cancel(true)
  end, { buffer = bufnr, desc = "Discard Hunk review comment", nowait = true, silent = true })
  vim.keymap.set("n", "q", cancel, { buffer = bufnr, desc = "Cancel Hunk review comment", nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = bufnr, desc = "Cancel Hunk review comment", nowait = true, silent = true })

  vim.cmd.startinsert()
end

function M.prompt(target, on_submit, opts)
  if #vim.api.nvim_list_uis() > 0 then
    open_window(target, on_submit, opts)
    return
  end

  vim.ui.input({
    prompt = string.format("Hunk review comment %s: ", target),
  }, on_submit)
end

return M
