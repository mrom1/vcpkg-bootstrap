# env-vcpkg-switch

**Case V11.** The same build directory is configured from different shells. A Visual Studio
developer prompt (and IDEs that load it, e.g. VS Code's CMake Tools) sets `VCPKG_ROOT` to the
bundled vcpkg; a plain terminal has the user's own one or none. CMake only reads the toolchain
file on the first configure, so the environment's new choice could not take effect anyway: when
only the environment differs, the vcpkg the build directory was configured with is kept. A
location chosen by a setting still fails like in [`toolchain-switch`](../toolchain-switch).

The test uses two fake bundles like [`bundled-vcpkg`](../bundled-vcpkg) (no Visual Studio, no
download needed).

Expected:

1. `VCPKG_ROOT=bundle-1`: configure uses bundle 1;
2. `VCPKG_ROOT=bundle-2`, same build directory: succeeds with `The environment points to another
   vcpkg … keeping …` and `Using vcpkg (configured before)`; bundle 1 stays in
   `VCPKG_BOOTSTRAP_ROOT` and `CMAKE_TOOLCHAIN_FILE`; nothing is cloned;
3. no `VCPKG_ROOT` (the per-user cache would be the default): bundle 1 is kept as well; build
   and run print `Hello World!`;
4. `-DVCPKG_BOOTSTRAP_ROOT_DIR=bundle-2`: fails with `The vcpkg location changed`;
5. a build directory configured by an older script version (no `_VCPKG_BOOTSTRAP_FROM_ENV` in
   the cache) behaves like 2.

Mode: shared only. Configures pass no `VCPKG_BOOTSTRAP_INSTALL_DIR` (that would make the shared
location a setting).

## By hand

```sh
mkdir -p bundle-1/scripts/buildsystems bundle-2/scripts/buildsystems
echo '{"readonly": true}' > bundle-1/vcpkg-bundle.json
echo '{"readonly": true}' > bundle-2/vcpkg-bundle.json
echo 'message(STATUS "fake-bundle-1-toolchain-loaded")' > bundle-1/scripts/buildsystems/vcpkg.cmake
echo 'message(STATUS "fake-bundle-2-toolchain-loaded")' > bundle-2/scripts/buildsystems/vcpkg.cmake
VCPKG_ROOT=$PWD/bundle-1 cmake -S tests/env-vcpkg-switch -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
VCPKG_ROOT=$PWD/bundle-2 cmake -S tests/env-vcpkg-switch -B build    # -> keeping .../bundle-1
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/env-vcpkg-switch/run.cmake
```
