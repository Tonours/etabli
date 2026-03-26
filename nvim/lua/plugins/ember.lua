local function enable_handlebars_syntax(bufnr)
  vim.treesitter.stop(bufnr)

  vim.api.nvim_buf_call(bufnr, function()
    vim.b.current_syntax = nil
    vim.bo.syntax = "handlebars"
    vim.cmd("runtime! syntax/handlebars.vim")
  end)
end

return {
  {
    "joukevandermaas/vim-ember-hbs",
    ft = { "handlebars", "html.handlebars" },
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "handlebars", "html.handlebars" },
        callback = function(args)
          enable_handlebars_syntax(args.buf)
        end,
      })

      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr)
          and (vim.bo[bufnr].filetype == "handlebars" or vim.bo[bufnr].filetype == "html.handlebars")
        then
          enable_handlebars_syntax(bufnr)
        end
      end
    end,
  },
}
