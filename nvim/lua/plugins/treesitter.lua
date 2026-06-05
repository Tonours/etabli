local pending_installs = {}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    init = function()
      -- Batch filetype registrations for better performance
      vim.filetype.add({
        extension = {
          astro = "astro",
          hbs = "handlebars",
        },
      })

      -- Register glimmer for handlebars variants
      vim.treesitter.language.register("glimmer", { "hbs", "handlebars", "html.handlebars" })

      -- Defer markdown parser registration to not block file opening
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        once = true,
        callback = function(args)
          -- Defer markdown parser loading by 50ms to prioritize editing
          vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(args.buf) and vim.bo[args.buf].filetype == "markdown" then
              pcall(vim.treesitter.start, args.buf, "markdown")
            end
          end, 50)
        end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "astro",
          "bash",
          "css",
          "graphql",
          "html.handlebars",
          "handlebars",
          "hbs",
          "html",
          "javascript",
          "javascriptreact",
          "json",
          "lua",
          "markdown",
          "php",
          "scss",
          "yaml",
        },
        callback = function(args)
          if vim.b[args.buf].large_file then
            return
          end
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
    config = function()
      local languages = {
        "bash", "css", "glimmer", "graphql", "html", "javascript",
        "json", "lua", "markdown", "markdown_inline", "php", "scss",
        "tsx", "typescript", "yaml",
      }
      local treesitter = require("nvim-treesitter")

      local installed = {}
      for _, language in ipairs(treesitter.get_installed()) do
        installed[language] = true
      end

      local missing = vim.tbl_filter(function(language)
        return not installed[language]
      end, languages)

      if #missing > 0 then
        vim.schedule(function()
          local ok, task = pcall(treesitter.install, missing, { summary = true })
          if not ok or not task or not task.await then
            vim.notify("Treesitter parser install could not be started", vim.log.levels.WARN)
            return
          end

          table.insert(pending_installs, task)
          task:await(function(err)
            for index, pending in ipairs(pending_installs) do
              if pending == task then
                table.remove(pending_installs, index)
                break
              end
            end

            if err then
              vim.schedule(function()
                vim.notify("Treesitter parser install failed: " .. tostring(err), vim.log.levels.WARN)
              end)
            end
          end)
        end)
      end

      local function start_treesitter(args, lang)
        if vim.b[args.buf].large_file then
          return
        end

        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(args.buf) then
            pcall(vim.treesitter.start, args.buf, lang)
          end
        end)
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "typescript", "typescriptreact" },
        callback = function(args)
          local lang = vim.bo[args.buf].filetype == "typescriptreact" and "tsx" or "typescript"
          start_treesitter(args, lang)
        end,
      })

      -- Performance: Disable treesitter for large files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "javascript.glimmer", "typescript.glimmer" },
        callback = function(args)
          start_treesitter(args, "glimmer")
        end,
      })

      -- Disable treesitter highlight for large files
      vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function(args)
          if vim.b[args.buf].large_file then
            vim.treesitter.stop(args.buf)
          end
        end,
      })
    end,
  },
}
