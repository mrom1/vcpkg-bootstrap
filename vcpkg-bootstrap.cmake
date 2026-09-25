# SPDX-License-Identifier: MIT
# vcpkg-bootstrap — https://github.com/mrom1/vcpkg-bootstrap
#
# Makes vcpkg available before project() and sets it up as the toolchain. Packages then come
# from plain find_package():
#
#   cmake_minimum_required(VERSION 3.24)
#   include(FetchContent)
#   FetchContent_Declare(vcpkg_bootstrap
#     GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
#     GIT_TAG        v1.0.0)
#   # set(VCPKG_BOOTSTRAP_ISOLATED ON)   # optional: vcpkg lives in the build directory
#   FetchContent_MakeAvailable(vcpkg_bootstrap)
#
#   project(myproject CXX)
#   find_package(fmt CONFIG REQUIRED)
#
# Alternatively: include(<path>/vcpkg-bootstrap.cmake) before the first project() call.
#
# Where packages come from (vcpkg has the lowest priority unless asked otherwise):
#   1. vcpkg.json present          vcpkg installs everything listed (vcpkg manifest mode).
#   2. vcpkg_bootstrap_install()   the given ports always come from vcpkg.
#   3. find_package(<Name> ...)    found elsewhere (system, another toolchain, prefix paths) ->
#                                  that one is used. Otherwise a vcpkg port that provides <Name>
#                                  is installed. Not done for find_package(... QUIET) without
#                                  REQUIRED, and not while another dependency provider is active.
#   Packages are installed where vcpkg puts them by default: manifest mode ->
#   ${CMAKE_BINARY_DIR}/vcpkg_installed, classic mode (2, 3) -> <vcpkg root>/installed.
#   Isolated mode therefore keeps vcpkg and all packages inside the build directory.
#
# Option:
#   VCPKG_BOOTSTRAP_ISOLATED  OFF (default): shared vcpkg — ENV{VCPKG_ROOT} (a bundled vcpkg without
#                             ports tree, e.g. Visual Studio's, only if vcpkg.json pins a baseline),
#                             or a per-user cache
#                               Windows:     %LOCALAPPDATA%/vcpkg-bootstrap/vcpkg
#                               Linux/macOS: $XDG_CACHE_HOME/vcpkg-bootstrap/vcpkg
#                                            or ~/.cache/vcpkg-bootstrap/vcpkg
#                             ON: private vcpkg in ${CMAKE_BINARY_DIR}/vcpkg; ENV{VCPKG_ROOT} ignored.
#
# Function:
#   vcpkg_bootstrap_install(<port>...)
#     After project(), anywhere in the tree. Ports use vcpkg syntax (fmt, fmt[core]).
#     In manifest mode it does nothing and warns about ports missing from vcpkg.json.
#
# Advanced variables (relative paths are relative to the top-level source directory):
#   VCPKG_BOOTSTRAP_ROOT_DIR     Use this existing vcpkg checkout as-is. Wins over everything.
#   VCPKG_BOOTSTRAP_INSTALL_DIR  Shared mode: manage vcpkg in <dir>/vcpkg instead of the user cache.
#   VCPKG_BOOTSTRAP_REF          Commit/tag to check out in a vcpkg managed by this script.
#   VCPKG_BOOTSTRAP_DISABLE      Do nothing.
#   vcpkg's own variables are respected: VCPKG_MANIFEST_DIR, VCPKG_TARGET_TRIPLET,
#   VCPKG_INSTALLED_DIR, VCPKG_OVERLAY_PORTS, VCPKG_OVERLAY_TRIPLETS, VCPKG_INSTALL_OPTIONS.
#
# vcpkg checkouts this script did not create (ENV{VCPKG_ROOT}, VCPKG_BOOTSTRAP_ROOT_DIR, a vcpkg
# toolchain given by the user) are never modified.
#
# Output:
#   VCPKG_BOOTSTRAP_ROOT  (cache) the vcpkg root in use.

include_guard(GLOBAL)

if(CMAKE_VERSION VERSION_LESS 3.24)
  message(FATAL_ERROR "[vcpkg-bootstrap] CMake 3.24 or newer is required (found ${CMAKE_VERSION}).")
endif()
cmake_policy(VERSION 3.24)

set(_VCPKG_BOOTSTRAP_REPO_URL "https://github.com/microsoft/vcpkg.git")

option(VCPKG_BOOTSTRAP_ISOLATED "Keep vcpkg in the build directory (ignores ENV{VCPKG_ROOT})" OFF)
option(VCPKG_BOOTSTRAP_DISABLE "Disable vcpkg-bootstrap completely" OFF)
mark_as_advanced(VCPKG_BOOTSTRAP_DISABLE)


#######################################################################################
## Public API                                                                        ##
## Defined before anything can return early, so calls never become "Unknown command" ##
#######################################################################################

function(vcpkg_bootstrap_install)
  if(ARGC EQUAL 0)
    message(WARNING "[vcpkg-bootstrap] vcpkg_bootstrap_install() called without any port.")
    return()
  endif()
  string(REPLACE ";" " " _ports "${ARGN}")

  get_property(_active GLOBAL PROPERTY VCPKG_BOOTSTRAP_ACTIVE)
  if(NOT _active)
    message(WARNING
      "[vcpkg-bootstrap] vcpkg is not set up for this build, so vcpkg_bootstrap_install(${_ports}) "
      "does nothing. vcpkg-bootstrap has to run before the first project() call of the top-level project.")
    return()
  endif()

  if(NOT VCPKG_TOOLCHAIN OR NOT VCPKG_TARGET_TRIPLET)
    message(FATAL_ERROR
      "[vcpkg-bootstrap] vcpkg_bootstrap_install(${_ports}) must be called after project(): "
      "the vcpkg target triplet is only known once vcpkg's toolchain has run.")
  endif()

  if(VCPKG_MANIFEST_MODE)
    _vcpkg_bootstrap_warn_unlisted(${ARGN})
    return()
  endif()

  _vcpkg_bootstrap_run_install(FATAL ${ARGN})
