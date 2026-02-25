-- Git workflow plugins
return {
  -- Git worktree navigation
  {
    "ThePrimeagen/git-worktree.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      require("git-worktree").setup()
      require("telescope").load_extension("git_worktree")
    end,
    keys = {
      {
        "<leader>gw",
        function()
          require("telescope").extensions.git_worktree.git_worktrees()
        end,
        desc = "Switch worktree",
      },
      {
        "<leader>gW",
        function()
          require("telescope").extensions.git_worktree.create_git_worktree()
        end,
        desc = "Create worktree",
      },
    },
  },

  -- Diff view for code review
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff view" },
      { "<leader>gD", "<cmd>DiffviewOpen HEAD~1<cr>", desc = "Diff vs last commit" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
    },
  },

  -- Keymap to open AGENTS.md
  {
    dir = ".",
    name = "agent-keymaps",
    keys = {
      {
        "<leader>cm",
        function()
          local agents_md = vim.fn.findfile("AGENTS.md", vim.fn.getcwd() .. ";")
          if agents_md ~= "" then
            vim.cmd("edit " .. vim.fn.fnameescape(agents_md))
          else
            vim.notify("AGENTS.md not found", vim.log.levels.WARN)
          end
        end,
        desc = "Edit AGENTS.md",
      },
    },
  },
}
