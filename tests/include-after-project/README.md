# include-after-project

**Case S2.** vcpkg-bootstrap is fetched *after* `project()`. The toolchain can no longer be
changed at that point, so the script only warns and does nothing. `vcpkg_bootstrap_install()`
is still defined: it warns instead of failing with "Unknown CMake command".

Expected:

- configure succeeds with the warnings `Included after project(...)` and
  `vcpkg is not set up for this build`;
- no vcpkg is cloned;
- the project builds and prints `Hello World!`.

Mode: shared only. No vcpkg download needed (fast).

## By hand

```sh
cmake -S tests/include-after-project -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/include-after-project/run.cmake
```