endfunction()


#######################################################################################
## Helpers: git                                                                      ##
#######################################################################################

# Runs git. Without RESULT, a failing command is a fatal error that shows git's output.
function(_vcpkg_bootstrap_git)
  cmake_parse_arguments(PARSE_ARGV 0 _arg "" "WORKING_DIRECTORY;OUTPUT;RESULT" "")
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" ${_arg_UNPARSED_ARGUMENTS}
    WORKING_DIRECTORY "${_arg_WORKING_DIRECTORY}"
    OUTPUT_VARIABLE _out
    ERROR_VARIABLE _out
    RESULT_VARIABLE _res
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT DEFINED _arg_RESULT AND NOT _res EQUAL 0)
    string(REPLACE ";" " " _cmd "${_arg_UNPARSED_ARGUMENTS}")
    message(FATAL_ERROR "[vcpkg-bootstrap] 'git ${_cmd}' in ${_arg_WORKING_DIRECTORY} failed:\n${_out}")
  endif()
  if(DEFINED _arg_OUTPUT)
    set(${_arg_OUTPUT} "${_out}" PARENT_SCOPE)
  endif()
  if(DEFINED _arg_RESULT)
    set(${_arg_RESULT} "${_res}" PARENT_SCOPE)
  endif()
endfunction()

# Sets <out> to TRUE if <ref> resolves to a commit in the checkout at <root>.
function(_vcpkg_bootstrap_has_commit root ref out)
  _vcpkg_bootstrap_git(cat-file -e "${ref}^{commit}" WORKING_DIRECTORY "${root}" RESULT _res)
  if(_res EQUAL 0)
    set(${out} TRUE PARENT_SCOPE)
  else()
    set(${out} FALSE PARENT_SCOPE)
  endif()
endfunction()

# Sets <out> to TRUE if HEAD of the checkout at <root> contains commit <ref>. vcpkg reads the
# versions database from the working tree, so HEAD must not be older than the baseline.
function(_vcpkg_bootstrap_head_contains root ref out)
  _vcpkg_bootstrap_git(merge-base --is-ancestor "${ref}" HEAD WORKING_DIRECTORY "${root}" RESULT _res)
  if(_res EQUAL 0)
    set(${out} TRUE PARENT_SCOPE)
  else()
    set(${out} FALSE PARENT_SCOPE)
  endif()
endfunction()


#######################################################################################
## Helpers: manifest                                                                 ##
#######################################################################################

# Sets <out> to the consumer's vcpkg.json path, or empty if there is none.
function(_vcpkg_bootstrap_manifest_file out)
  if(VCPKG_MANIFEST_DIR)
    set(_file "${VCPKG_MANIFEST_DIR}/vcpkg.json")
  else()
    set(_file "${CMAKE_SOURCE_DIR}/vcpkg.json")
  endif()
  if(EXISTS "${_file}")
    set(${out} "${_file}" PARENT_SCOPE)
  else()
    set(${out} "" PARENT_SCOPE)
  endif()
endfunction()

# Reads "builtin-baseline" from the consumer's manifest; empty if there is none.
function(_vcpkg_bootstrap_read_baseline out)
  set(${out} "" PARENT_SCOPE)
  _vcpkg_bootstrap_manifest_file(_file)
  if(NOT _file)
    return()
  endif()
  file(READ "${_file}" _json)
  string(JSON _baseline ERROR_VARIABLE _err GET "${_json}" "builtin-baseline")
  if(NOT _err)
    set(${out} "${_baseline}" PARENT_SCOPE)
  endif()
endfunction()

# Warns for ports passed to vcpkg_bootstrap_install() that are not listed in vcpkg.json.
function(_vcpkg_bootstrap_warn_unlisted)
  _vcpkg_bootstrap_manifest_file(_file)
  set(_listed "")
  if(_file)
    file(READ "${_file}" _json)
    string(JSON _count ERROR_VARIABLE _err LENGTH "${_json}" "dependencies")
    if(NOT _err AND _count GREATER 0)
      math(EXPR _last "${_count} - 1")
      foreach(_i RANGE ${_last})
        string(JSON _type TYPE "${_json}" "dependencies" ${_i})
        if(_type STREQUAL "STRING")
          string(JSON _name GET "${_json}" "dependencies" ${_i})
        else()
          string(JSON _name ERROR_VARIABLE _name_err GET "${_json}" "dependencies" ${_i} "name")
        endif()
        list(APPEND _listed "${_name}")
      endforeach()
    endif()
  endif()

  foreach(_port IN LISTS ARGN)
    string(REGEX REPLACE "[:[].*$" "" _base "${_port}")   # fmt[core]:x64-linux -> fmt
    if(NOT _base IN_LIST _listed)
      message(WARNING
        "[vcpkg-bootstrap] This project uses a vcpkg.json manifest, so vcpkg_bootstrap_install(${_port}) "
        "does nothing, and '${_base}' is not listed in the manifest's \"dependencies\". Add it there.")
    endif()
  endforeach()
endfunction()


#######################################################################################
## Helpers: vcpkg checkouts                                                          ##
#######################################################################################

