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