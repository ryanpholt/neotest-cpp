local helpers = require("tests.helpers")

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua_func(function()
        require("tests.helpers").setup_neotest({
          gtest = {
            test_prefixes = {
              "RH_",
              "XY_",
            },
          },
        })
      end)
    end,
    post_case = function()
      child.stop()
    end,
  },
})

local function discover_positions(content_)
  return child.lua_func(function(content)
    local bufnr = vim.api.nvim_create_buf(false, true)
    local test_file_path = "/tmp/test_discover_positions.cpp"
    vim.api.nvim_buf_set_name(bufnr, test_file_path)
    vim.bo[bufnr].filetype = "cpp"
    local lines = vim.split(content, "\n")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    local adapter = require("neotest-cpp")
    local tree = require("nio").tests.with_async_context(adapter.discover_positions, test_file_path)
    assert(tree)
    return vim.inspect(tree:to_list())
  end, content_)
end

T["should discover simple test positions"] = function()
  local input = [[
      #include <gtest/gtest.h>

      TEST(MathTest, Addition) {
        EXPECT_EQ(2 + 2, 4);
      }
    ]]

  local expected = [[
      { {
        id = "/tmp/test_discover_positions.cpp",
        name = "test_discover_positions.cpp",
        path = "/tmp/test_discover_positions.cpp",
        range = { 0, 0, 0, 0 },
        type = "file"
      }, { {
          id = "/tmp/test_discover_positions.cpp::MathTest",
          name = "MathTest",
          path = "/tmp/test_discover_positions.cpp",
          range = { 2, 0, 4, 0 },
          type = "namespace"
        }, { {
              id = "/tmp/test_discover_positions.cpp::MathTest::Addition",
            name = "Addition",
            path = "/tmp/test_discover_positions.cpp",
            range = { 2, 6, 4, 7 },
            suite = "MathTest",
            type = "test"
      } } } }
    ]]

  helpers.equality_sanitized(discover_positions(input), expected)
end

T["should discover TEST_F fixture test positions"] = function()
  local input = [[
        #include <gtest/gtest.h>

        class StringTest : public ::testing::Test {
        protected:
          void SetUp() override {}
        };

        TEST_F(StringTest, Length) {
          EXPECT_EQ(strlen("hello"), 5);
        }
      ]]

  local expected = [[
      { {
        id = "/tmp/test_discover_positions.cpp",
        name = "test_discover_positions.cpp",
        path = "/tmp/test_discover_positions.cpp",
        range = { 0, 0, 0, 0 },
        type = "file"
      }, { {
          id = "/tmp/test_discover_positions.cpp::StringTest",
          name = "StringTest",
          path = "/tmp/test_discover_positions.cpp",
          range = { 7, 0, 9, 0 },
          type = "namespace"
        }, { {
            id = "/tmp/test_discover_positions.cpp::StringTest::Length",
            name = "Length",
            path = "/tmp/test_discover_positions.cpp",
            range = { 7, 8, 9, 9 },
            suite = "StringTest",
            type = "test"
      } } } }
    ]]

  helpers.equality_sanitized(discover_positions(input), expected)
end

T["should discover TEST_P parameterized test positions"] = function()
  local input = [[
        #include <gtest/gtest.h>

        class MathParamTest : public ::testing::TestWithParam<int> {};

        TEST_P(MathParamTest, IsEven) {
          int n = GetParam();
          EXPECT_EQ(n % 2, 0);
        }

        TEST_P(MathParamTest, IsPositive) {
          int n = GetParam();
          EXPECT_GT(n, 0);
        }

        INSTANTIATE_TEST_SUITE_P(Numbers, MathParamTest,
                                 ::testing::Values(2, 4, 6, 8));
      ]]

  local expected = [[
      { {
        id = "/tmp/test_discover_positions.cpp",
        name = "test_discover_positions.cpp",
        path = "/tmp/test_discover_positions.cpp",
        range = { 0, 0, 0, 0 },
        type = "file"
      }, { {
          id = "/tmp/test_discover_positions.cpp::*/MathParamTest",
          name = "*/MathParamTest",
          path = "/tmp/test_discover_positions.cpp",
          range = { 4, 0, 12, 0 },
          type = "namespace"
        }, { {
            id = "/tmp/test_discover_positions.cpp::*/MathParamTest::IsEven/*",
            name = "IsEven/*",
            path = "/tmp/test_discover_positions.cpp",
            range = { 4, 8, 7, 9 },
            suite = "*/MathParamTest",
            type = "test"
          } }, { {
            id = "/tmp/test_discover_positions.cpp::*/MathParamTest::IsPositive/*",
            name = "IsPositive/*",
            path = "/tmp/test_discover_positions.cpp",
            range = { 9, 8, 12, 9 },
            suite = "*/MathParamTest",
            type = "test"
      } } } }
    ]]

  helpers.equality_sanitized(discover_positions(input), expected)