# Existing, user-owned vcpkg: only check, never modify.
function(_vcpkg_bootstrap_check_external root)
  if(NOT EXISTS "${root}/scripts/buildsystems/vcpkg.cmake")
    message(FATAL_ERROR "[vcpkg-bootstrap] '${root}' does not look like a vcpkg root "
                        "(scripts/buildsystems/vcpkg.cmake is missing).")
  endif()
  _vcpkg_bootstrap_read_baseline(_baseline)
  if(NOT _baseline OR NOT EXISTS "${root}/.git" OR NOT GIT_EXECUTABLE)
    return()
  endif()
  _vcpkg_bootstrap_head_contains("${root}" "${_baseline}" _ok)
  if(NOT _ok)
    message(WARNING
      "[vcpkg-bootstrap] The vcpkg checkout in ${root} is older than builtin-baseline "
      "${_baseline}, so vcpkg will likely fail to resolve versions. vcpkg-bootstrap does "
      "not modify vcpkg installations it did not create; update it with "
      "'git -C \"${root}\" pull' (then run its bootstrap script).")
  endif()
endfunction()

# Script-owned vcpkg: clone, fetch, check out and bootstrap as needed.
function(_vcpkg_bootstrap_ensure_managed root)
  if(NOT GIT_EXECUTABLE)
    message(FATAL_ERROR "[vcpkg-bootstrap] git is required to clone vcpkg but was not found.")
  endif()

  cmake_path(GET root PARENT_PATH _parent)
  file(MAKE_DIRECTORY "${_parent}")

  # Serialize parallel configures (Debug + Release, IDE + terminal) sharing this checkout.
  message(CHECK_START "[vcpkg-bootstrap] Locking ${_parent}")
  file(LOCK "${_parent}/vcpkg-bootstrap.lock" GUARD FUNCTION TIMEOUT 1800 RESULT_VARIABLE _lock)
  if(_lock)
    message(CHECK_FAIL "failed")
    message(FATAL_ERROR "[vcpkg-bootstrap] Could not lock ${_parent}: ${_lock}")
  endif()
  message(CHECK_PASS "done")

  set(_need_bootstrap FALSE)

  if(NOT EXISTS "${root}")
    # Full clone (no --depth): manifest versioning needs the registry history.
    # Clone into a temporary directory first so an interrupted clone never looks valid.
    set(_tmp "${root}.partial")
    file(REMOVE_RECURSE "${_tmp}")
    set(_clone_opts --quiet)
    if(CMAKE_HOST_WIN32)
      # vcpkg contains paths that exceed MAX_PATH below deep install directories.
      list(APPEND _clone_opts -c core.longpaths=true)
    endif()
    message(CHECK_START "[vcpkg-bootstrap] Cloning ${_VCPKG_BOOTSTRAP_REPO_URL} into ${root}")
    _vcpkg_bootstrap_git(clone ${_clone_opts} "${_VCPKG_BOOTSTRAP_REPO_URL}" "${_tmp}"
      WORKING_DIRECTORY "${_parent}" OUTPUT _out RESULT _res)
    if(NOT _res EQUAL 0)
      message(CHECK_FAIL "failed")
      file(REMOVE_RECURSE "${_tmp}")
      message(FATAL_ERROR "[vcpkg-bootstrap] git clone failed:\n${_out}")
    endif()
    file(RENAME "${_tmp}" "${root}")
    message(CHECK_PASS "done")
    set(_need_bootstrap TRUE)
  elseif(NOT EXISTS "${root}/.vcpkg-root" OR NOT EXISTS "${root}/.git")
    message(FATAL_ERROR
      "[vcpkg-bootstrap] '${root}' exists but is not a vcpkg git checkout. "
      "Delete it to let vcpkg-bootstrap clone vcpkg again.")
  endif()

  set(_wanted "")
  _vcpkg_bootstrap_read_baseline(_baseline)
  if(VCPKG_BOOTSTRAP_REF)
    list(APPEND _wanted "${VCPKG_BOOTSTRAP_REF}")
  endif()
  if(_baseline)
    list(APPEND _wanted "${_baseline}")
  endif()

  # Only go to the network when something we need is missing locally.
  foreach(_ref IN LISTS _wanted)
    _vcpkg_bootstrap_has_commit("${root}" "${_ref}" _has)
    if(NOT _has)
      message(CHECK_START "[vcpkg-bootstrap] Fetching vcpkg (need ${_ref})")
      _vcpkg_bootstrap_git(fetch --quiet --tags origin WORKING_DIRECTORY "${root}" OUTPUT _out RESULT _res)
      if(NOT _res EQUAL 0)
        message(CHECK_FAIL "failed")
        message(FATAL_ERROR "[vcpkg-bootstrap] git fetch failed:\n${_out}")
      endif()
      message(CHECK_PASS "done")
      break()
    endif()
  endforeach()
  foreach(_ref IN LISTS _wanted)
    _vcpkg_bootstrap_has_commit("${root}" "${_ref}" _has)
    if(NOT _has)
      message(FATAL_ERROR "[vcpkg-bootstrap] '${_ref}' does not exist in ${_VCPKG_BOOTSTRAP_REPO_URL}.")
    endif()
  endforeach()

  if(VCPKG_BOOTSTRAP_REF)
    _vcpkg_bootstrap_git(rev-parse HEAD WORKING_DIRECTORY "${root}" OUTPUT _head)
    _vcpkg_bootstrap_git(rev-parse "${VCPKG_BOOTSTRAP_REF}^{commit}" WORKING_DIRECTORY "${root}" OUTPUT _target)
    if(NOT _head STREQUAL _target)
      message(STATUS "[vcpkg-bootstrap] Checking out ${VCPKG_BOOTSTRAP_REF} (${_target})")
      _vcpkg_bootstrap_git(-c advice.detachedHead=false checkout --detach "${_target}"
        WORKING_DIRECTORY "${root}")
      set(_need_bootstrap TRUE)
    endif()
  endif()

  if(_baseline)
    _vcpkg_bootstrap_head_contains("${root}" "${_baseline}" _ok)
    if(NOT _ok AND VCPKG_BOOTSTRAP_REF)
      message(WARNING
        "[vcpkg-bootstrap] VCPKG_BOOTSTRAP_REF ${VCPKG_BOOTSTRAP_REF} is older than builtin-baseline "
        "${_baseline}, so vcpkg will likely fail to resolve versions.")
    elseif(NOT _ok)
      # Only ever moves forward: an older baseline is already contained in HEAD.
      message(STATUS "[vcpkg-bootstrap] Updating vcpkg to builtin-baseline ${_baseline}")
      _vcpkg_bootstrap_git(-c advice.detachedHead=false checkout --detach "${_baseline}"
        WORKING_DIRECTORY "${root}")
      set(_need_bootstrap TRUE)
    endif()
  endif()

  if(CMAKE_HOST_WIN32)
    set(_exe "${root}/vcpkg.exe")
    set(_bootstrap_script "${root}/bootstrap-vcpkg.bat")
  else()
    set(_exe "${root}/vcpkg")
    set(_bootstrap_script "${root}/bootstrap-vcpkg.sh")
  endif()
  if(NOT EXISTS "${_exe}")
    set(_need_bootstrap TRUE)
  endif()

  if(_need_bootstrap)
    message(CHECK_START "[vcpkg-bootstrap] Bootstrapping vcpkg")
    if(CMAKE_HOST_WIN32)
      set(_cmd cmd /c "${_bootstrap_script}")
    else()
      set(_cmd sh "${_bootstrap_script}")
    endif()
    execute_process(
      COMMAND ${_cmd} -disableMetrics
      WORKING_DIRECTORY "${root}"
      OUTPUT_VARIABLE _out
      ERROR_VARIABLE _out
      RESULT_VARIABLE _res)
    if(NOT _res EQUAL 0 OR NOT EXISTS "${_exe}")
      message(CHECK_FAIL "failed")
      message(FATAL_ERROR "[vcpkg-bootstrap] ${_bootstrap_script} failed (${_res}):\n${_out}")
    endif()
    message(CHECK_PASS "done")
  endif()
