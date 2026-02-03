-- TypeScript configuration
return {
  -- TypeScript-specific keymaps
  {
    dir = ".",
    name = "typescript-keymaps",
    keys = {
      { "<leader>co", "<cmd>TSToolsOrganizeImports<cr>", desc = "Organize Imports" },
      { "<leader>ci", "<cmd>TSToolsAddMissingImports<cr>", desc = "Add Missing Imports" },
      { "<leader>cu", "<cmd>TSToolsRemoveUnused<cr>", desc = "Remove Unused" },
      { "<leader>cF", "<cmd>TSToolsFixAll<cr>", desc = "Fix All" },
    },
  },
}
