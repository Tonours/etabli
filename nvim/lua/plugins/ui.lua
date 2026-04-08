return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    opts = {
      flavour = "mocha",
      integrations = {
        mason = false,
        telescope = false,
        treesitter = false,
      },
      custom_highlights = function(colors)
        return {
          DiagnosticSignError = { fg = colors.red, bg = colors.base },
          DiagnosticSignWarn = { fg = colors.yellow, bg = colors.base },
          DiagnosticSignInfo = { fg = colors.sky, bg = colors.base },
          DiagnosticSignHint = { fg = colors.teal, bg = colors.base },
          DiagnosticFloatingError = { fg = colors.red },
          DiagnosticFloatingWarn = { fg = colors.yellow },
          DiagnosticFloatingInfo = { fg = colors.sky },
          DiagnosticFloatingHint = { fg = colors.teal },
          NormalFloat = { bg = colors.mantle },
          FloatBorder = { fg = colors.surface1, bg = colors.mantle },
          TelescopeNormal = { bg = colors.base },
          TelescopeBorder = { fg = colors.surface1, bg = colors.base },
          TelescopePromptBorder = { fg = colors.blue, bg = colors.mantle },
          TelescopePromptNormal = { bg = colors.mantle },
          TelescopePromptPrefix = { fg = colors.blue, bg = colors.mantle },
          TelescopePreviewNormal = { bg = colors.base },
          TelescopeResultsNormal = { bg = colors.base },
          TelescopeSelection = { fg = colors.text, bg = colors.surface0, bold = true },
          TelescopeMatching = { fg = colors.lavender, bold = true },
          NvimTreeNormal = { bg = colors.base },
          NvimTreeNormalNC = { bg = colors.base },
          NvimTreeRootFolder = { fg = colors.peach, bold = true },
          NvimTreeFolderName = { fg = colors.text },
          NvimTreeOpenedFolderName = { fg = colors.peach, bold = true },
          NvimTreeOpenedFile = { fg = colors.peach, bold = true },
          NvimTreeSpecialFile = { fg = colors.mauve, underline = true },
          NvimTreeIndentMarker = { fg = colors.surface1 },
          WinSeparator = { fg = colors.surface1 },
          NvimTreeWinSeparator = { fg = colors.surface1, bg = colors.base },
        }
      end,
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "UIEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      local statusline = require("config.statusline")

      local function ops_label()
        local ops = package.loaded["config.ops"]
        return ops and ops.statusline_label() or ""
      end

      local function ops_color()
        local ops = package.loaded["config.ops"]
        return ops and ops.statusline_color() or {}
      end

      return {
        options = {
          theme = "catppuccin-mocha",
          globalstatus = true,
          component_separators = { left = "▓", right = "▒" },
          section_separators = { left = "█", right = "█" },
          -- Performance: reduce refresh frequency
          refresh = {
            statusline = 1000,
            tabline = 5000,
            winbar = 5000,
          },
        },
        sections = {
          lualine_a = {
            {
              "mode",
              fmt = function(str)
                return "█ " .. str
              end,
            },
          },
          lualine_b = {
            {
              "branch",
              icon = "▛",
            },
            {
              statusline.project_label,
              color = statusline.project_color,
            },
          },
          lualine_c = {
            {
              "filename",
              path = 1,
              symbols = {
                modified = " ●",
                readonly = " ",
                unnamed = "[No Name]",
              },
            },
          },
          lualine_x = {
            {
              ops_label,
              color = ops_color,
              cond = function()
                return ops_label() ~= ""
              end,
            },
            "diagnostics",
          },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      }
    end,
    config = function(_, opts)
      require("lualine").setup(opts)
      require("config.lualine_notices").patch()
    end,
  },
}
