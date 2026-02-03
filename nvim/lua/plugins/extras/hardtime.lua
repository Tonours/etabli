-- Hardtime: disable bad habits but allow arrows in insert mode
return {
  {
    "m4xshen/hardtime.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
    opts = {
      -- Allow arrow keys in insert mode only
      disabled_keys = {
        ["<Up>"] = { "n", "v" },
        ["<Down>"] = { "n", "v" },
        ["<Left>"] = { "n", "v" },
        ["<Right>"] = { "n", "v" },
      },
    },
    keys = {
      { "<leader>uh", "<cmd>Hardtime toggle<cr>", desc = "Toggle Hardtime" },
    },
  },
}
