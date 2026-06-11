local M = {}

local rail_by_tab = {}

local function display_width(value)
  return vim.fn.strdisplaywidth(value)
end

local function truncate(value, width)
  local text = tostring(value or "")
  if display_width(text) <= width then
    return text
  end

  return vim.fn.strcharpart(text, 0, math.max(0, width - 3)) .. "..."
end

local function note_line(note)
  local source = tostring(note.source or "note")
  local range = note.newRange or note.oldRange or {}
  local first = tonumber(range[1])
  local last = tonumber(range[2]) or first
  local location = ""
  if first and last and first ~= last then
    location = string.format(" L%d-%d", first, last)
  elseif first then
    location = string.format(" L%d", first)
  end

  return string.format("%s%s", source, location)
end

local function hunk_range(hunk)
  local range = hunk and hunk.newRange or {}
  local first = tonumber(range[1])
  local last = tonumber(range[2])
  if not first then
    return "new ?"
  end
  if not last or last <= first then
    return string.format("new %d", first)
  end

  return string.format("new %d-%d", first, last)
end

local function count_notes_for_file(notes, path)
  local count = 0
  for _, note in ipairs(notes or {}) do
    if note.filePath == path then
      count = count + 1
    end
  end
  return count
end

local function section(lines, title)
  if #lines > 0 and lines[#lines] ~= "" then
    table.insert(lines, "")
  end
  table.insert(lines, title)
end

function M.lines(model, opts)
  local options = opts or {}
  local width = math.max(36, options.width or 44)
  local review = model and model.review or {}
  local files = review.files or {}
  local notes = review.reviewNotes or {}
  local selected_file = review.selectedFile or files[1] or {}
  local selected_hunk = review.selectedHunk or (selected_file.hunks or {})[1] or {}

  local additions = 0
  local deletions = 0
  local hunks = 0
  for _, file in ipairs(files) do
    additions = additions + (tonumber(file.additions) or 0)
    deletions = deletions + (tonumber(file.deletions) or 0)
    hunks = hunks + (tonumber(file.hunkCount) or 0)
  end

  local lines = {
    "Thread    File    Checks",
    string.rep("-", math.min(width, 44)),
    truncate(review.title or "Hunk review", width),
    string.format("files %d  hunks %d  +%d -%d", #files, hunks, additions, deletions),
    string.format("notes %d  live %d", tonumber(review.reviewNoteCount) or #notes, tonumber(review.liveCommentCount) or 0),
  }

  section(lines, "Thread")
  table.insert(lines, truncate(selected_file.path or "No file selected", width))
  table.insert(lines, string.format("hunk %s  %s", tostring(selected_hunk.index or 0), hunk_range(selected_hunk)))

  local selected_notes = {}
  for _, note in ipairs(notes) do
    if note.filePath == selected_file.path then
      table.insert(selected_notes, note)
    end
  end

  if #selected_notes == 0 then
    table.insert(lines, "No notes on selected file")
  else
    for _, note in ipairs(selected_notes) do
      table.insert(lines, "")
      table.insert(lines, truncate(note_line(note), width))
      for _, body_line in ipairs(vim.split(tostring(note.body or ""), "\n", { plain = true })) do
        if vim.trim(body_line) ~= "" then
          table.insert(lines, "  " .. truncate(vim.trim(body_line), width - 2))
        end
      end
    end
  end

  section(lines, "Files")
  for _, file in ipairs(files) do
    local marker = file.path == selected_file.path and ">" or " "
    local note_count = count_notes_for_file(notes, file.path)
    local summary = string.format(
      "%s %s +%d -%d %dh",
      marker,
      file.path or "?",
      tonumber(file.additions) or 0,
      tonumber(file.deletions) or 0,
      tonumber(file.hunkCount) or 0
    )
    if note_count > 0 then
      summary = summary .. string.format(" %dn", note_count)
    end
    table.insert(lines, truncate(summary, width))
  end

  section(lines, "Checks")
  table.insert(lines, "Hunk session     active")
  table.insert(lines, review.showAgentNotes and "Agent notes      visible" or "Agent notes      hidden")
  table.insert(lines, "External checks  not attached")

  return lines
end

local function setup_buffer(buf, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "hunkreviewrail"
  vim.bo[buf].modifiable = true
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

local function style_window(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  vim.wo[win].cursorline = false
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].statuscolumn = ""
  vim.wo[win].wrap = false
  vim.wo[win].winhighlight = "Normal:Normal,EndOfBuffer:Comment"
  vim.wo[win].statusline = " r Refresh %= q Close "
end

function M.refresh(context, opts)
  local options = opts or {}
  local entry = options.entry or rail_by_tab[vim.api.nvim_get_current_tabpage()]
  if not entry or not vim.api.nvim_buf_is_valid(entry.buf) then
    return false
  end

  local hunk = require("config.review.hunk")
  local model, err = hunk.review_model(context, { include_notes = true })
  local lines = model and M.lines(model, { width = entry.width - 2 }) or {
    "Thread    File    Checks",
    string.rep("-", math.min(entry.width - 2, 44)),
    "Hunk context unavailable",
    err or "session is still starting",
  }

  vim.bo[entry.buf].modifiable = true
  vim.api.nvim_buf_set_lines(entry.buf, 0, -1, false, lines)
  vim.bo[entry.buf].modifiable = false
  vim.bo[entry.buf].modified = false
  return model ~= nil
end

function M.open(context, opts)
  local options = opts or {}
  if #vim.api.nvim_list_uis() == 0 then
    return false
  end
  if vim.o.columns < (options.min_columns or 150) then
    return false
  end

  local origin_win = options.origin_win or vim.api.nvim_get_current_win()
  local tab = vim.api.nvim_get_current_tabpage()
  local existing = rail_by_tab[tab]
  if existing and vim.api.nvim_win_is_valid(existing.win) and vim.api.nvim_buf_is_valid(existing.buf) then
    M.refresh(context, { entry = existing })
    if origin_win and vim.api.nvim_win_is_valid(origin_win) then
      pcall(vim.api.nvim_set_current_win, origin_win)
    end
    return true
  end

  local width = math.min(math.max(42, math.floor(vim.o.columns * 0.26)), 54)
  vim.cmd("botright vertical " .. width .. "new")

  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  local entry = { buf = buf, win = win, width = width }
  rail_by_tab[tab] = entry

  pcall(vim.api.nvim_buf_set_name, buf, "hunk-review-rail://" .. tostring(context and context.repo or "repo"))
  setup_buffer(buf, {
    "Thread    File    Checks",
    string.rep("-", math.min(width - 2, 44)),
    "Loading Hunk context",
  })
  style_window(win)

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    rail_by_tab[tab] = nil
    if origin_win and vim.api.nvim_win_is_valid(origin_win) then
      pcall(vim.api.nvim_set_current_win, origin_win)
    end
  end

  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "r", function()
    M.refresh(context, { entry = entry })
  end, { buffer = buf, nowait = true, silent = true })

  vim.defer_fn(function()
    M.refresh(context, { entry = entry })
  end, options.delay or 700)
  vim.defer_fn(function()
    M.refresh(context, { entry = entry })
  end, options.second_delay or 1600)

  if origin_win and vim.api.nvim_win_is_valid(origin_win) then
    pcall(vim.api.nvim_set_current_win, origin_win)
  end

  return true
end

function M.maybe_open(context, opts)
  if vim.g.etabli_review_hunk_rail == false then
    return false
  end
  return M.open(context, opts)
end

return M
