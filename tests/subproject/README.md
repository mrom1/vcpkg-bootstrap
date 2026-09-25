# subproject

**Cases S3, S4.** vcpkg-bootstrap in projects that are consumed with `add_subdirectory()`.

- **A — [`parent-plain/`](parent-plain) + [`child/`](child):** the parent does not use
  vcpkg-bootstrap; the child does (FetchContent snippet, `project(child)`,
  `vcpkg_bootstrap_install(fmt)`). The child's script runs after the parent's `project()`, so it
  only warns, and so does the explicit install. Expected: configure succeeds with
  `Included after project(parent)` and `vcpkg is not set up for this build`, nothing is cloned,
  the child's program builds and prints `Hello World!`.
- **B — [`parent-vcpkg/`](parent-vcpkg) + [`child-fmt/`](child-fmt):** parent and child both
  fetch vcpkg-bootstrap. The parent's copy sets vcpkg up; the child's `FetchContent_MakeAvailable()`
  is a no-op, and its `vcpkg_bootstrap_install(fmt)` installs fmt. Expected: configure prints
  `[vcpkg-bootstrap] Installing fmt`; the child's program builds and prints `Hello World!` with fmt.

Mode: shared only.

## By hand

```sh
cmake -S tests/subproject/parent-plain -B build-a -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
cmake --build build-a --config Release
cmake -S tests/subproject/parent-vcpkg -B build-b -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
cmake --build build-b --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/subproject/run.cmake
```
