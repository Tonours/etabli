local function open_grug_far_overlay()
  local max_width = math.max(vim.o.columns - 4, 20)
  local max_height = math.max(vim.o.lines - 4, 8)
  local width = math.min(math.max(math.floor(vim.o.columns * 0.72), 72), math.min(140, max_width))
  local height = math.min(math.max(math.floor(vim.o.lines * 0.78), 16), math.min(40, max_height))
  local row = math.max(math.floor((vim.o.lines - height) * 0.5 - 1), 1)
  local col = math.max(math.floor((vim.o.columns - width) * 0.5), 0)

  return vim.api.nvim_open_win(0, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Find & Replace ",
    title_pos = "center",
    zindex = 90,
  })
end

return {
  {
    "MagicDuck/grug-far.nvim",
    config = function()
      local grug_far = require("grug-far")
      local original_create_window = grug_far._createWindow

      grug_far.setup({
        debounceMs = 200,
        minSearchChars = 1,
        showCompactInputs = false,
        showInputsTopPadding = false,
        startInInsertMode = true,
        transient = true,
        windowCreationCommand = "keepalt botright 1new",
        keymaps = {
          close = { n = "q" },
          help = { n = "?" },
          replace = { n = "<leader>R" },
          nextInput = "<Tab>",
          prevInput = "<S-Tab>",
        },
      })

      grug_far._createWindow = function(context)
        local prev_win = vim.api.nvim_get_current_win()
        local prev_buf = vim.api.nvim_win_get_buf(prev_win)
        local ok, win = pcall(open_grug_far_overlay)

        if ok and win and vim.api.nvim_win_is_valid(win) then
          context.prevWin = prev_win
          context.prevBufName = vim.api.nvim_buf_get_name(prev_buf)
          context.prevBufFiletype = vim.bo[prev_buf].filetype
          context.initialWin = win
          return win
        end

        if type(original_create_window) == "function" then
          return original_create_window(context)
        end

        error("grug-far window creation unavailable")
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "grug-far",
        callback = function(event)
          local win = vim.fn.bufwinid(event.buf)
          if win == -1 then
            return
          end

          vim.bo[event.buf].buflisted = false
          vim.wo[win].cursorline = false
          vim.wo[win].number = false
          vim.wo[win].relativenumber = false
          vim.wo[win].signcolumn = "no"
          vim.wo[win].spell = false
          vim.wo[win].winhl = "NormalFloat:Normal,FloatBorder:FloatBorder,FloatTitle:Title"
        end,
      })
    end,
  },
}