endfunction()

function(_vcpkg_bootstrap_default_install_dir out)
  if(CMAKE_HOST_WIN32)
    set(_base "$ENV{LOCALAPPDATA}")
  elseif(NOT "$ENV{XDG_CACHE_HOME}" STREQUAL "")
    set(_base "$ENV{XDG_CACHE_HOME}")
  elseif(NOT "$ENV{HOME}" STREQUAL "")
    set(_base "$ENV{HOME}/.cache")
  endif()
  if(NOT _base)
    message(FATAL_ERROR "[vcpkg-bootstrap] Cannot determine a per-user cache directory; "
                        "set VCPKG_BOOTSTRAP_INSTALL_DIR, VCPKG_ROOT or VCPKG_BOOTSTRAP_ISOLATED.")
  endif()
  file(TO_CMAKE_PATH "${_base}/vcpkg-bootstrap" _dir)
  set(${out} "${_dir}" PARENT_SCOPE)
endfunction()


#######################################################################################
## Helpers: installing ports                                                         ##
#######################################################################################

# Runs `vcpkg install <ports>` (classic mode) into the build's install root.
# <on_error>: FATAL fails the configure, WARNING reports and continues.
function(_vcpkg_bootstrap_run_install on_error)
  set(_root "${VCPKG_BOOTSTRAP_ROOT}")
  if(CMAKE_HOST_WIN32)
    set(_exe "${_root}/vcpkg.exe")
  else()
    set(_exe "${_root}/vcpkg")
  endif()
  if(NOT EXISTS "${_exe}")
    message(FATAL_ERROR
      "[vcpkg-bootstrap] The vcpkg executable is missing: ${_exe}. Run the bootstrap-vcpkg script "
      "in ${_root}, or let vcpkg-bootstrap manage its own vcpkg.")
  endif()

  # vcpkg's toolchain decides the install root; fall back to our default before it ran.
  if(_VCPKG_INSTALLED_DIR)
    set(_installed "${_VCPKG_INSTALLED_DIR}")
  elseif(VCPKG_INSTALLED_DIR)
    set(_installed "${VCPKG_INSTALLED_DIR}")
  else()
    set(_installed "${CMAKE_BINARY_DIR}/vcpkg_installed")
  endif()

  set(_cmd "${_exe}" install ${ARGN}
    "--vcpkg-root=${_root}"
    "--triplet=${VCPKG_TARGET_TRIPLET}"
    "--x-install-root=${_installed}")
  if(VCPKG_HOST_TRIPLET)
    list(APPEND _cmd "--host-triplet=${VCPKG_HOST_TRIPLET}")
  endif()
  foreach(_dir IN LISTS VCPKG_OVERLAY_PORTS)
    list(APPEND _cmd "--overlay-ports=${_dir}")
  endforeach()
  foreach(_dir IN LISTS VCPKG_OVERLAY_TRIPLETS)
    list(APPEND _cmd "--overlay-triplets=${_dir}")
  endforeach()
  list(APPEND _cmd ${VCPKG_INSTALL_OPTIONS})

  string(REPLACE ";" " " _ports "${ARGN}")
  message(CHECK_START "[vcpkg-bootstrap] Installing ${_ports} (${VCPKG_TARGET_TRIPLET})")
  # vcpkg serializes concurrent use of one vcpkg root itself (filesystem lock on .vcpkg-root).
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env VCPKG_DISABLE_METRICS=1 ${_cmd}
    WORKING_DIRECTORY "${_root}"
    OUTPUT_VARIABLE _out
    ERROR_VARIABLE _out
    RESULT_VARIABLE _res)
  file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/vcpkg-bootstrap")
  file(APPEND "${CMAKE_BINARY_DIR}/vcpkg-bootstrap/install.log"
       "==== vcpkg install ${_ports} (${_res})\n${_out}\n")
  if(NOT _res EQUAL 0)
    message(CHECK_FAIL "failed")
    if(on_error STREQUAL "FATAL")
      message(FATAL_ERROR "[vcpkg-bootstrap] 'vcpkg install ${_ports}' failed (${_res}):\n${_out}")
    endif()
    message(WARNING "[vcpkg-bootstrap] 'vcpkg install ${_ports}' failed (${_res}):\n${_out}")
    return()
  endif()
  message(CHECK_PASS "done")
