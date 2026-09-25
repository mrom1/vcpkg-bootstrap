# chainload-toolchain

**Cases C3, C4.** The user already has a toolchain that is not vcpkg's (cross-compiling,
embedded, ...). vcpkg-bootstrap must not replace it: it passes it to vcpkg's toolchain as
`VCPKG_CHAINLOAD_TOOLCHAIN_FILE`, which loads it. [`dummy-toolchain.cmake`](dummy-toolchain.cmake)
stands in for such a toolchain; the project fails if it was not loaded.

- **A:** toolchain given with `-DCMAKE_TOOLCHAIN_FILE=<abs path>/dummy-toolchain.cmake`.
- **B:** toolchain given with the environment variable `CMAKE_TOOLCHAIN_FILE`, no `-D`.

Expected (both):

- configure prints `Chainloading toolchain: .../dummy-toolchain.cmake` and `dummy-toolchain-loaded`;
- cache: `VCPKG_CHAINLOAD_TOOLCHAIN_FILE` = the dummy toolchain, `CMAKE_TOOLCHAIN_FILE` = vcpkg's
  `scripts/buildsystems/vcpkg.cmake`;
- fmt comes from `vcpkg.json`; build, run: `Hello World!`;
- a second configure does not clone, fetch or bootstrap, and still loads the dummy toolchain.

Mode: shared only.

## By hand

```sh
cmake -S tests/chainload-toolchain -B build-a -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> \
      -DCMAKE_TOOLCHAIN_FILE=$PWD/tests/chainload-toolchain/dummy-toolchain.cmake
CMAKE_TOOLCHAIN_FILE=$PWD/tests/chainload-toolchain/dummy-toolchain.cmake \
  cmake -S tests/chainload-toolchain -B build-b -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/chainload-toolchain/run.cmake
```
