-- Lualine config - aligned with tmux Catppuccin
return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function()
      local colors = {
        bg = "#1e1e2e", -- base
        fg = "#cdd6f4", -- text
        surface0 = "#313244",
        surface1 = "#45475a",
        overlay0 = "#6c7086",
        mauve = "#cba6f7",
        blue = "#89b4fa",
        sapphire = "#74c7ec",
        green = "#a6e3a1",
        yellow = "#f9e2af",
        peach = "#fab387",
        red = "#f38ba8",
      }

      -- Theme minimaliste style tmux
      local theme = {
        normal = {
          a = { fg = colors.bg, bg = colors.mauve, gui = "bold" },
          b = { fg = colors.fg, bg = colors.surface1 },
          c = { fg = colors.overlay0, bg = colors.bg },
        },
        insert = {
          a = { fg = colors.bg, bg = colors.green, gui = "bold" },
        },
        visual = {
          a = { fg = colors.bg, bg = colors.blue, gui = "bold" },
        },
        replace = {
          a = { fg = colors.bg, bg = colors.red, gui = "bold" },
        },
        command = {
          a = { fg = colors.bg, bg = colors.peach, gui = "bold" },
        },
        inactive = {
          a = { fg = colors.overlay0, bg = colors.surface0 },
          b = { fg = colors.overlay0, bg = colors.bg },
          c = { fg = colors.overlay0, bg = colors.bg },
        },
      }

      return {
        options = {
          theme = theme,
          globalstatus = true,
          component_separators = { left = "│", right = "│" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = {
            statusline = { "dashboard", "alpha", "starter" },
          },
        },
        sections = {
          lualine_a = {
            { "mode", fmt = function(str) return str:sub(1, 1) end },
          },
          lualine_b = {
            { "branch", icon = "" },
          },
          lualine_c = {
            { "filename", path = 1, symbols = { modified = " ●", readonly = " ", unnamed = "" } },
          },
          lualine_x = {
            {
              "diagnostics",
              symbols = { error = " ", warn = " ", info = " ", hint = " " },
            },
          },
          lualine_y = {
            { "filetype", icon_only = true },
            { "progress" },
          },
          lualine_z = {
            { "location" },
          },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
      }
    end,
  },
}
