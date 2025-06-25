local adapter = require("neotest-cpp.adapter")
local nio = require("nio")
require("tests.utils")

describe("discover_positions", function()
  local test_file_path = "/tmp/test_discover_positions.cpp"

  local function discover_positions(content)
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.split(content, "\n")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    local tree = nio.tests.with_async_context(adapter.discover_positions, test_file_path)
    assert.is_not_nil(tree)
    return tree
  end

  local function discover_positions_str(content)
    local tree = discover_positions(content)
    return vim.inspect(tree:to_list())
  end

  before_each(function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, test_file_path)
    vim.bo[bufnr].filetype = "cpp"
    vim.api.nvim_set_current_buf(bufnr)
  end)

  after_each(function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("should discover simple test positions", function()
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

    assert.same_ignoring_whitespace(discover_positions_str(input), expected)
  end)

  it("should discover TEST_F fixture test positions", function()
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
        range = { 7, 6, 9, 7 },
        suite = "StringTest",
        type = "test"
      } } } }
    ]]

    assert.same_ignoring_whitespace(discover_positions_str(input), expected)
  end)

  it("should discover TEST_P parameterized test positions", function()
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
        range = { 4, 6, 7, 7 },
        suite = "*/MathParamTest",
        type = "test"
      } }, { {
        id = "/tmp/test_discover_positions.cpp::*/MathParamTest::IsPositive/*",
        name = "IsPositive/*",
        path = "/tmp/test_discover_positions.cpp",
        range = { 9, 6, 12, 7 },
        suite = "*/MathParamTest",
        type = "test"
      } } } }
    ]]

    assert.same_ignoring_whitespace(discover_positions_str(input), expected)
  end)

  it("should discover test with custom prefix", function()
    local input = [[
      #include <gtest/gtest.h>

      // Not a valid prefix
      AB_TEST(MathTest, Multiplication) {
        EXPECT_EQ(2 * 2, 4);
      }

      // Valid prefix
      RH_TEST(MathTest, Addition) {
        EXPECT_EQ(2 + 2, 4);
      }

      class StringTest : public ::testing::Test {
      protected:
        void SetUp() override {}
      };

      // Valid prefix
      RH_TEST_F(StringTest, Length) {
        EXPECT_EQ(strlen("hello"), 5);
      }

      class MathParamTest : public ::testing::TestWithParam<int> {};

      // Valid prefix
      XY_TEST_P(MathParamTest, IsEven) {
        int n = GetParam();
        EXPECT_EQ(n % 2, 0);
      }

      INSTANTIATE_TEST_SUITE_P(Numbers, MathParamTest,
                               ::testing::Values(2, 4, 6, 8));
    ]]

    local positions_str = discover_positions_str(input)

    local ids_to_find = {
      "/tmp/test_discover_positions.cpp::MathTest::Addition",
      "/tmp/test_discover_positions.cpp::StringTest::Length",
      "/tmp/test_discover_positions.cpp::*/MathParamTest::IsEven/*",
    }

    local ids_to_not_find = {
      "/tmp/test_discover_positions.cpp::MathTest::Multiplication",
    }

    -- Verify that ids_to_find are in positions_str
    for _, id in ipairs(ids_to_find) do
      assert.match(vim.pesc(id), positions_str, "Expected to find ID: " .. id)
    end

    -- Verify that ids_to_not_find are *not* in positions_str
    for _, id in ipairs(ids_to_not_find) do
      assert.not_match(vim.pesc(id), positions_str, "Expected NOT to find ID: " .. id)
    end
  end)
end)
