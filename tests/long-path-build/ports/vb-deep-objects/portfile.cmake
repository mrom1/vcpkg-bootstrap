vcpkg_buildpath_length_warning(37)
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

set(SOURCE_PATH "${CMAKE_CURRENT_LIST_DIR}/src")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/copyright" "MIT (vcpkg-bootstrap test port)\n")
