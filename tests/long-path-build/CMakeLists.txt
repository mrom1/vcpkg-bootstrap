cmake_minimum_required(VERSION 3.24)

# vb-deep-objects: a local port whose objects exceed Windows' path limit in CMake's default layout
set(VCPKG_OVERLAY_PORTS "${CMAKE_CURRENT_LIST_DIR}/ports")

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
FetchContent_MakeAvailable(vcpkg_bootstrap)

project(long-path-build LANGUAGES CXX)

find_package(vb-deep-objects CONFIG REQUIRED)

add_executable(main main.cpp)
target_link_libraries(main PRIVATE vb::deep_objects)
