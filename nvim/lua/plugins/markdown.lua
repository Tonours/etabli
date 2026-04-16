return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      file_types = { "markdown" },
      render_modes = { "n", "c", "t" },
      debounce = 75,
      heading = {
        position = "inline",
      },
      code = {
        sign = false,
        width = "block",
      },
      bullet = {
        enabled = true,
      },
      checkbox = {
        enabled = true,
      },
    },
  },
}