end

T["should discover test with custom prefix"] = function()
  local input = [[
        #include <gtest/gtest.h>

        AB_TEST(MathTest, Multiplication) {
          EXPECT_EQ(2 * 2, 4);
        }

        RH_TEST(MathTest, Addition) {
          EXPECT_EQ(2 + 2, 4);
        }

        class StringTest : public ::testing::Test {
        protected:
          void SetUp() override {}
        };

        RH_TEST_F(StringTest, Length) {
          EXPECT_EQ(strlen("hello"), 5);
        }

        class MathParamTest : public ::testing::TestWithParam<int> {};

        XY_TEST_P(MathParamTest, IsEven) {
          int n = GetParam();
          EXPECT_EQ(n % 2, 0);
        }

        INSTANTIATE_TEST_SUITE_P(Numbers, MathParamTest,
                                 ::testing::Values(2, 4, 6, 8));
      ]]

  local positions_str = discover_positions(input)

  local ids_to_find = {
    "/tmp/test_discover_positions.cpp::MathTest::Multiplication",
    "/tmp/test_discover_positions.cpp::MathTest::Addition",
    "/tmp/test_discover_positions.cpp::StringTest::Length",
    "/tmp/test_discover_positions.cpp::*/MathParamTest::IsEven/*",
  }

  -- Verify that all prefixed tests are found
  for _, id in ipairs(ids_to_find) do
    MiniTest.expect.equality(string.match(positions_str, vim.pesc(id)), id)
  end
end

T["should discover test with additional arguments"] = function()
  local input = [[
      #include <gtest/gtest.h>

      RH_TEST(MySuiteName, MyTestName, "") {
        EXPECT_EQ(1, 1);
      }

      RH_TEST_F(MyFixture, MyFixtureTest, "description") {
        EXPECT_TRUE(true);
      }

      class MyParamTest : public ::testing::TestWithParam<int> {};

      RH_TEST_P(MyParamTest, MyParamTestName, "param description") {
        int n = GetParam();
        EXPECT_GT(n, 0);
      }
    ]]

  local expected = [[
      { {
        id = "/tmp/test_discover_positions.cpp",
        name = "test_discover_positions.cpp",
        path = "/tmp/test_discover_positions.cpp",
        range = { 0, 0, 0, 0 },
        type = "file"
      }, { {
          id = "/tmp/test_discover_positions.cpp::MySuiteName",
          name = "MySuiteName",
          path = "/tmp/test_discover_positions.cpp",
          range = { 2, 0, 2, 0 },
          type = "namespace"
        }, { {
            id = "/tmp/test_discover_positions.cpp::MySuiteName::MyTestName",
            name = "MyTestName",
            path = "/tmp/test_discover_positions.cpp",
            range = { 2, 6, 2, 42 },
            suite = "MySuiteName",
            type = "test"
        } } }, { {
          id = "/tmp/test_discover_positions.cpp::MyFixture",
          name = "MyFixture",
          path = "/tmp/test_discover_positions.cpp",
          range = { 6, 0, 6, 0 },
          type = "namespace"
        }, { {
            id = "/tmp/test_discover_positions.cpp::MyFixture::MyFixtureTest",
            name = "MyFixtureTest",
            path = "/tmp/test_discover_positions.cpp",
            range = { 6, 6, 6, 56 },
            suite = "MyFixture",
            type = "test"
        } } }, { {
          id = "/tmp/test_discover_positions.cpp::*/MyParamTest",
          name = "*/MyParamTest",
          path = "/tmp/test_discover_positions.cpp",
          range = { 12, 0, 12, 0 },
          type = "namespace"
        }, { {
            id = "/tmp/test_discover_positions.cpp::*/MyParamTest::MyParamTestName/*",
            name = "MyParamTestName/*",
            path = "/tmp/test_discover_positions.cpp",
            range = { 12, 6, 12, 66 },
            suite = "*/MyParamTest",
            type = "test"
        } } } }
    ]]

  helpers.equality_sanitized(discover_positions(input), expected)
end

T["should discover test with comments in arguments"] = function()
  local input = [[
      #include <gtest/gtest.h>

      RH_TEST(
        // Comment before suite name
        MySuiteName,
        // Comment before test name
        MyTestName,
        // Comment before additional argument
        ""
      ) {
        EXPECT_EQ(1, 1);
      }
    ]]

  local positions_str = discover_positions(input)
  local expected_id = "/tmp/test_discover_positions.cpp::MySuiteName::MyTestName"

  -- Verify that the test with comments is found
  MiniTest.expect.equality(string.match(positions_str, vim.pesc(expected_id)), expected_id)
end

return T
