add_rules("mode.debug", "mode.release")

option("gtest_version")
set_default("1.16.0")
set_description("GoogleTest version to use")
option_end()

add_requires("gtest $(gtest_version)", { configs = { main = true, gmock = true } })

target("your_library")
set_kind("static")
add_includedirs("include")
add_files("src/*.cpp")
set_languages("c++20")

local tests = { "test_basic", "test_fixture", "test_parameterized",
                "test_disabled", "test_skipped" }

for _, test in ipairs(tests) do
  target(test)
  set_kind("binary")
  add_includedirs("include")
  add_files("test/" .. test .. ".cpp")
  add_deps("your_library")
  set_languages("c++20")
  add_packages("gtest")
  add_tests("default")
end
