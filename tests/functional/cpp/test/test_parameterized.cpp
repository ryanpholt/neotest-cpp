#include <gtest/gtest.h>
#include "mylib.hpp"

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