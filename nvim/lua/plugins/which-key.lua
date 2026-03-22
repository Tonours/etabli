return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      delay = 300,
      icons = {
        mappings = false,
      },
      preset = "classic",
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>p", group = "project" },
        { "<leader>r", group = "refactor" },
        { "<leader>s", group = "symbols" },
        { "<leader>d", group = "diagnostics" },
        { "<leader>c", group = "code" },
        { "<leader>m", group = "multi-cursor" },
        { "<leader>b", group = "buffers" },
        { "<leader>w", group = "windows" },
        { "<leader>t", group = "tabs" },
      },
      win = {
        border = "rounded",
      },
    },
  },
}
