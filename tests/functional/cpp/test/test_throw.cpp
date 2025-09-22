#include <exception>
#include <gtest/gtest.h>

TEST(MyLibTest, Exception) {
  throw std::exception();
};
