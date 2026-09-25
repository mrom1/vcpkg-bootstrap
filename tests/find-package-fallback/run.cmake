# find-package-fallback
#
# No vcpkg.json, no explicit install: plain find_package(<Name> ... REQUIRED) installs the vcpkg port
# that provides <Name> when the package is not found anywhere else (a vcpkg-bootstrap extra).
# A: fmt (port fmt) and nlohmann_json (port nlohmann-json) are installed, Threads (system) is not.
# B: a too-old fmt elsewhere does not count as found: vcpkg's fmt is installed.     (shared only)
# C: an unrelated CMAKE_PROJECT_TOP_LEVEL_INCLUDES entry keeps the fallback active. (shared only)
#
#   cmake -DVB_SCRIPT_DIR=<checkout of main> [-DVB_ISOLATED=ON] -P tests/find-package-fallback/run.cmake

set(CASE find-package-fallback)
set(CASE_MODES OFF ON)
set(REQUIRED_INPUTS VB_SCRIPT_DIR)

# ---- common: identical in every tests/*/run.cmake -------------------------------------------
cmake_minimum_required(VERSION 3.24)
get_filename_component(CASE_DIR "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)
get_filename_component(REPO_DIR "${CASE_DIR}/../.." ABSOLUTE)

# Inputs (see README.md): VB_SCRIPT_DIR, VB_SCRIPT_TAG, VB_ISOLATED, VB_WORK_DIR, VB_EXAMPLE_DIR,
# VB_SHARED_DIR. Relative paths are relative to the current directory.
if(VB_ISOLATED)
  set(VB_ISOLATED ON)
  set(MODE isolated)
else()
  set(VB_ISOLATED OFF)
  set(MODE shared)
endif()
if(NOT VB_ISOLATED IN_LIST CASE_MODES)
  message(FATAL_ERROR "[${CASE}] This case only runs with VB_ISOLATED=${CASE_MODES}.")
endif()
foreach(var IN LISTS REQUIRED_INPUTS)
  if("${${var}}" STREQUAL "")
    message(FATAL_ERROR "[${CASE}] -D${var}=... is required.")
  endif()
endforeach()
if("${VB_WORK_DIR}" STREQUAL "")
  set(VB_WORK_DIR "${REPO_DIR}/_work")
endif()
foreach(var VB_SCRIPT_DIR VB_EXAMPLE_DIR VB_SHARED_DIR VB_WORK_DIR)
  if(NOT "${${var}}" STREQUAL "")
    file(TO_CMAKE_PATH "${${var}}" ${var})
    get_filename_component(${var} "${${var}}" ABSOLUTE)
  endif()
endforeach()
if(VB_SCRIPT_DIR AND NOT EXISTS "${VB_SCRIPT_DIR}/vcpkg-bootstrap.cmake")
  message(FATAL_ERROR "[${CASE}] VB_SCRIPT_DIR has no vcpkg-bootstrap.cmake: ${VB_SCRIPT_DIR}")
endif()

set(RUN_DIR "${VB_WORK_DIR}/${CASE}-${MODE}")
set(LOG_DIR "${VB_WORK_DIR}/logs/${CASE}-${MODE}")
file(REMOVE_RECURSE "${RUN_DIR}" "${LOG_DIR}")
file(MAKE_DIRECTORY "${RUN_DIR}" "${LOG_DIR}")

# Environment: only what the case sets below.
unset(ENV{VCPKG_ROOT})
unset(ENV{CMAKE_TOOLCHAIN_FILE})

# Where the shared (non-isolated) vcpkg is expected.
if(VB_SHARED_DIR)
  set(SHARED_ROOT "${VB_SHARED_DIR}/vcpkg")
elseif(CMAKE_HOST_WIN32)
  file(TO_CMAKE_PATH "$ENV{LOCALAPPDATA}/vcpkg-bootstrap/vcpkg" SHARED_ROOT)
elseif(NOT "$ENV{XDG_CACHE_HOME}" STREQUAL "")
  set(SHARED_ROOT "$ENV{XDG_CACHE_HOME}/vcpkg-bootstrap/vcpkg")
else()
  set(SHARED_ROOT "$ENV{HOME}/.cache/vcpkg-bootstrap/vcpkg")
endif()

message(STATUS "[${CASE}] mode=${MODE} run dir=${RUN_DIR}")

# fail(<message>...): prints the last step's log and stops. "::error::" becomes a GitHub annotation.
function(fail)
  string(JOIN "" msg ${ARGV})
  if(LOG_FILE AND EXISTS "${LOG_FILE}")
    file(READ "${LOG_FILE}" text)
    message("::group::Log of step '${STEP}' (${LOG_FILE})\n${text}\n::endgroup::")
  endif()
  message("::error::[${CASE}] (${MODE}) ${msg}")
  message(FATAL_ERROR "[${CASE}] (${MODE}) ${msg}\nLog: ${LOG_FILE}")
endfunction()

# step(<name> SUCCESS|FAILURE|ANY [WORKING_DIRECTORY <dir>] COMMAND <command>...)
# Runs the command, writes its output to ${LOG_DIR}/<name>.log and checks the exit code.
# Sets STEP, LOG (the output) and LOG_FILE in the caller's scope.
function(step name expect)
  cmake_parse_arguments(PARSE_ARGV 2 arg "" "WORKING_DIRECTORY" "COMMAND")
  if(NOT arg_WORKING_DIRECTORY)
    set(arg_WORKING_DIRECTORY "${RUN_DIR}")
  endif()
  string(REPLACE ";" " " cmd "${arg_COMMAND}")
  message(STATUS "[${CASE}] ${name}: ${cmd}")
  execute_process(COMMAND ${arg_COMMAND}
    WORKING_DIRECTORY "${arg_WORKING_DIRECTORY}"
    OUTPUT_VARIABLE out ERROR_VARIABLE out RESULT_VARIABLE res)
  set(STEP "${name}")
  set(LOG "${out}")
  set(LOG_FILE "${LOG_DIR}/${name}.log")
  file(WRITE "${LOG_FILE}" "> ${cmd}\n\n${out}\n> exit code: ${res}\n")
  set(STEP "${STEP}" PARENT_SCOPE)
  set(LOG "${LOG}" PARENT_SCOPE)
  set(LOG_FILE "${LOG_FILE}" PARENT_SCOPE)
  if(expect STREQUAL "SUCCESS" AND NOT res EQUAL 0)
    fail("step '${name}' failed (exit code ${res})")
  elseif(expect STREQUAL "FAILURE" AND res EQUAL 0)
    fail("step '${name}' succeeded but was expected to fail")
  endif()
endfunction()

# contains(<regex>...) / not_contains(<regex>...): check the output of the last step.
# CMake word-wraps warnings, so every whitespace run (incl. line breaks) is matched as one space.
function(contains)
  string(REGEX REPLACE "[ \t\r\n]+" " " flat "${LOG}")
  foreach(re IN LISTS ARGN)
    if(NOT flat MATCHES "${re}")
      fail("step '${STEP}': output does not contain '${re}'")
    endif()
  endforeach()
endfunction()
function(not_contains)
  string(REGEX REPLACE "[ \t\r\n]+" " " flat "${LOG}")
  foreach(re IN LISTS ARGN)
    if(flat MATCHES "${re}")
      fail("step '${STEP}': output contains '${re}' (matched: '${CMAKE_MATCH_0}')")
    endif()
  endforeach()
endfunction()

# configure(<step> <source dir> <build dir> [EXPECT SUCCESS|FAILURE|ANY] [PLAIN] [NO_ISOLATED]
#           [ARGS <cmake args>...] [CONTAINS <regex>...] [NOT_CONTAINS <regex>...])
# Configures like a user would, with the script taken from VB_SCRIPT_DIR instead of GitHub.
# PLAIN: no vcpkg-bootstrap arguments at all. NO_ISOLATED: VCPKG_BOOTSTRAP_ISOLATED not passed.
function(configure name source build)
  cmake_parse_arguments(PARSE_ARGV 3 arg "PLAIN;NO_ISOLATED" "EXPECT" "ARGS;CONTAINS;NOT_CONTAINS")
  if(NOT arg_EXPECT)
    set(arg_EXPECT SUCCESS)
  endif()
  set(cmd "${CMAKE_COMMAND}" -S "${source}" -B "${build}")
  if(NOT arg_PLAIN)
    if(VB_SCRIPT_DIR)
      list(APPEND cmd "-DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=${VB_SCRIPT_DIR}")
    endif()
    if(NOT arg_NO_ISOLATED)
      list(APPEND cmd "-DVCPKG_BOOTSTRAP_ISOLATED=${VB_ISOLATED}")
    endif()
    if(VB_SHARED_DIR)
      list(APPEND cmd "-DVCPKG_BOOTSTRAP_INSTALL_DIR=${VB_SHARED_DIR}")
    endif()
  endif()
  list(APPEND cmd ${arg_ARGS})
  step("configure-${name}" ${arg_EXPECT} COMMAND ${cmd})
  contains(${arg_CONTAINS})
  not_contains(${arg_NOT_CONTAINS})
  set(STEP "${STEP}" PARENT_SCOPE)
  set(LOG "${LOG}" PARENT_SCOPE)
  set(LOG_FILE "${LOG_FILE}" PARENT_SCOPE)
endfunction()

# build(<step> <build dir>)
function(build name build)
  step("build-${name}" SUCCESS COMMAND "${CMAKE_COMMAND}" --build "${build}" --config Release)
  set(STEP "${STEP}" PARENT_SCOPE)
  set(LOG "${LOG}" PARENT_SCOPE)
  set(LOG_FILE "${LOG_FILE}" PARENT_SCOPE)
endfunction()

# run_main(<step> <build dir>): runs the executable "main"; it must print "Hello World!".
function(run_main name build)
  foreach(exe "${build}/main" "${build}/main.exe" "${build}/Release/main.exe" "${build}/Release/main")
    if(EXISTS "${exe}" AND NOT IS_DIRECTORY "${exe}")
      step("run-${name}" SUCCESS COMMAND "${exe}")
      contains("Hello World!")
      set(STEP "${STEP}" PARENT_SCOPE)
      set(LOG "${LOG}" PARENT_SCOPE)
      set(LOG_FILE "${LOG_FILE}" PARENT_SCOPE)
      return()
    endif()
  endforeach()
  fail("no executable 'main' found in ${build}")
endfunction()

# cache_get(<out> <build dir> <variable>): value from CMakeCache.txt; <out>_SET is TRUE if present.
function(cache_get out build var)
  set(value "")
  set(is_set FALSE)
  if(EXISTS "${build}/CMakeCache.txt")
    file(READ "${build}/CMakeCache.txt" text)
    if(text MATCHES "(^|\n)${var}:[^=\n]*=([^\r\n]*)")
      set(value "${CMAKE_MATCH_2}")
      set(is_set TRUE)
    endif()
  endif()
  set(${out} "${value}" PARENT_SCOPE)
  set(${out}_SET ${is_set} PARENT_SCOPE)
endfunction()

# expect_same_path(<what> <actual> <expected>): compares normalized paths (case-insensitive on Windows).
function(expect_same_path what actual expected)
  foreach(p actual expected)
    set(v "${${p}}")
    file(TO_CMAKE_PATH "${v}" v)
    if(v AND EXISTS "${v}")
      file(REAL_PATH "${v}" v)
    endif()
    cmake_path(NORMAL_PATH v)
    string(REGEX REPLACE "(.)/+$" "\\1" v "${v}")
    if(CMAKE_HOST_WIN32)
      string(TOLOWER "${v}" v)
    endif()
    set(${p}_norm "${v}")
  endforeach()
  if(NOT actual_norm STREQUAL expected_norm)
    fail("${what} is '${actual}', expected '${expected}'")
  endif()
endfunction()

# root_check(<build dir>): vcpkg is where the mode says, and the toolchain belongs to it.
function(root_check build)
  if(VB_ISOLATED)
    set(expected "${build}/vcpkg")
  else()
    set(expected "${SHARED_ROOT}")
  endif()
  cache_get(root "${build}" VCPKG_BOOTSTRAP_ROOT)
  expect_same_path("VCPKG_BOOTSTRAP_ROOT" "${root}" "${expected}")
  cache_get(toolchain "${build}" CMAKE_TOOLCHAIN_FILE)
  expect_same_path("CMAKE_TOOLCHAIN_FILE" "${toolchain}" "${expected}/scripts/buildsystems/vcpkg.cmake")
  if(NOT EXISTS "${expected}/.vcpkg-root")
    fail("${expected} is not a vcpkg root (.vcpkg-root missing)")
  endif()
  if(NOT VB_ISOLATED AND EXISTS "${build}/vcpkg")
    fail("shared mode created ${build}/vcpkg")
  endif()
endfunction()

# reconfigure_check(<step> <source dir> <build dir> [<cmake args>...]): configure again without
# VCPKG_BOOTSTRAP_ISOLATED (it must persist); no clone/fetch/bootstrap; same vcpkg root.
function(reconfigure_check name source build)
  cache_get(before "${build}" VCPKG_BOOTSTRAP_ROOT)
  configure(${name} "${source}" "${build}" NO_ISOLATED ARGS ${ARGN}
    NOT_CONTAINS "\\[vcpkg-bootstrap\\] (Cloning|Fetching|Bootstrapping)")
  cache_get(after "${build}" VCPKG_BOOTSTRAP_ROOT)
  if(NOT before STREQUAL after)
    fail("VCPKG_BOOTSTRAP_ROOT changed on re-configure: '${before}' -> '${after}'")
  endif()
  set(STEP "${STEP}" PARENT_SCOPE)
  set(LOG "${LOG}" PARENT_SCOPE)
  set(LOG_FILE "${LOG_FILE}" PARENT_SCOPE)
endfunction()
# ---- end of common part ---------------------------------------------------------------------

# A: basic. Classic-mode installs go to <vcpkg root>/installed (vcpkg's default). In shared mode that
# vcpkg is shared, so the test needs one where fmt/nlohmann-json are not installed yet.
if(NOT VB_ISOLATED)
  file(GLOB preinstalled "${SHARED_ROOT}/installed/*/share/fmt" "${SHARED_ROOT}/installed/*/share/nlohmann-json")
  if(preinstalled)
    fail("the shared vcpkg already has ${preinstalled} installed, so find_package() would find it without "
         "the fallback. Run this case on a fresh runner or with a fresh -DVB_SHARED_DIR.")
  endif()
endif()

set(BUILD_A "${RUN_DIR}/build-basic")
configure(basic "${CASE_DIR}/basic" "${BUILD_A}"
  CONTAINS "'fmt' not found elsewhere; installing vcpkg port 'fmt'"
           "'nlohmann_json' not found elsewhere; installing vcpkg port 'nlohmann-json'"
  NOT_CONTAINS "'Threads' not found elsewhere")
root_check("${BUILD_A}")
cache_get(root "${BUILD_A}" VCPKG_BOOTSTRAP_ROOT)
cache_get(triplet "${BUILD_A}" VCPKG_TARGET_TRIPLET)
foreach(port fmt nlohmann-json)
  if(NOT IS_DIRECTORY "${root}/installed/${triplet}/share/${port}")
    fail("${port} was not installed into ${root}/installed/${triplet}")
  endif()
endforeach()
build(basic "${BUILD_A}")
run_main(basic "${BUILD_A}")

# Already installed now: the pre-check finds both packages, nothing is installed again.
reconfigure_check(basic-second "${CASE_DIR}/basic" "${BUILD_A}")
not_contains("not found elsewhere")
build(basic-second "${BUILD_A}")
run_main(basic-second "${BUILD_A}")

if(VB_ISOLATED)
  message(STATUS "PASSED ${CASE} (${MODE})")
  return()
endif()

# B and C install into their own build directory (vcpkg's VCPKG_INSTALLED_DIR), because A already
# installed fmt into the shared vcpkg.

# B: an fmt 1.0.0 elsewhere (CMAKE_PREFIX_PATH) does not satisfy find_package(fmt 10 ...).
set(FAKE_PREFIX "${RUN_DIR}/fake-prefix")
file(WRITE "${FAKE_PREFIX}/lib/cmake/fmt/fmt-config.cmake"
  "message(FATAL_ERROR \"The fake fmt 1.0.0 from ${FAKE_PREFIX} must not be used.\")\n")
file(WRITE "${FAKE_PREFIX}/lib/cmake/fmt/fmt-config-version.cmake" [=[
# Version 1.0.0, compatibility SameMajorVersion.
set(PACKAGE_VERSION "1.0.0")
if(PACKAGE_FIND_VERSION_MAJOR STREQUAL "1")
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
  if(PACKAGE_FIND_VERSION STREQUAL PACKAGE_VERSION)
    set(PACKAGE_VERSION_EXACT TRUE)
  endif()
else()
  set(PACKAGE_VERSION_COMPATIBLE FALSE)
endif()
]=])
set(BUILD_B "${RUN_DIR}/build-old-version")
configure(old-version "${CASE_DIR}/old-version" "${BUILD_B}"
  ARGS "-DCMAKE_PREFIX_PATH=${FAKE_PREFIX}" "-DVCPKG_INSTALLED_DIR=${BUILD_B}/vcpkg_installed"
  CONTAINS "installing vcpkg port 'fmt'" "fmt_VERSION=[1-9][0-9]\\.")
build(old-version "${BUILD_B}")
run_main(old-version "${BUILD_B}")

# C: an unrelated top-level include (no dependency provider) next to the fallback's provider.
set(NOOP "${CASE_DIR}/noop-include.cmake")
set(BUILD_C "${RUN_DIR}/build-top-level-include")
configure(top-level-include "${CASE_DIR}/basic" "${BUILD_C}"
  ARGS "-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=${NOOP}" "-DVCPKG_INSTALLED_DIR=${BUILD_C}/vcpkg_installed"
  CONTAINS "noop-include-loaded" "installing vcpkg port 'fmt'"
  NOT_CONTAINS "Another dependency provider")
cache_get(includes "${BUILD_C}" CMAKE_PROJECT_TOP_LEVEL_INCLUDES)
if(NOT includes MATCHES "^[^;]*/vcpkg-bootstrap/provider\\.cmake;")
  fail("CMAKE_PROJECT_TOP_LEVEL_INCLUDES does not start with vcpkg-bootstrap's provider.cmake: '${includes}'")
endif()
if(NOT includes MATCHES "noop-include\\.cmake")
  fail("CMAKE_PROJECT_TOP_LEVEL_INCLUDES lost the user's entry: '${includes}'")
endif()
build(top-level-include "${BUILD_C}")
run_main(top-level-include "${BUILD_C}")

message(STATUS "PASSED ${CASE} (${MODE})")
