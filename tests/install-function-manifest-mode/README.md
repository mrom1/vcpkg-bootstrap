# install-function-manifest-mode

**Cases M2, M3.** How `vcpkg_bootstrap_install()` behaves where it cannot or should not install.

- **A — [`manifest/`](manifest):** the project has a `vcpkg.json` listing `fmt` and calls
  `vcpkg_bootstrap_install(fmt nlohmann-json)`. In manifest mode vcpkg installs what the manifest
  lists, so the call does nothing, and warns about each port that is not in the manifest.
  Expected: configure succeeds, warning `'nlohmann-json' is not listed`, no warning for `fmt`,
  no `[vcpkg-bootstrap] Installing`; build, run: `Hello World!`.
- **B — [`before-project/`](before-project):** `vcpkg_bootstrap_install(fmt)` between
  `FetchContent_MakeAvailable()` and `project()`. The vcpkg triplet is only known after
  `project()`, so configure fails with `must be called after project()`.

Mode: shared only.

## By hand

```sh
cmake -S tests/install-function-manifest-mode/manifest -B build-a -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
cmake --build build-a --config Release
cmake -S tests/install-function-manifest-mode/before-project -B build-b -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
# -> error: ... must be called after project() ...
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/install-function-manifest-mode/run.cmake
```
