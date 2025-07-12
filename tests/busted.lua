#!/usr/bin/env -S nvim -l

vim.env.LAZY_STDPATH = ".tests"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

vim.o.swapfile = false
vim.o.backup = false
vim.o.undofile = false

require("lazy.minit").busted({
  spec = {
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
      "nvim-neotest/neotest",
      lazy = false,
    },
    {
      "mfussenegger/nvim-dap",
      lazy = false,
    },
    {
      dir = vim.fn.getcwd(),
      name = "neotest-cpp",
      lazy = false,
      opts = {
        executables = {
          patterns = { "tests/integration/cpp/build/**" },
          cwd = function(_)
            return "tests/integration/cpp"
          end,
          debug = {
            dap_template = function(executable)
              return {
                name = "Debug with neotest-gtest",
                type = "lldb",
                request = "launch",
                program = executable,
                args = "${arguments}",
                cwd = "${cwd}",
                env = "${env}",
                preRunCommands = {},
              }
            end,
          },
        },
        gtest = {
          test_prefixes = {
            "RH_",
            "XY_",
          },
        },
      },
    },
  },
})
