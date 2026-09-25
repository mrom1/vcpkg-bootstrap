cmake_minimum_required(VERSION 3.24)

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
FetchContent_MakeAvailable(vcpkg_bootstrap)

project(install-function LANGUAGES CXX)

# No vcpkg.json: ask vcpkg for the ports explicitly.
vcpkg_bootstrap_install(fmt nlohmann-json)

find_package(fmt CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

add_executable(main main.cpp)
target_compile_features(main PRIVATE cxx_std_17)
target_link_libraries(main PRIVATE fmt::fmt nlohmann_json::nlohmann_json)
