# long-path-build

Ports built with CMake keep their objects in `<build>/CMakeFiles/<target>.dir/<source>.obj`. In a
deep build directory, such as vcpkg's `buildtrees` in isolated mode, that exceeds Windows' 260
character path limit, which MSVC's compiler cannot go beyond. vcpkg-bootstrap has vcpkg build ports
with short intermediate directories (CMake 4.2+, `CMAKE_INTERMEDIATE_DIR_STRATEGY=SHORT`:
`<build>/.o/<hash>/<hash>.obj`), passed through vcpkg's cleaned build environment with
`VCPKG_KEEP_ENV_VARS`.

[`ports/vb-deep-objects`](ports/vb-deep-objects) is a local overlay port (`VCPKG_OVERLAY_PORTS`)
that names its target so that the default object path is 270 characters long in whatever
directory vcpkg builds it. It declares a path limit of 37, like vcpkg's long path ports, and builds
and runs a tool with its own manifest during its build, like Qt's code generators. Both steps clear
vcpkg's binary cache (`VCPKG_BINARY_SOURCES=clear`), so the port is really built.

- **A:** first configure in isolated mode. Expected on Windows:
  `[vcpkg-bootstrap] These ports will likely fail to build from source on Windows` naming
  `vb-deep-objects` (overlay ports are checked too) and `This is a limitation of MSVC, not of
  vcpkg-bootstrap`. The port builds anyway. Elsewhere: no warning. Build, run: `Hello World!`. On
  Windows, the port's configure log shows a default object path over 260 characters, and its build
  directory has CMake's short `.o` directory. The project's own build keeps CMake's default layout
  (no `CMAKE_INTERMEDIATE_DIR_STRATEGY` in its cache, no `<build>/.o`).
- **B (Windows), negative control:** a new build directory with the user's own
  `CMAKE_INTERMEDIATE_DIR_STRATEGY=FULL` in the environment, which wins. Expected: the warning, and
  `building vb-deep-objects:<triplet> failed`.

Mode: isolated only.

## By hand

```sh
cmake -S tests/long-path-build -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> \
      -DVCPKG_BOOTSTRAP_ISOLATED=ON
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -DVB_ISOLATED=ON -P tests/long-path-build/run.cmake
```
