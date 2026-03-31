return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
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
          TelescopeBorder = { fg = colors.surface1, bg = colors.base },
          TelescopePromptBorder = { fg = colors.blue, bg = colors.mantle },
          TelescopePromptNormal = { bg = colors.mantle },
          TelescopePromptPrefix = { fg = colors.blue, bg = colors.mantle },
          TelescopeResultsNormal = { bg = colors.base },
          TelescopeSelection = { fg = colors.text, bg = colors.surface0, bold = true },
          TelescopeMatching = { fg = colors.lavender, bold = true },
          NvimTreeNormal = { bg = colors.base },
          NvimTreeNormalNC = { bg = colors.base },
          NvimTreeRootFolder = { fg = colors.blue, bold = true },
          NvimTreeFolderName = { fg = colors.text },
          NvimTreeOpenedFolderName = { fg = colors.blue, bold = true },
          NvimTreeOpenedFile = { fg = colors.lavender, bold = true },
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
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      -- Lazy-load statusline module only when lualine initializes
      local statusline = require("config.statusline")
      return {
        options = {
          theme = "catppuccin-mocha",
          globalstatus = true,
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          -- Performance: reduce refresh frequency
          refresh = {
            statusline = 1000,  -- Refresh every 1000ms (was 750ms)
            tabline = 5000,     -- Refresh every 5000ms (was 3000ms)
            winbar = 5000,      -- Refresh every 5000ms (was 3000ms)
          },
        },
        sections = {
          lualine_a = {
            {
              "mode",
              fmt = function(str)
                return " " .. str
              end,
            },
          },
          lualine_b = {
            {
              "branch",
              icon = "",
            },
            {
              statusline.worktree_label,
              cond = statusline.has_worktree,
              color = statusline.worktree_color,
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
              function()
                return require("config.ade").statusline_label()
              end,
              color = function()
                return require("config.ade").statusline_color()
              end,
              cond = function()
                return require("config.ade").statusline_label() ~= ""
              end,
            },
            "diagnostics",
          },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      }
    end,
  },
}
