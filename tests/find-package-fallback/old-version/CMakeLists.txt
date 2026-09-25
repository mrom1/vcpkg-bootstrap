cmake_minimum_required(VERSION 3.24)

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
FetchContent_MakeAvailable(vcpkg_bootstrap)

project(old-version LANGUAGES CXX)

# An fmt 1.0.0 on CMAKE_PREFIX_PATH does not satisfy this; vcpkg's fmt does.
find_package(fmt 10 CONFIG REQUIRED)
message(STATUS "fmt_VERSION=${fmt_VERSION}")

add_executable(main main.cpp)
target_link_libraries(main PRIVATE fmt::fmt)
