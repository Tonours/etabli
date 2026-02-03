-- AI pair programming plugins
return {
  -- Folke Sidekick
  {
    "folke/sidekick.nvim",
    keys = {
      { "<leader>aa", "<cmd>Sidekick<cr>", desc = "Sidekick Toggle" },
      { "<leader>ac", "<cmd>SidekickChat<cr>", desc = "Sidekick Chat" },
      { "<leader>as", "<cmd>SidekickSwitch<cr>", desc = "Sidekick Switch" },
    },
    opts = {},
  },
}
