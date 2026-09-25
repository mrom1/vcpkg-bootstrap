cmake_minimum_required(VERSION 3.24)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  message(FATAL_ERROR
    "vcpkg-bootstrap is not a standalone project. Use it via FetchContent_MakeAvailable() "
    "before project() in your own CMakeLists.txt; see README.md.")
endif()

include(${CMAKE_CURRENT_LIST_DIR}/vcpkg-bootstrap.cmake)
