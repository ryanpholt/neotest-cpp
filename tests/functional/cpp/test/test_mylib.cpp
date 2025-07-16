#include <gtest/gtest.h>
#include "mylib.hpp"

TEST(MyLibTest, AddFunction) {
    EXPECT_EQ(add(2, 3), 5);
    EXPECT_EQ(add(-1, 1), 0);
};

TEST(MyLibTest, AddFunction2) {
    EXPECT_EQ(add(2, 3), 3);
    EXPECT_EQ(add(-1, 1), 4);
}

TEST(MyLibTest, AddFunction3) {
    EXPECT_EQ(add(2, 3), 3);
    EXPECT_EQ(add(-1, 1), 4);
}

TEST(MyLibTest, AddFunction4) {
    EXPECT_EQ(add(2, 3), 5);
}

TEST(MyLibTest, DISABLED_AddFunction5) {
    EXPECT_EQ(add(2, 3), 5);
}

TEST(MyLibTest, AddFunction6) {
    GTEST_SKIP();
}

// -------------------------------------------------------------------------------------

class MyFixture : public ::testing::Test {
protected:
  void SetUp() override {
    value = 42;
  }

  int value;
};

// Should pass
TEST_F(MyFixture, ValueEqualsFortyTwo) {
  EXPECT_EQ(value, 42);
}

// Should fail
TEST_F(MyFixture, ValueEqualsZero) {
  EXPECT_EQ(value, 0);
}


// -------------------------------------------------------------------------------------

class MyParameterizedTest : public ::testing::TestWithParam<int> {};

// Should pass
TEST_P(MyParameterizedTest, CheckEvenNumbers) {
  int n = GetParam();
  EXPECT_EQ(n % 2, 0);
}

// Should fail
TEST_P(MyParameterizedTest, CheckEvenNumbers2) {
  int n = GetParam();
  EXPECT_EQ(n % 2, 1);
}

INSTANTIATE_TEST_SUITE_P(EvenNumbersTests, MyParameterizedTest, ::testing::Values(2, 4, 6));

// -------------------------------------------------------------------------------------
