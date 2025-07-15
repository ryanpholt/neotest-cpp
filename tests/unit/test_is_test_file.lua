local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua_func(function()
        require("tests.helpers").setup_neotest({})
      end)
    end,
    post_case = function()
      child.stop()
    end,
  },
})

local is_test_file = function(path_)
  return child.lua_func(function(path)
    return require("neotest-cpp").is_test_file(path)
  end, path_)
end

T["should return true for C++ test files"] = function()
  eq(is_test_file("/path/to/test_file.cpp"), true)
  eq(is_test_file("/path/to/file_test.cxx"), true)
  eq(is_test_file("/path/to/file_test.cc"), true)
end

T["should return false for non-C++ files"] = function()
  eq(is_test_file("/path/to/file.c"), false)
  eq(is_test_file("/path/to/file.h"), false)
  eq(is_test_file("/path/to/file.hpp"), false)
  eq(is_test_file("/path/to/file.py"), false)
  eq(is_test_file("/path/to/file.txt"), false)
end

return T
