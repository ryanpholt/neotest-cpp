# Run all test files
test: deps
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run test from file at `$FILE` environment variable
test_file: deps
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

.PHONY: deps
deps: deps/neotest deps/nvim-nio deps/nvim-treesitter deps/mini.nvim deps/nvim-dap deps/plenary.nvim

deps/neotest:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/nvim-neotest/neotest.git $@

deps/nvim-nio:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/nvim-neotest/nvim-nio $@

deps/nvim-treesitter:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/nvim-treesitter/nvim-treesitter.git $@

deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/echasnovski/mini.nvim $@

deps/nvim-dap:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/mfussenegger/nvim-dap.git $@

deps/plenary.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/nvim-lua/plenary.nvim.git $@