endfunction()


#######################################################################################
## Helpers: find_package() fallback provider                                         ##
#######################################################################################

# Sets <out> to TRUE if vcpkg port <port> provides the CMake package <package>.
# Deliberately strict: a wrong guess could install large, unrelated ports.
function(_vcpkg_bootstrap_port_provides port package out)
  set(${out} FALSE PARENT_SCOPE)
  set(_dir "${VCPKG_BOOTSTRAP_ROOT}/ports/${port}")
  if(NOT EXISTS "${_dir}/portfile.cmake")
    return()
  endif()
  file(READ "${_dir}/portfile.cmake" _portfile)

  # Meta-ports (e.g. boost) install nothing themselves but can pull in huge dependency sets.
  # CMake helper ports (e.g. boost-cmake) only serve other ports' builds, even if their usage
  # text mentions a package.
  if(_portfile MATCHES "VCPKG_POLICY_(EMPTY_PACKAGE|CMAKE_HELPER_PORT)[ \t]+enabled")
    return()
  endif()

  string(REPLACE "+" "\\+" _re "${package}")
  string(REPLACE "." "\\." _re "${_re}")

  # vcpkg_cmake_config_fixup(PACKAGE_NAME <package> ...)
  if(_portfile MATCHES "PACKAGE_NAME[ \t\r\n]+\"?${_re}\"?[ \t\r\n)]")
    set(${out} TRUE PARENT_SCOPE)
    return()
  endif()

  # The port's usage text: find_package(<package> ...)
  if(EXISTS "${_dir}/usage")
    file(READ "${_dir}/usage" _usage)
    if(_usage MATCHES "find_package\\([ \t]*${_re}[ \t\r\n)]")
      set(${out} TRUE PARENT_SCOPE)
      return()
    endif()
  endif()

  # Without PACKAGE_NAME, vcpkg's config fixup installs the CMake package under the port name.
  if(port STREQUAL package
     AND NOT _portfile MATCHES "PACKAGE_NAME"
     AND _portfile MATCHES "vcpkg_cmake_config_fixup|vcpkg_fixup_cmake_targets")
    set(${out} TRUE PARENT_SCOPE)
  endif()
endfunction()

# Sets <out> to the vcpkg port that provides CMake package <package>, or empty.
function(_vcpkg_bootstrap_port_for package out)
  set(${out} "" PARENT_SCOPE)
  set(_root "${VCPKG_BOOTSTRAP_ROOT}")

  # 1. Obvious candidates: fmt -> fmt, nlohmann_json -> nlohmann-json, ZLIB -> zlib.
  string(TOLOWER "${package}" _lower)
  string(REPLACE "_" "-" _dashed "${_lower}")
  set(_candidates "${_lower}" "${_dashed}")
  list(REMOVE_DUPLICATES _candidates)
  foreach(_port IN LISTS _candidates)
    _vcpkg_bootstrap_port_provides("${_port}" "${package}" _ok)
    if(_ok)
      set(${out} "${_port}" PARENT_SCOPE)
      return()
    endif()
    # The package's own port is a meta-port (Boost -> boost): never substitute another port.
    if(EXISTS "${_root}/ports/${_port}/portfile.cmake")
      file(STRINGS "${_root}/ports/${_port}/portfile.cmake" _meta
           REGEX "VCPKG_POLICY_EMPTY_PACKAGE[ \t]+enabled" LIMIT_COUNT 1)
      if(_meta)
        return()
      endif()
    endif()
  endforeach()

  # 2. Search the ports tree for ports mentioning the package name, then verify each.
  set(_files "")
  if(GIT_EXECUTABLE AND EXISTS "${_root}/.git")
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" grep -l -F -e "${package}" -- "ports/*/portfile.cmake" "ports/*/usage"
      WORKING_DIRECTORY "${_root}"
      OUTPUT_VARIABLE _files
      ERROR_QUIET
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REPLACE "\n" ";" _files "${_files}")
  else()
    file(GLOB _all RELATIVE "${_root}" "${_root}/ports/*/portfile.cmake" "${_root}/ports/*/usage")
    foreach(_file IN LISTS _all)
      file(STRINGS "${_root}/${_file}" _hit REGEX "${package}" LIMIT_COUNT 1)
      if(_hit)
        list(APPEND _files "${_file}")
      endif()
    endforeach()
  endif()

  set(_ports "")
  foreach(_file IN LISTS _files)
    if(_file MATCHES "^ports/([^/]+)/")
      list(APPEND _ports "${CMAKE_MATCH_1}")
    endif()
  endforeach()
  list(REMOVE_DUPLICATES _ports)
  list(REMOVE_ITEM _ports ${_candidates})
  foreach(_port IN LISTS _ports)
    _vcpkg_bootstrap_port_provides("${_port}" "${package}" _ok)
    if(_ok)
      set(${out} "${_port}" PARENT_SCOPE)
      return()
    endif()
  endforeach()
endfunction()

