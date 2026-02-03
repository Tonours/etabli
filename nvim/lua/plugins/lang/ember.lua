-- Ember.js / Glimmer / Handlebars support
return {
  -- Treesitter: Add Glimmer parser for .hbs files
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        "glimmer", -- Handlebars/Glimmer templates
        "html",
      })
    end,
  },

  -- vim-ember-hbs: Enhanced Handlebars syntax highlighting
  {
    "joukevandermaas/vim-ember-hbs",
    ft = { "handlebars", "html.handlebars", "hbs" },
  },

  -- LSP Configuration for Ember
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Ember Language Server for navigation, completions
        ember = {
          cmd = { "ember-language-server", "--stdio" },
          filetypes = { "handlebars", "typescript", "javascript" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern(
              "ember-cli-build.js",
              ".ember-cli",
              "package.json"
            )(fname)
          end,
        },
        -- Glint for typed Ember templates (if project uses Glint)
        glint = {
          cmd = { "glint-language-server" },
          filetypes = { "handlebars", "typescript", "javascript", "typescript.glimmer", "javascript.glimmer" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern(
              "glint.config.ts",
              "glint.config.js",
              ".glintrc.yml",
              ".glintrc",
              ".glintrc.json",
              "ember-cli-build.js",
              "package.json"
            )(fname)
          end,
        },
      },
      setup = {
        -- ember-template-lint integration via null-ls/none-ls would go here
        -- For now, we rely on eslint with ember plugins
      },
    },
  },

  -- Mason: ensure LSP servers are installed
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "ember-language-server",
        "html-lsp",
        "css-lsp",
      })
    end,
  },

  -- File type detection and settings for Ember
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      -- Register .hbs as handlebars filetype
      vim.filetype.add({
        extension = {
          hbs = "handlebars",
        },
        pattern = {
          [".*%.hbs"] = "handlebars",
        },
      })

      -- Ember file patterns
      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = { "*.hbs" },
        callback = function()
          vim.bo.filetype = "handlebars"
        end,
      })
      return opts
    end,
  },

  -- Add colorizer support for handlebars
  {
    "norcalli/nvim-colorizer.lua",
    opts = function(_, opts)
      opts = opts or {}
      opts.filetypes = opts.filetypes or {}
      vim.list_extend(opts.filetypes, { "handlebars", "hbs" })
      return opts
    end,
  },

  -- Which-key: Ember-specific keybindings group
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>E", group = "Ember", icon = "🐹" },
      },
    },
  },

  -- Ember keymaps (moved from config/keymaps.lua)
  {
    dir = ".",
    name = "ember-keymaps",
    keys = {
      -- Navigate between component files (template <-> class)
      {
        "<leader>Et",
        function()
          local file = vim.fn.expand("%:t")
          local dir = vim.fn.expand("%:p:h")
          local base = vim.fn.expand("%:t:r")

          if file:match("%.hbs$") then
            -- From template to component class
            local patterns = {
              dir .. "/" .. base .. ".ts",
              dir .. "/" .. base .. ".js",
              dir:gsub("/templates?", "") .. "/" .. base .. ".ts",
              dir:gsub("/templates?", "") .. "/" .. base .. ".js",
              dir:gsub("/templates?", "/components") .. "/" .. base .. ".ts",
              dir:gsub("/templates?", "/components") .. "/" .. base .. ".js",
            }
            for _, path in ipairs(patterns) do
              if vim.fn.filereadable(path) == 1 then
                vim.cmd("edit " .. vim.fn.fnameescape(path))
                return
              end
            end
            vim.notify("Component class not found", vim.log.levels.WARN)
          else
            -- From class to template
            local patterns = {
              dir .. "/" .. base .. ".hbs",
              dir:gsub("/components?", "/templates") .. "/" .. base .. ".hbs",
              dir .. "/template.hbs",
            }
            for _, path in ipairs(patterns) do
              if vim.fn.filereadable(path) == 1 then
                vim.cmd("edit " .. vim.fn.fnameescape(path))
                return
              end
            end
            vim.notify("Template not found", vim.log.levels.WARN)
          end
        end,
        desc = "Toggle Template/Class",
      },

      -- Run ember-template-lint on current file
      {
        "<leader>El",
        function()
          local file = vim.fn.expand("%:p")
          if file:match("%.hbs$") then
            vim.cmd("!ember-template-lint " .. vim.fn.shellescape(file))
          else
            vim.notify("Not a .hbs file", vim.log.levels.WARN)
          end
        end,
        desc = "Ember Template Lint",
      },

      -- Search Ember components
      {
        "<leader>Ec",
        function()
          require("telescope.builtin").find_files({
            prompt_title = "Ember Components",
            search_dirs = { "app/components", "addon/components" },
          })
        end,
        desc = "Find Components",
      },

      -- Search Ember routes
      {
        "<leader>Er",
        function()
          require("telescope.builtin").find_files({
            prompt_title = "Ember Routes",
            search_dirs = { "app/routes", "app/controllers", "app/templates" },
          })
        end,
        desc = "Find Routes",
      },

      -- Search Ember services
      {
        "<leader>Es",
        function()
          require("telescope.builtin").find_files({
            prompt_title = "Ember Services",
            search_dirs = { "app/services", "addon/services" },
          })
        end,
        desc = "Find Services",
      },

      -- Search Ember helpers
      {
        "<leader>Eh",
        function()
          require("telescope.builtin").find_files({
            prompt_title = "Ember Helpers",
            search_dirs = { "app/helpers", "addon/helpers" },
          })
        end,
        desc = "Find Helpers",
      },

      -- Search Ember models
      {
        "<leader>Em",
        function()
          require("telescope.builtin").find_files({
            prompt_title = "Ember Models",
            search_dirs = { "app/models", "addon/models" },
          })
        end,
        desc = "Find Models",
      },

      -- Run Ember test for current file
      {
        "<leader>ET",
        function()
          local filter = vim.fn.shellescape(vim.fn.expand("%:t:r"))
          vim.cmd("vsplit term://ember test --filter=" .. filter)
        end,
        desc = "Ember Test Current",
      },
    },
  },
}
