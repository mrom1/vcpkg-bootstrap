# toolchain-switch

**Case V8.** The vcpkg location changes in an existing build directory, here by flipping
`VCPKG_BOOTSTRAP_ISOLATED` from `OFF` to `ON`. CMake only reads the toolchain file on the first
configure of a build directory, so the new location could not take effect. The script must
fail before it clones anything. Switching back to the original setting works again.

Expected:

1. configure with `VCPKG_BOOTSTRAP_ISOLATED=OFF` succeeds (shared vcpkg);
2. configure again with `VCPKG_BOOTSTRAP_ISOLATED=ON` fails with `The vcpkg location changed`,
   nothing is cloned, `<build>/vcpkg` does not exist;
3. configure again with `VCPKG_BOOTSTRAP_ISOLATED=OFF` succeeds; build and run print `Hello World!`.

Mode: shared only.

## By hand

```sh
cmake -S tests/toolchain-switch -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> -DVCPKG_BOOTSTRAP_ISOLATED=OFF
cmake -S tests/toolchain-switch -B build -DVCPKG_BOOTSTRAP_ISOLATED=ON    # -> error: The vcpkg location changed
cmake -S tests/toolchain-switch -B build -DVCPKG_BOOTSTRAP_ISOLATED=OFF
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/toolchain-switch/run.cmake
```
