local adapter
local nio = require("nio")
local types = require("neotest.types")
local utils = require("tests.utils")

describe("build_spec", function()
  setup(function()
    -- selene: allow(global_usage)
    _G._TEST = true
  end)

  teardown(function()
    -- selene: allow(global_usage)
    _G._TEST = nil
  end)

  before_each(function()
    utils.setup_neotest({
      executables = {
        patterns = { "tests/integration/cpp/build/**" },
        cwd = function(_)
          return "tests/integration/cpp"
        end,
      },
      gtest = {
        test_prefixes = {
          "RH_",
          "XY_",
        },
      },
    })
    adapter = require("neotest-cpp.adapter")
  end)

  local function build_spec(mock_positions, strategy)
    local mock_tree = require("neotest.types.tree").from_list(mock_positions, function(x)
      return x.id
    end)
    local args = {
      tree = mock_tree,
      strategy = strategy,
    }
    local spec = nio.tests.with_async_context(adapter.build_spec, args)
    return vim.inspect(spec)
  end

  it("should create a valid run spec for a test", function()
    local mock_position = {
      {
        id = "/path/to/test.cpp::TestSuite::TestCase",
        name = "TestCase",
        type = types.PositionType.test,
        path = "/path/to/test.cpp",
        file = "/path/to/test.cpp",
        suite = "TestSuite",
        executable = "/path/to/test_executable",
      },
    }

    local expected = [[
      {
        command = { "/path/to/test_executable", "--gtest_filter=TestSuite.TestCase", "--gtest_output=json:/tmp/neotest-cpp-results" },
        context = {
          non_existent_tests = {},
          results_path = "/tmp/neotest-cpp-results"
        },
        cwd = "tests/integration/cpp"
      }
    ]]

    local expected_with_dap = [[
    {
      command = { "/path/to/test_executable", "--gtest_filter=TestSuite.TestCase", "--gtest_output=json:/tmp/neotest-cpp-results",
                  "--gtest_color=no", "--gtest_break_on_failure" },
      context = {
        non_existent_tests = {},
        results_path = "/tmp/neotest-cpp-results"
      },
      cwd = "tests/integration/cpp",
      strategy = {
        args = { "--gtest_filter=TestSuite.TestCase", "--gtest_output=json:/tmp/neotest-cpp-results", "--gtest_color=no",
                 "--gtest_break_on_failure" },
        cwd = "tests/integration/cpp",
        name = "Debug with neotest-cpp",
        program = "/path/to/test_executable",
        request = "launch",
        type = "lldb"
      }
}
    ]]

    assert.same_ignoring_whitespace(build_spec(mock_position), expected)
    assert.same_ignoring_whitespace(build_spec(mock_position, "dap"), expected_with_dap)
  end)

  it("should create a valid run spec for a namespace with multiple tests", function()
    local mock_positions = {
      {
        id = "/path/to/test.cpp::TestSuite",
        name = "TestSuite",
        type = "namespace",
        path = "/path/to/test.cpp",
        file = "/path/to/test.cpp",
        executable = "/path/to/test_executable",
      },
      {
        {
          id = "/path/to/test.cpp::TestSuite::TestCase1",
          name = "TestCase1",
          type = "test",
          path = "/path/to/test.cpp",
          file = "/path/to/test.cpp",
          suite = "TestSuite",
          executable = "/path/to/test_executable",
        },
        {
          id = "/path/to/test.cpp::TestSuite::TestCase2",
          name = "TestCase2",
          type = "test",
          path = "/path/to/test.cpp",
          file = "/path/to/test.cpp",
          suite = "TestSuite",
          executable = "/path/to/test_executable",
        },
      },
    }

    local expected = [[
      {
        command = { "/path/to/test_executable", "--gtest_filter=TestSuite.TestCase1:TestSuite.TestCase2", "--gtest_output=json:/tmp/neotest-cpp-results" },
        context = {
          non_existent_tests = {},
          results_path = "/tmp/neotest-cpp-results"
        },
        cwd = "tests/integration/cpp"
      }
    ]]

    local expected_with_dap = [[
    {
      command = { "/path/to/test_executable", "--gtest_filter=TestSuite.TestCase1:TestSuite.TestCase2", "--gtest_output=json:/tmp/neotest-cpp-results",
                  "--gtest_color=no", "--gtest_break_on_failure" },
      context = {
        non_existent_tests = {},
        results_path = "/tmp/neotest-cpp-results"
      },
      cwd = "tests/integration/cpp",
      strategy = {
        args = { "--gtest_filter=TestSuite.TestCase1:TestSuite.TestCase2", "--gtest_output=json:/tmp/neotest-cpp-results", "--gtest_color=no",
                 "--gtest_break_on_failure" },
        cwd = "tests/integration/cpp",
        name = "Debug with neotest-cpp",
        program = "/path/to/test_executable",
        request = "launch",
        type = "lldb"
      }
    }
    ]]

    assert.same_ignoring_whitespace(build_spec(mock_positions), expected)
    assert.same_ignoring_whitespace(build_spec(mock_positions, "dap"), expected_with_dap)
  end)

  it("should create a valid run spec for a file with multiple tests", function()
    local mock_positions = {
      {
        id = "/path/to/test.cpp",
        name = "test.cpp",
        type = "file",
        path = "/path/to/test.cpp",
        file = "/path/to/test.cpp",
        executable = "/path/to/test_executable",
      },
      {
        {
          id = "/path/to/test.cpp::TestSuite",
          name = "TestSuite",
          type = "namespace",
          path = "/path/to/test.cpp",
          file = "/path/to/test.cpp",
          executable = "/path/to/test_executable",
        },
        {
          {
            id = "/path/to/test.cpp::TestSuite::TestCase1",
            name = "TestCase1",
            type = "test",
            path = "/path/to/test.cpp",
            file = "/path/to/test.cpp",
            suite = "TestSuite",
            executable = "/path/to/test_executable",
          },
          {
            id = "/path/to/test.cpp::TestSuite::TestCase2",
            name = "TestCase2",
            type = "test",
            path = "/path/to/test.cpp",
            file = "/path/to/test.cpp",
            suite = "TestSuite",
            executable = "/path/to/test_executable",
          },
        },
      },
    }

    local expected = [[
      {
        command = { "/path/to/test_executable", "--gtest_filter=TestSuite.TestCase1:TestSuite.TestCase2", "--gtest_output=json:/tmp/neotest-cpp-results" },
        context = {
          non_existent_tests = {},
          results_path = "/tmp/neotest-cpp-results"
        },
        cwd = "tests/integration/cpp"
      }
    ]]

    local expected_with_dap = [[
    {
      command = { "/path/to/test_executable", "--gtest_filter=TestSuite.TestCase1:TestSuite.TestCase2", "--gtest_output=json:/tmp/neotest-cpp-results",
                  "--gtest_color=no", "--gtest_break_on_failure" },
      context = {
        non_existent_tests = {},
        results_path = "/tmp/neotest-cpp-results"
      },
      cwd = "tests/integration/cpp",
      strategy = {
        args = { "--gtest_filter=TestSuite.TestCase1:TestSuite.TestCase2", "--gtest_output=json:/tmp/neotest-cpp-results", "--gtest_color=no",
                 "--gtest_break_on_failure" },
        cwd = "tests/integration/cpp",
        name = "Debug with neotest-cpp",
        program = "/path/to/test_executable",
        request = "launch",
        type = "lldb"
      }
    }
    ]]

    assert.same_ignoring_whitespace(build_spec(mock_positions), expected)
    assert.same_ignoring_whitespace(build_spec(mock_positions, "dap"), expected_with_dap)
  end)

  it("should create a valid run spec for parameterized tests", function()
    local mock_positions = {
      {
        id = "/path/to/test.cpp::ParameterizedTest/IntegrationTest",
        name = "ParameterizedTest/IntegrationTest",
        type = "namespace",
        path = "/path/to/test.cpp",
        file = "/path/to/test.cpp",
        executable = "/path/to/test_executable",
      },
      {
        {
          id = "/path/to/test.cpp::ParameterizedTest/IntegrationTest::TestCase/0",
          name = "TestCase/0",
          type = "test",
          path = "/path/to/test.cpp",
          file = "/path/to/test.cpp",
          suite = "ParameterizedTest/IntegrationTest",
          executable = "/path/to/test_executable",
        },
        {
          id = "/path/to/test.cpp::ParameterizedTest/IntegrationTest::TestCase/1",
          name = "TestCase/1",
          type = "test",
          path = "/path/to/test.cpp",
          file = "/path/to/test.cpp",
          suite = "ParameterizedTest/IntegrationTest",
          executable = "/path/to/test_executable",
        },
      },
    }

    local expected = [[
      {
        command = { "/path/to/test_executable", "--gtest_filter=ParameterizedTest/IntegrationTest.TestCase/0:ParameterizedTest/IntegrationTest.TestCase/1", "--gtest_output=json:/tmp/neotest-cpp-results" },
        context = {
          non_existent_tests = {},
          results_path = "/tmp/neotest-cpp-results"
        },
        cwd = "tests/integration/cpp"
      }
    ]]

    local expected_with_dap = [[
    {
      command = { "/path/to/test_executable", "--gtest_filter=ParameterizedTest/IntegrationTest.TestCase/0:ParameterizedTest/IntegrationTest.TestCase/1", "--gtest_output=json:/tmp/neotest-cpp-results",
                  "--gtest_color=no", "--gtest_break_on_failure" },
      context = {
        non_existent_tests = {},
        results_path = "/tmp/neotest-cpp-results"
      },
      cwd = "tests/integration/cpp",
      strategy = {
        args = { "--gtest_filter=ParameterizedTest/IntegrationTest.TestCase/0:ParameterizedTest/IntegrationTest.TestCase/1", "--gtest_output=json:/tmp/neotest-cpp-results", "--gtest_color=no",
                 "--gtest_break_on_failure" },
        cwd = "tests/integration/cpp",
        name = "Debug with neotest-cpp",
        program = "/path/to/test_executable",
        request = "launch",
        type = "lldb"
      }
    }
    ]]

    assert.same_ignoring_whitespace(build_spec(mock_positions), expected)
    assert.same_ignoring_whitespace(build_spec(mock_positions, "dap"), expected_with_dap)
  end)
end)
