local parser_by_filetype = {
  astro = { "astro" },
  bash = { "bash" },
  css = { "css" },
  graphql = { "graphql" },
  hbs = { "glimmer" },
  handlebars = { "glimmer" },
  html = { "html" },
  ["html.handlebars"] = { "glimmer" },
  javascript = { "javascript" },
  javascriptreact = { "tsx" },
  ["javascript.glimmer"] = { "glimmer" },
  json = { "json" },
  lua = { "lua" },
  markdown = { "markdown", "markdown_inline" },
  php = { "php" },
  scss = { "scss" },
  typescript = { "typescript" },
  typescriptreact = { "tsx" },
  ["typescript.glimmer"] = { "glimmer" },
  yaml = { "yaml" },
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    version = "4916d6592ede",
    event = { "BufReadPre", "BufNewFile" },
    cmd = { "TSUpdate", "TSInstall", "TSLog", "TSUninstall" },
    build = ":TSUpdate",
    init = function()
      vim.filetype.add({
        extension = {
          astro = "astro",
          hbs = "handlebars",
        },
      })
    end,
    config = function()
      local treesitter = require("nvim-treesitter")
      local install_pending = {}
      local waiting_buffers = {}

      vim.treesitter.language.register("glimmer", { "hbs", "handlebars", "html.handlebars" })

      local function missing_parsers(parsers)
        local installed = {}
        for _, parser in ipairs(treesitter.get_installed("parsers")) do
          installed[parser] = true
        end

        return vim.tbl_filter(function(parser)
          return not installed[parser]
        end, parsers)
      end

      local function start_treesitter(bufnr, parser)
        if not vim.api.nvim_buf_is_valid(bufnr) or vim.b[bufnr].large_file then
          return false
        end

        return pcall(vim.treesitter.start, bufnr, parser)
      end

      local function restart_waiting_buffers()
        for bufnr, parsers in pairs(waiting_buffers) do
          if not vim.api.nvim_buf_is_valid(bufnr) then
            waiting_buffers[bufnr] = nil
          elseif #missing_parsers(parsers) == 0 then
            waiting_buffers[bufnr] = nil
            start_treesitter(bufnr, parsers[1])
          end
        end
      end

      local function install_missing_parsers(parsers, bufnr)
        local missing = missing_parsers(parsers)
        if #missing == 0 then
          return
        end

        waiting_buffers[bufnr] = parsers

        local to_install = vim.tbl_filter(function(parser)
          return not install_pending[parser]
        end, missing)
        if #to_install == 0 then
          return
        end

        for _, parser in ipairs(to_install) do
          install_pending[parser] = true
        end

        vim.schedule(function()
          local ok, task = pcall(treesitter.install, to_install, { max_jobs = 1, summary = true })
          if not ok or not task or type(task.await) ~= "function" then
            for _, parser in ipairs(to_install) do
              install_pending[parser] = nil
            end
            vim.notify("Tree-sitter parser install could not be started", vim.log.levels.WARN)
            return
          end

          task:await(function(err, installed)
            vim.schedule(function()
              for _, parser in ipairs(to_install) do
                install_pending[parser] = nil
              end

              if err or installed == false then
                vim.notify("Tree-sitter parser install failed: " .. tostring(err or "unknown error"), vim.log.levels.WARN)
                return
              end

              restart_waiting_buffers()
            end)
          end)
        end)
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("etabli_treesitter", { clear = true }),
        pattern = vim.tbl_keys(parser_by_filetype),
        callback = function(args)
          local parsers = parser_by_filetype[vim.bo[args.buf].filetype]
          if not parsers or vim.b[args.buf].large_file or start_treesitter(args.buf, parsers[1]) then
            return
          end

          install_missing_parsers(parsers, args.buf)
        end,
      })

      vim.api.nvim_create_autocmd("BufReadPost", {
        group = vim.api.nvim_create_augroup("etabli_treesitter_large_files", { clear = true }),
        callback = function(args)
          if vim.b[args.buf].large_file then
            vim.treesitter.stop(args.buf)
          end
        end,
      })
    end,
  },
}
