cmake_minimum_required(VERSION 3.24)

# Ports of manifest features count too
list(APPEND VCPKG_MANIFEST_FEATURES "math")

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
FetchContent_MakeAvailable(vcpkg_bootstrap)

project(long-path-warning LANGUAGES CXX)

find_package(Eigen3 CONFIG REQUIRED)

add_executable(main main.cpp)
target_link_libraries(main PRIVATE Eigen3::Eigen)