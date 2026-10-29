cmake_minimum_required(VERSION 3.24)

# Manifest features chosen with -DVCPKG_MANIFEST_FEATURES=...

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
FetchContent_MakeAvailable(vcpkg_bootstrap)

project(long-path-warning-platform LANGUAGES CXX)