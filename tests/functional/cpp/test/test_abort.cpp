#include <gtest/gtest.h>

TEST(MyLibTest, NoAbort) {
  EXPECT_EQ(1, 1);
};

TEST(MyLibTest, Abort) {
  std::abort();
};

TEST(MyLibTest, WontRun) {
  EXPECT_EQ(1, 1);
};
