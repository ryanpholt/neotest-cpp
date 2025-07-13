#!/usr/bin/env -S nvim -l

vim.env.LAZY_STDPATH = ".tests"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

vim.o.swapfile = false
vim.o.backup = false
vim.o.undofile = false

require("lazy.minit").busted({
  spec = {
    {
      "nvim-neotest/neotest",
      lazy = false,
      dependencies = {
        {
          dir = vim.fn.getcwd(),
          name = "neotest-cpp",
          lazy = false,
        },
      },
      {
        "nvim-lua/plenary.nvim",
        lazy = false,
      },
      {
        "nvim-neotest/nvim-nio",
        lazy = false,
      },
      {
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        config = function()
          require("nvim-treesitter.configs").setup({
            ensure_installed = { "cpp" },
            sync_install = true,
          })
        end,
      },
      {
        "mfussenegger/nvim-dap",
        lazy = false,
        config = function()
          local ok, dap = pcall(require, "dap")
          if not ok then
            return
          end
          dap.adapters.lldb = {
            type = "executable",
            command = "/Library/Developer/CommandLineTools/usr/bin/lldb-dap",
            name = "lldb",
          }
        end,
      },
    },
  },
})
