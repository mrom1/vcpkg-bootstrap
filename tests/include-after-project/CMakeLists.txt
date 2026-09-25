cmake_minimum_required(VERSION 3.24)

# Wrong order on purpose: project() comes before vcpkg-bootstrap.
project(include-after-project LANGUAGES CXX)

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
FetchContent_MakeAvailable(vcpkg_bootstrap)

# Warns and does nothing instead of failing with "Unknown CMake command".
vcpkg_bootstrap_install(fmt)

add_executable(main main.cpp)
