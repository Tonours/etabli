return {
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "VeryLazy" },
    dependencies = {
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
    },
    config = function()
      local copilot = require("config.copilot")
      local cmp = require("cmp")
      local compare = cmp.config.compare

      local function has_words_before()
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        if col == 0 then
          return false
        end

        local current_line = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
        return current_line:sub(col, col):match("%s") == nil
      end

      cmp.setup({
        completion = {
          completeopt = "menu,menuone,noselect",
        },
        window = {
          completion = cmp.config.window.bordered({
            border = "single",
            winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None",
          }),
          documentation = cmp.config.window.bordered({
            border = "single",
            winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None",
          }),
        },
        experimental = {
          ghost_text = false,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
          ["<A-y>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.complete()
              return
            end

            cmp.complete()
          end, { "i" }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if copilot.accept_inline() then
              return
            elseif cmp.visible() then
              cmp.select_next_item()
            elseif has_words_before() then
              cmp.complete()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        preselect = cmp.PreselectMode.None,
        snippet = {
          expand = function(args)
            vim.snippet.expand(args.body)
          end,
        },
        sources = cmp.config.sources({
          { name = "nvim_lsp", max_item_count = 20 },
          { name = "path", max_item_count = 10 },
        }, {
          { name = "buffer", max_item_count = 10, keyword_length = 3 },
        }),
        formatting = {
          expandable_indicator = true,
        },
        performance = {
          debounce = 25,
          throttle = 8,
          fetching_timeout = 2000,
        },
        sorting = {
          priority_weight = 2,
          comparators = {
            compare.offset,
            compare.exact,
            compare.score,
            compare.recently_used,
            compare.locality,
            compare.kind,
            compare.sort_text,
            compare.length,
            compare.order,
          },
        },
      })

      cmp.setup.filetype("markdown", {
        sources = cmp.config.sources({
          { name = "path", max_item_count = 8 },
        }, {
          { name = "buffer", max_item_count = 8, keyword_length = 5 },
        }),
        performance = {
          debounce = 40,
          throttle = 15,
          fetching_timeout = 120,
        },
      })
    end,
  },
}