# Installs the port providing <package> if there is one. <mode>: REQUIRED, DEFAULT or PROBE.
function(_vcpkg_bootstrap_try_auto_install package mode)
  get_property(_tried GLOBAL PROPERTY "_VCPKG_BOOTSTRAP_TRIED_${package}")
  if(_tried)
    return()
  endif()
  set_property(GLOBAL PROPERTY "_VCPKG_BOOTSTRAP_TRIED_${package}" TRUE)

  get_property(_active GLOBAL PROPERTY VCPKG_BOOTSTRAP_ACTIVE)
  if(NOT _active OR NOT VCPKG_TOOLCHAIN OR NOT VCPKG_TARGET_TRIPLET)
    return()
  endif()

  if(mode STREQUAL "PROBE")
    message(VERBOSE
      "[vcpkg-bootstrap] '${package}' not found; not installing it from vcpkg because "
      "find_package() was called with QUIET and without REQUIRED.")
    return()
  endif()

  _vcpkg_bootstrap_port_for("${package}" _port)
  if(NOT _port)
    set(_level VERBOSE)
    if(mode STREQUAL "REQUIRED")
      set(_level STATUS)
    endif()
    message(${_level}
      "[vcpkg-bootstrap] No vcpkg port provides the CMake package '${package}'. If vcpkg has it "
      "under another name, call vcpkg_bootstrap_install(<port>) before find_package().")
    return()
  endif()

  message(STATUS "[vcpkg-bootstrap] '${package}' not found elsewhere; installing vcpkg port '${_port}'")
  if(mode STREQUAL "REQUIRED")
    _vcpkg_bootstrap_run_install(FATAL "${_port}")
  else()
    _vcpkg_bootstrap_run_install(WARNING "${_port}")
  endif()
endfunction()

# Dependency provider for find_package(). A macro, so a successful pre-check sets the result
# variables in the caller's scope exactly like find_package() would.
# vcpkg has the lowest priority: if the package is found anywhere else, that one is used.
# If this provider does not set <Package>_FOUND, CMake continues with its built-in
# find_package() using the caller's original arguments.
macro(_vcpkg_bootstrap_provide _vb_method _vb_package)
  set(_vb_args ${ARGN})
  get_property(_vb_busy GLOBAL PROPERTY _VCPKG_BOOTSTRAP_PROVIDER_BUSY)
  if(NOT _vb_busy AND NOT VCPKG_MANIFEST_MODE)
    set_property(GLOBAL PROPERTY _VCPKG_BOOTSTRAP_PROVIDER_BUSY TRUE)

    # Pre-check with the caller's version/components, so an outdated package elsewhere
    # does not count as found.
    set(_vb_check_args ${_vb_args})
    list(REMOVE_ITEM _vb_check_args REQUIRED)
    find_package(${_vb_package} ${_vb_check_args} QUIET BYPASS_PROVIDER)

    if(NOT ${_vb_package}_FOUND)
      unset(${_vb_package}_FOUND)
      string(TOUPPER "${_vb_package}" _vb_upper)
      unset(${_vb_upper}_FOUND)

      if("REQUIRED" IN_LIST _vb_args)
        set(_vb_mode REQUIRED)
      elseif("QUIET" IN_LIST _vb_args)
        set(_vb_mode PROBE)
      else()
        set(_vb_mode DEFAULT)
      endif()
      _vcpkg_bootstrap_try_auto_install("${_vb_package}" ${_vb_mode})
    endif()

    set_property(GLOBAL PROPERTY _VCPKG_BOOTSTRAP_PROVIDER_BUSY FALSE)
  endif()
  unset(_vb_args)
  unset(_vb_busy)
  unset(_vb_check_args)
  unset(_vb_upper)
  unset(_vb_mode)
endmacro()

# Writes the provider file and prepends it to CMAKE_PROJECT_TOP_LEVEL_INCLUDES, which the
# first project() call reads. Prepending means a provider listed by the user (e.g. cmake-conan)
# is registered later and therefore wins.
function(_vcpkg_bootstrap_register_provider)
  set(_file "${CMAKE_BINARY_DIR}/vcpkg-bootstrap/provider.cmake")
  set(_content [=[
# Generated by vcpkg-bootstrap. Registers the find_package() fallback that installs missing
# packages from vcpkg. Does nothing unless vcpkg-bootstrap ran in the current configure, so a
# stale entry in CMAKE_PROJECT_TOP_LEVEL_INCLUDES is harmless.
get_property(_vcpkg_bootstrap_active GLOBAL PROPERTY VCPKG_BOOTSTRAP_ACTIVE)
if(_vcpkg_bootstrap_active AND COMMAND _vcpkg_bootstrap_provide)
  cmake_language(SET_DEPENDENCY_PROVIDER _vcpkg_bootstrap_provide SUPPORTED_METHODS FIND_PACKAGE)
endif()
unset(_vcpkg_bootstrap_active)
]=])
  set(_old "")
  if(EXISTS "${_file}")
    file(READ "${_file}" _old)
  endif()
  if(NOT _old STREQUAL _content)
    file(WRITE "${_file}" "${_content}")
  endif()

  set(_includes ${CMAKE_PROJECT_TOP_LEVEL_INCLUDES})
  list(REMOVE_ITEM _includes "${_file}")

  foreach(_include IN LISTS _includes)
    set(_path "${_include}")
    if(NOT IS_ABSOLUTE "${_path}")
      if(EXISTS "${CMAKE_SOURCE_DIR}/${_path}")
        set(_path "${CMAKE_SOURCE_DIR}/${_path}")
      else()
        set(_path "${CMAKE_BINARY_DIR}/${_path}")
      endif()
    endif()
    if(EXISTS "${_path}" AND NOT IS_DIRECTORY "${_path}")
      file(READ "${_path}" _text)
      if(_text MATCHES "SET_DEPENDENCY_PROVIDER")
        message(STATUS
          "[vcpkg-bootstrap] Another dependency provider is configured (${_include}); it takes "
          "precedence, so find_package() will not install missing packages from vcpkg. "
          "vcpkg_bootstrap_install() still works.")
        break()
      endif()
    endif()
  endforeach()

  list(PREPEND _includes "${_file}")
  set(CMAKE_PROJECT_TOP_LEVEL_INCLUDES "${_includes}" CACHE STRING
      "Files included during the first project() call (vcpkg-bootstrap prepends its provider)" FORCE)
