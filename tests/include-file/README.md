# include-file

**Case S1 (without FetchContent).** Instead of fetching vcpkg-bootstrap, the user copies
`vcpkg-bootstrap.cmake` into the project (here `cmake/vcpkg-bootstrap.cmake`) and includes it
before `project()`:

```cmake
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/vcpkg-bootstrap.cmake)
project(include-file LANGUAGES CXX)
```

The script is not part of this branch, so the test builds the project in its run directory from
this folder's files plus a copy of `vcpkg-bootstrap.cmake` from `main`.

Expected (same as [`manifest-file`](../manifest-file)):

- `Using vcpkg (shared)` / `Using vcpkg (isolated)`; nothing is fetched with FetchContent;
- vcpkg is in the per-user cache (shared) or `<build>/vcpkg` (isolated);
- fmt from `vcpkg.json` in `<build>/vcpkg_installed`; build, run: `Hello World!`;
- a second configure does not clone, fetch or bootstrap.

Modes: shared and isolated.

## By hand

```sh
mkdir -p project/cmake
cp tests/include-file/{CMakeLists.txt,vcpkg.json,main.cpp} project/
cp <checkout of main>/vcpkg-bootstrap.cmake project/cmake/
cmake -S project -B build [-DVCPKG_BOOTSTRAP_ISOLATED=ON]
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/include-file/run.cmake
cmake -DVB_SCRIPT_DIR=<checkout of main> -DVB_ISOLATED=ON -P tests/include-file/run.cmake
```
