cmake_minimum_required(VERSION 3.24)

option(USE_VCPKG "Set up vcpkg with vcpkg-bootstrap" OFF)
if(USE_VCPKG)
  include(FetchContent)
  FetchContent_Declare(vcpkg_bootstrap
    GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
    GIT_TAG        main
  )
  FetchContent_MakeAvailable(vcpkg_bootstrap)
endif()

project(existing-build-dir LANGUAGES CXX)

add_executable(main main.cpp)
