#include <gtest/gtest.h>
#include "mylib.hpp"

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