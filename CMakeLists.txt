#######################################################################################
## Set CMake Minimum Version                                                         ##
#######################################################################################
cmake_minimum_required(VERSION 3.24)


#######################################################################################
## Setup vcpkg toolchain                                                             ##
## IMPORTANT: Needs to be done at the root of CMake, before defining the project     ##
#######################################################################################
include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
# Optional: Isolated mode will install vcpkg and all packages into the build folder.
option(VCPKG_BOOTSTRAP_ISOLATED "Virtual Environment Mode" OFF)
FetchContent_MakeAvailable(vcpkg_bootstrap)


#######################################################################################
## Project                                                                           ##
#######################################################################################
project(vcpkg-bootstrap-example VERSION 0.1.0 LANGUAGES CXX)


#######################################################################################
## Find Dependency                                                                   ##
#######################################################################################
find_package(fmt CONFIG REQUIRED)


#######################################################################################
## Building Executable                                                               ##
#######################################################################################
add_executable(main source/main.cpp)
target_link_libraries(main PRIVATE fmt::fmt)
