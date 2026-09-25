cmake_minimum_required(VERSION 3.24)

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
FetchContent_MakeAvailable(vcpkg_bootstrap)

# Wrong on purpose: the vcpkg triplet is only known after project().
vcpkg_bootstrap_install(fmt)

project(before-project LANGUAGES CXX)
