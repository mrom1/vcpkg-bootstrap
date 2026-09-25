cmake_minimum_required(VERSION 3.24)

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
FetchContent_MakeAvailable(vcpkg_bootstrap)

project(chainload-toolchain LANGUAGES CXX)

if(NOT VB_DUMMY_TOOLCHAIN_LOADED)
  message(FATAL_ERROR "The user's toolchain (dummy-toolchain.cmake) was not loaded.")
endif()

find_package(fmt CONFIG REQUIRED)

add_executable(main main.cpp)
target_link_libraries(main PRIVATE fmt::fmt)
