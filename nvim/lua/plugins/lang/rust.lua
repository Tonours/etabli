-- Rust development configuration for LazyVim
return {
  -- Treesitter: Rust parser
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        "rust",
        "toml",
      })
    end,
  },

  -- LSP: rust-analyzer
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
                runBuildScripts = true,
              },
              checkOnSave = {
                allFeatures = true,
                command = "clippy",
                extraArgs = { "--no-deps" },
              },
              procMacro = {
                enable = true,
                ignored = {
                  ["async-trait"] = { "async_trait" },
                  ["napi-derive"] = { "napi" },
                  ["async-recursion"] = { "async_recursion" },
                },
              },
              inlayHints = {
                bindingModeHints = { enable = false },
                chainingHints = { enable = true },
                closingBraceHints = { enable = true, minLines = 25 },
                closureReturnTypeHints = { enable = "never" },
                lifetimeElisionHints = { enable = "never", useParameterNames = false },
                maxLength = 25,
                parameterHints = { enable = true },
                reborrowHints = { enable = "never" },
                renderColons = true,
                typeHints = {
                  enable = true,
                  hideClosureInitialization = false,
                  hideNamedConstructor = false,
                },
              },
            },
          },
        },
        taplo = {}, -- TOML LSP for Cargo.toml
      },
    },
  },

  -- Formatting with rustfmt
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        rust = { "rustfmt" },
        toml = { "taplo" },
      },
    },
  },

  -- Crates.nvim for Cargo.toml dependency management
  {
    "saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("crates").setup({
        popup = {
          autofocus = true,
          border = "rounded",
        },
        lsp = {
          enabled = true,
          actions = true,
          completion = true,
          hover = true,
        },
      })
    end,
    keys = {
      { "<leader>rct", function() require("crates").toggle() end, desc = "Toggle Crates" },
      { "<leader>rcr", function() require("crates").reload() end, desc = "Reload Crates" },
      { "<leader>rcv", function() require("crates").show_versions_popup() end, desc = "Show Versions" },
      { "<leader>rcf", function() require("crates").show_features_popup() end, desc = "Show Features" },
      { "<leader>rcd", function() require("crates").show_dependencies_popup() end, desc = "Show Dependencies" },
      { "<leader>rcu", function() require("crates").update_crate() end, desc = "Update Crate" },
      { "<leader>rcU", function() require("crates").upgrade_crate() end, desc = "Upgrade Crate" },
      { "<leader>rca", function() require("crates").update_all_crates() end, desc = "Update All" },
      { "<leader>rcA", function() require("crates").upgrade_all_crates() end, desc = "Upgrade All" },
    },
  },

  -- Debugging with codelldb
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")
      if not dap.adapters["codelldb"] then
        dap.adapters["codelldb"] = {
          type = "server",
          host = "localhost",
          port = "${port}",
          executable = {
            command = "codelldb",
            args = { "--port", "${port}" },
          },
        }
      end
      for _, lang in ipairs({ "c", "cpp", "rust" }) do
        dap.configurations[lang] = dap.configurations[lang] or {}
        table.insert(dap.configurations[lang], {
          type = "codelldb",
          request = "launch",
          name = "Launch file",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
          end,
          cwd = "${workspaceFolder}",
        })
      end
    end,
  },

  -- Which-key group for Rust/Crates
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>rc", group = "crates", icon = "📦" },
      },
    },
  },
}
