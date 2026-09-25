# manifest-file

**Cases S1, V1, V2, V10, C1, M1.** The standard use: vcpkg-bootstrap before `project()`,
dependencies listed in `vcpkg.json` (without a baseline), plain `find_package(fmt CONFIG REQUIRED)`.

Expected:

- shared mode (`VCPKG_BOOTSTRAP_ISOLATED=OFF`): `Using vcpkg (shared)`, vcpkg is cloned into the
  per-user cache (`%LOCALAPPDATA%/vcpkg-bootstrap/vcpkg`, `${XDG_CACHE_HOME:-~/.cache}/vcpkg-bootstrap/vcpkg`),
  `<build>/vcpkg` does not exist;
- isolated mode (`ON`): `Using vcpkg (isolated)`, vcpkg is cloned into `<build>/vcpkg`,
  `ENV{VCPKG_ROOT}` is ignored (the test points it at a missing directory);
- `VCPKG_BOOTSTRAP_ROOT` and `CMAKE_TOOLCHAIN_FILE` in the cache point to that vcpkg;
- vcpkg installs fmt in manifest mode into `<build>/vcpkg_installed`;
- the program builds and prints `Hello World!`;
- a second configure (without passing `VCPKG_BOOTSTRAP_ISOLATED` again) does not clone, fetch or
  bootstrap and keeps the same vcpkg root.

Modes: shared and isolated.

## By hand

```sh
cmake -S tests/manifest-file -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> [-DVCPKG_BOOTSTRAP_ISOLATED=ON]
cmake --build build --config Release
./build/main            # or build/Release/main.exe
cmake -S tests/manifest-file -B build   # second configure: nothing is cloned again
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/manifest-file/run.cmake
cmake -DVB_SCRIPT_DIR=<checkout of main> -DVB_ISOLATED=ON -P tests/manifest-file/run.cmake
```
