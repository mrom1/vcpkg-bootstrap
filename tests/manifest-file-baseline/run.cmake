# manifest-file-baseline
#
# vcpkg.json pins a builtin-baseline. A: a fresh managed clone contains the baseline and builds.
# B: an existing managed clone that is older than the baseline is fetched, moved forward to the
# baseline and bootstrapped again. C: a second configure of B does nothing of that again.
#
#   cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/manifest-file-baseline/run.cmake

set(CASE manifest-file-baseline)
set(CASE_MODES OFF)
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

# vcpkg release tags (resolved once with git ls-remote https://github.com/microsoft/vcpkg refs/tags/<tag>).
set(NEW 9e593bb18ea69cc5095e012465dcd675a822ed0d)   # 2026.07.29, the builtin-baseline in vcpkg.json
set(OLD 84bab45d415d22042bd0b9081aea57f362da3f35)   # 2025.12.12
set(OLD_TAG 2025.12.12)

# git_ok(<out> <dir> <git args>...): TRUE if the git command succeeds.
function(git_ok out dir)
  execute_process(COMMAND git ${ARGN} WORKING_DIRECTORY "${dir}"
    RESULT_VARIABLE res OUTPUT_QUIET ERROR_QUIET)
  if(res EQUAL 0)
    set(${out} TRUE PARENT_SCOPE)
  else()
    set(${out} FALSE PARENT_SCOPE)
  endif()
endfunction()

# A: fresh managed clone (own install dir, independent of the user cache)
set(MANAGED "${RUN_DIR}/managed")
set(BUILD_A "${RUN_DIR}/build-fresh")
configure(fresh "${CASE_DIR}" "${BUILD_A}" ARGS "-DVCPKG_BOOTSTRAP_INSTALL_DIR=${MANAGED}"
  CONTAINS "\\[vcpkg-bootstrap\\] Cloning" "\\[vcpkg-bootstrap\\] Bootstrapping")
cache_get(root "${BUILD_A}" VCPKG_BOOTSTRAP_ROOT)
expect_same_path("VCPKG_BOOTSTRAP_ROOT" "${root}" "${MANAGED}/vcpkg")
git_ok(has_new "${MANAGED}/vcpkg" merge-base --is-ancestor ${NEW} HEAD)
if(NOT has_new)
  fail("HEAD of ${MANAGED}/vcpkg does not contain the baseline ${NEW}")
endif()
build(fresh "${BUILD_A}")
run_main(fresh "${BUILD_A}")

# B: an older managed clone. Full history up to OLD, without the baseline commit, origin on GitHub:
# what a clone made months ago looks like. Cloned from A's checkout to save the download;
# --no-local copies only the objects reachable from OLD.
set(MANAGED2 "${RUN_DIR}/managed2")
set(OLD_CLONE "${MANAGED2}/vcpkg")
file(TO_NATIVE_PATH "${MANAGED}/vcpkg" local_source)
step(clone-old SUCCESS COMMAND git -c advice.detachedHead=false clone --quiet --no-local --single-branch
  --branch ${OLD_TAG} "${local_source}" "${OLD_CLONE}")
step(set-origin SUCCESS WORKING_DIRECTORY "${OLD_CLONE}"
  COMMAND git remote set-url origin https://github.com/microsoft/vcpkg.git)
step(set-refspec SUCCESS WORKING_DIRECTORY "${OLD_CLONE}"
  COMMAND git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*")
execute_process(COMMAND git rev-parse HEAD WORKING_DIRECTORY "${OLD_CLONE}"
  OUTPUT_VARIABLE old_head OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT old_head STREQUAL OLD)
  fail("test setup: ${OLD_CLONE} is at '${old_head}', expected ${OLD} (${OLD_TAG})")
endif()
git_ok(has_new "${OLD_CLONE}" cat-file -e ${NEW}^{commit})
if(has_new)
  fail("test setup: ${OLD_CLONE} already contains ${NEW}")
endif()
if(CMAKE_HOST_WIN32)
  step(bootstrap-old SUCCESS WORKING_DIRECTORY "${OLD_CLONE}" COMMAND cmd /c "${OLD_CLONE}/bootstrap-vcpkg.bat" -disableMetrics)
else()
  step(bootstrap-old SUCCESS WORKING_DIRECTORY "${OLD_CLONE}" COMMAND sh "${OLD_CLONE}/bootstrap-vcpkg.sh" -disableMetrics)
endif()

set(BUILD_B "${RUN_DIR}/build-old-clone")
configure(old-clone "${CASE_DIR}" "${BUILD_B}" ARGS "-DVCPKG_BOOTSTRAP_INSTALL_DIR=${MANAGED2}"
  CONTAINS "\\[vcpkg-bootstrap\\] Fetching vcpkg \\(need"
           "\\[vcpkg-bootstrap\\] Updating vcpkg to builtin-baseline"
           "\\[vcpkg-bootstrap\\] Bootstrapping"
  NOT_CONTAINS "\\[vcpkg-bootstrap\\] Cloning")
git_ok(has_new "${OLD_CLONE}" merge-base --is-ancestor ${NEW} HEAD)
if(NOT has_new)
  fail("HEAD of ${OLD_CLONE} was not moved to the baseline ${NEW}")
endif()
build(old-clone "${BUILD_B}")
run_main(old-clone "${BUILD_B}")

# C: second configure of B
reconfigure_check(old-clone-second "${CASE_DIR}" "${BUILD_B}" "-DVCPKG_BOOTSTRAP_INSTALL_DIR=${MANAGED2}")
build(old-clone-second "${BUILD_B}")
run_main(old-clone-second "${BUILD_B}")

message(STATUS "PASSED ${CASE} (${MODE})")
