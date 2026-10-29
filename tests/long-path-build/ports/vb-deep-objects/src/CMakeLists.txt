cmake_minimum_required(VERSION 3.24)
project(vb-deep-objects LANGUAGES CXX)

# The target is named so that CMake's default object path in this build directory,
# <build>/CMakeFiles/<target>.dir/deep_objects.cpp.obj, is 270 characters long: beyond Windows'
# 260 character limit, wherever the port is built. With short intermediate directories
# (CMAKE_INTERMEDIATE_DIR_STRATEGY=SHORT) the object goes to <build>/.o/<hash>/<hash>.obj.
string(LENGTH "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/deep_.dir/deep_objects.cpp.obj" fixed)
math(EXPR pad_length "270 - ${fixed}")
if(pad_length LESS 1)
  set(pad_length 1)
endif()
string(REPEAT "x" ${pad_length} pad)
set(target "deep_${pad}")
message(STATUS "Default object path: ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target}.dir/deep_objects.cpp.obj")

add_library(${target} STATIC deep_objects.cpp)
# Everything but the intermediate directory gets a short name
set_target_properties(${target} PROPERTIES
  OUTPUT_NAME vb_deep_objects
  COMPILE_PDB_NAME vb_deep_objects
  EXPORT_NAME deep_objects)
target_include_directories(${target} PUBLIC
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
  "$<INSTALL_INTERFACE:include>")

# A tool built and run during the build, like Qt's code generators, with its own manifest merged
# into the linker's like theirs: the executable must link and start
if(WIN32)
  set(tool_manifest tool.manifest)
endif()
add_executable(vb_deep_tool tool.cpp ${tool_manifest})
add_custom_target(vb_deep_tool_run ALL COMMAND vb_deep_tool VERBATIM)

install(TARGETS ${target} EXPORT vb-deep-objects-targets ARCHIVE DESTINATION lib)
install(FILES include/vb_deep_objects.h DESTINATION include)
install(EXPORT vb-deep-objects-targets NAMESPACE vb:: FILE vb-deep-objects-config.cmake
  DESTINATION share/vb-deep-objects)
