return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      delay = 300,
      preset = "modern",
      plugins = {
        spelling = {
          enabled = false,
        },
      },
      spec = {
        { "<leader>b", group = "Buffers" },
        { "<leader>c", group = "Code" },
        { "<leader>d", group = "Diagnostics" },
        { "<leader>f", group = "Files" },
        { "<leader>p", group = "Projects" },
        { "<leader>r", group = "Review" },
        { "<leader>s", group = "Symbols" },
        { "<leader>t", group = "Tabs" },
        { "<leader>w", group = "Windows" },
      },
      win = {
        border = "rounded",
      },
    },
  },
}