endfunction()


#######################################################################################
## Main                                                                              ##
#######################################################################################

function(_vcpkg_bootstrap_activate root)
  set_property(GLOBAL PROPERTY VCPKG_BOOTSTRAP_ACTIVE TRUE)
  set(VCPKG_BOOTSTRAP_ROOT "${root}" CACHE INTERNAL "vcpkg root used by vcpkg-bootstrap")
endfunction()

function(_vcpkg_bootstrap_main)
  if(VCPKG_BOOTSTRAP_DISABLE)
    message(STATUS "[vcpkg-bootstrap] Disabled (VCPKG_BOOTSTRAP_DISABLE).")
    return()
  endif()

  find_package(Git QUIET)

  # --- Included after project(): the toolchain can no longer be changed ----------------
  if(DEFINED PROJECT_NAME)
    if(VCPKG_TOOLCHAIN)
      # vcpkg is already active (e.g. a parent project set it up): explicit installs still work.
      if(Z_VCPKG_ROOT_DIR)
        set(_root "${Z_VCPKG_ROOT_DIR}")
      else()
        string(REGEX REPLACE "/scripts/buildsystems/vcpkg\\.cmake$" "" _root "${CMAKE_TOOLCHAIN_FILE}")
      endif()
      _vcpkg_bootstrap_activate("${_root}")
      message(STATUS
        "[vcpkg-bootstrap] Included after project(${PROJECT_NAME}); vcpkg's toolchain is already "
        "active (${_root}), so vcpkg_bootstrap_install() is available.")
    else()
      message(WARNING
        "[vcpkg-bootstrap] Included after project(${PROJECT_NAME}); the toolchain can no longer be "
        "changed, so nothing is done. Include vcpkg-bootstrap before the first project() call.")
    endif()
    return()
  endif()

  # --- Toolchain requested by the user (CMake also reads it from the environment) ------
  if(DEFINED CMAKE_TOOLCHAIN_FILE)
    file(TO_CMAKE_PATH "${CMAKE_TOOLCHAIN_FILE}" _user_toolchain)
  elseif(NOT "$ENV{CMAKE_TOOLCHAIN_FILE}" STREQUAL "")
    file(TO_CMAKE_PATH "$ENV{CMAKE_TOOLCHAIN_FILE}" _user_toolchain)
  else()
    set(_user_toolchain "")
  endif()
  set(_own_toolchain "")
  if(DEFINED CACHE{_VCPKG_BOOTSTRAP_TOOLCHAIN_FILE})
    set(_own_toolchain "$CACHE{_VCPKG_BOOTSTRAP_TOOLCHAIN_FILE}")
  endif()
  if(_own_toolchain AND _user_toolchain STREQUAL _own_toolchain)
    set(_user_toolchain "")   # set by an earlier run of this script, not by the user
  endif()

  # A vcpkg toolchain given by the user (command line, preset, IDE integration) wins.
  if(_user_toolchain MATCHES "/scripts/buildsystems/vcpkg\\.cmake$")
    string(REGEX REPLACE "/scripts/buildsystems/vcpkg\\.cmake$" "" _root "${_user_toolchain}")
    message(STATUS "[vcpkg-bootstrap] Using the vcpkg toolchain given by the user: ${_user_toolchain}")
    _vcpkg_bootstrap_check_external("${_root}")
    _vcpkg_bootstrap_activate("${_root}")
    _vcpkg_bootstrap_register_provider()
    return()
  endif()

  # --- Where vcpkg comes from ----------------------------------------------------------
  # ENV{VCPKG_ROOT} is often set by an IDE (Visual Studio developer environment) to a bundled
  # vcpkg without a ports tree. That one works in manifest mode when the manifest has a
  # builtin-baseline (or a vcpkg-configuration.json defines the registry), but it cannot install
  # ports in classic mode (vcpkg_bootstrap_install(), find_package() fallback). Without such a
  # manifest it is skipped in favour of a managed vcpkg.
  set(_env_root "")
  if(NOT VCPKG_BOOTSTRAP_ROOT_DIR AND NOT VCPKG_BOOTSTRAP_ISOLATED AND NOT "$ENV{VCPKG_ROOT}" STREQUAL "")
    file(TO_CMAKE_PATH "$ENV{VCPKG_ROOT}" _env_root)
    if(EXISTS "${_env_root}/vcpkg-bundle.json" OR NOT IS_DIRECTORY "${_env_root}/ports")
      _vcpkg_bootstrap_manifest_file(_manifest)
      _vcpkg_bootstrap_read_baseline(_baseline)
      set(_registry_config FALSE)
      if(_manifest)
        cmake_path(GET _manifest PARENT_PATH _manifest_dir)
        if(EXISTS "${_manifest_dir}/vcpkg-configuration.json")
          set(_registry_config TRUE)
        endif()
      endif()
      set(_manifest_off FALSE)
      if(DEFINED VCPKG_MANIFEST_MODE AND NOT VCPKG_MANIFEST_MODE)
        set(_manifest_off TRUE)
      endif()

      if(_manifest AND NOT _manifest_off AND (_baseline OR _registry_config))
        message(STATUS
          "[vcpkg-bootstrap] ENV{VCPKG_ROOT} is a bundled vcpkg (e.g. Visual Studio's); using it "
          "because the manifest pins a baseline. (vcpkg_bootstrap_install() and the find_package() "
          "fallback are inactive in manifest mode anyway.)")
      else()
        if(NOT _manifest)
          set(_reason "no vcpkg.json found")
        elseif(_manifest_off)
          set(_reason "VCPKG_MANIFEST_MODE is OFF")
        else()
          set(_reason "vcpkg.json has no builtin-baseline")
        endif()
        message(STATUS
          "[vcpkg-bootstrap] Ignoring ENV{VCPKG_ROOT} (${_env_root}): ${_reason}. It is a bundled "
          "vcpkg without a ports tree (e.g. Visual Studio's), which only works with a vcpkg.json "
          "that has a builtin-baseline. Using a vcpkg managed by vcpkg-bootstrap instead.")
        set(_env_root "")
      endif()
    endif()
  endif()

  if(VCPKG_BOOTSTRAP_ROOT_DIR)
    file(TO_CMAKE_PATH "${VCPKG_BOOTSTRAP_ROOT_DIR}" _root)
    cmake_path(ABSOLUTE_PATH _root BASE_DIRECTORY "${CMAKE_SOURCE_DIR}" NORMALIZE)
    set(_managed FALSE)
    set(_source "VCPKG_BOOTSTRAP_ROOT_DIR")
  elseif(VCPKG_BOOTSTRAP_ISOLATED)
    set(_root "${CMAKE_BINARY_DIR}/vcpkg")
    set(_managed TRUE)
    set(_source "isolated")
  elseif(_env_root)
    set(_root "${_env_root}")
    set(_managed FALSE)
    set(_source "ENV{VCPKG_ROOT}")
  else()
    if(VCPKG_BOOTSTRAP_INSTALL_DIR)
      file(TO_CMAKE_PATH "${VCPKG_BOOTSTRAP_INSTALL_DIR}" _dir)
    else()
      _vcpkg_bootstrap_default_install_dir(_dir)
    endif()
    cmake_path(ABSOLUTE_PATH _dir BASE_DIRECTORY "${CMAKE_SOURCE_DIR}" NORMALIZE)
    set(_root "${_dir}/vcpkg")
    set(_managed TRUE)
    set(_source "shared")
  endif()
  cmake_path(SET _root NORMALIZE "${_root}")
  string(REGEX REPLACE "/$" "" _root "${_root}")
  set(_toolchain "${_root}/scripts/buildsystems/vcpkg.cmake")

  # --- CMake only reads the toolchain on the first configure of a build directory ------
  # CMAKE_PLATFORM_INFO_INITIALIZED is cached by the first project() call. Set without our
  # toolchain means this build directory was configured before without vcpkg, and CMake would
  # silently ignore the toolchain set below.
  if(NOT _own_toolchain AND CMAKE_PLATFORM_INFO_INITIALIZED)
    message(FATAL_ERROR
      "[vcpkg-bootstrap] This build directory (${CMAKE_BINARY_DIR}) was configured before without "
      "vcpkg's toolchain. CMake only reads the toolchain file on the first configure of a build "
      "directory, so vcpkg cannot be set up here. Delete the build directory (or its CMakeCache.txt) "
      "and configure again.")
  endif()
  if(_own_toolchain)
    set(_before "${_own_toolchain}")
    set(_now "${_toolchain}")
    if(CMAKE_HOST_WIN32)
      string(TOLOWER "${_before}" _before)
      string(TOLOWER "${_now}" _now)
    endif()
    if(NOT _before STREQUAL _now)
      message(FATAL_ERROR
        "[vcpkg-bootstrap] The vcpkg location changed since this build directory was configured:\n"
        "  before: ${_own_toolchain}\n"
        "  now:    ${_toolchain}\n"
        "CMake only reads the toolchain file on the first configure of a build directory, so the "
        "change cannot take effect. Delete the build directory (or its CMakeCache.txt) and configure again.")
    endif()
  endif()

  message(STATUS "[vcpkg-bootstrap] Using vcpkg (${_source}): ${_root}")
  if(_managed)
    _vcpkg_bootstrap_ensure_managed("${_root}")
  else()
    _vcpkg_bootstrap_check_external("${_root}")
  endif()

  # --- Keep a user toolchain (cross-compiling, Conan, ...) by chainloading it ----------
  if(_user_toolchain)
    set(_chainload "${_user_toolchain}")
    # CMake resolves a relative toolchain path against the build dir, then the source dir.
    if(NOT IS_ABSOLUTE "${_chainload}")
      if(EXISTS "${CMAKE_BINARY_DIR}/${_chainload}")
        set(_chainload "${CMAKE_BINARY_DIR}/${_chainload}")
      else()
        set(_chainload "${CMAKE_SOURCE_DIR}/${_chainload}")
      endif()
    endif()
    set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${_chainload}" CACHE FILEPATH "Toolchain loaded by vcpkg's toolchain")
    message(STATUS "[vcpkg-bootstrap] Chainloading toolchain: ${VCPKG_CHAINLOAD_TOOLCHAIN_FILE}")
  endif()

  # Install locations are vcpkg's defaults: manifest mode -> ${CMAKE_BINARY_DIR}/vcpkg_installed,
  # classic mode -> <vcpkg root>/installed (inside the build directory in isolated mode).
  set(_VCPKG_BOOTSTRAP_TOOLCHAIN_FILE "${_toolchain}" CACHE INTERNAL "")
  set(CMAKE_TOOLCHAIN_FILE "${_toolchain}" CACHE FILEPATH "vcpkg toolchain (set by vcpkg-bootstrap)" FORCE)

  _vcpkg_bootstrap_activate("${_root}")
  _vcpkg_bootstrap_register_provider()
endfunction()

_vcpkg_bootstrap_main()