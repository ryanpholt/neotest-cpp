#!/usr/bin/env -S nvim -l

vim.cmd([[let &rtp.=','.getcwd()]])

vim.cmd("set rtp+=deps/neotest")
vim.cmd("set rtp+=deps/nvim-nio")
vim.cmd("set rtp+=deps/nvim-treesitter")
vim.cmd("set rtp+=deps/nvim-dap")
vim.cmd("set rtp+=deps/mini.nvim")
vim.cmd("set rtp+=deps/plenary.nvim")


require("nvim-treesitter.configs").setup({
  ensure_installed = { "cpp" },
  sync_install = true,
})

local ok, dap = pcall(require, "dap")
if not ok then
  return
end
dap.adapters.lldb = {
  type = "executable",
  command = "/Library/Developer/CommandLineTools/usr/bin/lldb-dap",
  name = "lldb",
}
require("mini.test").setup()
