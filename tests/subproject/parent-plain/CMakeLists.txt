cmake_minimum_required(VERSION 3.24)

# A parent that does not use vcpkg-bootstrap consumes a project that does.
project(parent LANGUAGES CXX)

add_subdirectory(../child child)
