cmake_minimum_required(VERSION 3.24)

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main
)
FetchContent_MakeAvailable(vcpkg_bootstrap)

project(find-package-provider-found LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../modules")

# One package, one component per call: the second call must still search.
find_package(VbParts REQUIRED COMPONENTS First)
find_package(VbParts REQUIRED COMPONENTS Second)

# A result cached by the first configure: every configure must still search.
find_package(VbCached REQUIRED)

set(missing "")
foreach(target VbParts::First VbParts::Second VbCached::VbCached)
  if(NOT TARGET ${target})
    message(SEND_ERROR "${target} does not exist: its find_package() did not search")
    set(missing TRUE)
  endif()
endforeach()
if(NOT missing)
  message(STATUS "All test targets exist")
endif()

add_executable(main ../main.cpp)
target_link_libraries(main PRIVATE VbParts::First VbParts::Second VbCached::VbCached)
