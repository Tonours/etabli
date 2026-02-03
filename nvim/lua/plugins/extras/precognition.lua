-- Precognition: shows virtual text hints for motions
return {
  "tris203/precognition.nvim",
  event = "VeryLazy",
  opts = {
    startVisible = true,
    showBlankVirtLine = true,
    highlightColor = { link = "Comment" },
  },
  keys = {
    { "<leader>up", function() require("precognition").toggle() end, desc = "Toggle Precognition" },
  },
}
