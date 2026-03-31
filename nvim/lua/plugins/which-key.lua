return {
  {
    "folke/which-key.nvim",
    cmd = "WhichKey",
    event = "VeryLazy",
    opts = {
      delay = 300,
      icons = {
        mappings = false,
      },
      preset = "classic",
      spec = {
        { "<leader>a", group = "ADE" },
        { "<leader>f", group = "find" },
        { "<leader>p", group = "project" },
        { "<leader>r", group = "review" },
        { "<leader>s", group = "symbols" },
        { "<leader>d", group = "diagnostics" },
        { "<leader>c", group = "code" },
        { "<leader>m", group = "multi-cursor" },
        { "<leader>b", group = "buffers" },
        { "<leader>w", group = "windows" },
        { "<leader>t", group = "tabs" },
        { "<leader>pW", desc = "New worktree" },
      },
      win = {
        border = "rounded",
      },
    },
  },
}
