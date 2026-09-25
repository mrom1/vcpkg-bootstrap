cmake_minimum_required(VERSION 3.24)

option(USE_VCPKG "Set up vcpkg with vcpkg-bootstrap" ON)
if(USE_VCPKG)
  include(FetchContent)
  FetchContent_Declare(vcpkg_bootstrap
    GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
    GIT_TAG        main
  )
  FetchContent_MakeAvailable(vcpkg_bootstrap)
endif()

project(stale-provider LANGUAGES CXX)

add_executable(main main.cpp)

if(USE_VCPKG)
  find_package(fmt CONFIG REQUIRED)      # installed by the find_package() fallback
  target_link_libraries(main PRIVATE fmt::fmt)
  target_compile_definitions(main PRIVATE USE_VCPKG)
else()
  find_package(nlohmann_json CONFIG)     # the stale provider entry must not install this
  message(STATUS "nlohmann_json_FOUND=${nlohmann_json_FOUND}")
endif()
