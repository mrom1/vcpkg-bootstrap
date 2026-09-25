cmake_minimum_required(VERSION 3.24)

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
FetchContent_MakeAvailable(vcpkg_bootstrap)

project(find-package-guard LANGUAGES CXX)

# Meta-port: never installed automatically (would pull in all of Boost).
find_package(Boost)

# QUIET without REQUIRED is a probe: never installed automatically.
find_package(fmt CONFIG QUIET)
message(STATUS "fmt_FOUND=${fmt_FOUND}")

# No vcpkg port provides this: the normal "not found" result.
find_package(VbDefinitelyNotAPackage)

add_executable(main main.cpp)
