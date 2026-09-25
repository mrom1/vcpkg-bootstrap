cmake_minimum_required(VERSION 3.24)

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
FetchContent_MakeAvailable(vcpkg_bootstrap)

project(child LANGUAGES CXX)

# The parent did not set up vcpkg: warns, does nothing.
vcpkg_bootstrap_install(fmt)

add_executable(main main.cpp)
