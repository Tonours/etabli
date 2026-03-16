-- TypeScript configuration
return {
  {
    dir = ".",
    name = "typescript-keymaps",
    keys = {
      { "<leader>ci", LazyVim.lsp.action["source.addMissingImports.ts"], desc = "Add Missing Imports" },
      { "<leader>cF", LazyVim.lsp.action["source.fixAll.ts"], desc = "Fix All" },
    },
  },
}
