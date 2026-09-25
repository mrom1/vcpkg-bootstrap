# existing-build-dir

**Case V9.** A build directory is configured without vcpkg first, then vcpkg-bootstrap is
switched on (`-DUSE_VCPKG=ON`). CMake only reads the toolchain file on the first configure of
a build directory, so vcpkg could not take effect. The script must say so, before it clones
anything.

Expected:

- first configure (`USE_VCPKG=OFF`) succeeds, vcpkg-bootstrap is not involved;
- second configure (`USE_VCPKG=ON`, same build directory) fails with
  `configured before without vcpkg's toolchain … delete the build directory`;
- nothing is cloned.

Mode: shared only. No vcpkg download needed (fast).

## By hand

```sh
cmake -S tests/existing-build-dir -B build -DUSE_VCPKG=OFF
cmake -S tests/existing-build-dir -B build -DUSE_VCPKG=ON -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
# -> error: ... configured before without vcpkg's toolchain ...
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/existing-build-dir/run.cmake
```
