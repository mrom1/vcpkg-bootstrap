cmake_minimum_required(VERSION 3.24)

# vcpkg-bootstrap.cmake copied into the project (cmake/), no FetchContent.
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/vcpkg-bootstrap.cmake)

project(include-file LANGUAGES CXX)

find_package(fmt CONFIG REQUIRED)

add_executable(main main.cpp)
target_link_libraries(main PRIVATE fmt::fmt)
