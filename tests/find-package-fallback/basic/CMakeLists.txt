cmake_minimum_required(VERSION 3.24)

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
FetchContent_MakeAvailable(vcpkg_bootstrap)

project(find-package-fallback LANGUAGES CXX)

# No vcpkg.json, no vcpkg_bootstrap_install(): plain find_package() only.
find_package(Threads REQUIRED)                  # system package: never from vcpkg
find_package(fmt CONFIG REQUIRED)               # vcpkg port fmt
find_package(nlohmann_json CONFIG REQUIRED)     # vcpkg port nlohmann-json

add_executable(main main.cpp)
target_compile_features(main PRIVATE cxx_std_17)
target_link_libraries(main PRIVATE Threads::Threads fmt::fmt nlohmann_json::nlohmann_json)
