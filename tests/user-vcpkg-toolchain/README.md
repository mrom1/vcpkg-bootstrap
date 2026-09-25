# user-vcpkg-toolchain

**Case C2.** The user passes vcpkg's own toolchain file, as on the command line, in a preset or
from an IDE integration: `-DCMAKE_TOOLCHAIN_FILE=<vcpkg>/scripts/buildsystems/vcpkg.cmake`.
vcpkg-bootstrap defers completely: it does not clone or choose another vcpkg, does not set its
own toolchain, and reports the user's vcpkg as `VCPKG_BOOTSTRAP_ROOT`.

Expected:

- configure prints `Using the vcpkg toolchain given by the user`, and neither `Using vcpkg (`
  nor `Cloning`;
- cache: `VCPKG_BOOTSTRAP_ROOT` = the user's vcpkg; `_VCPKG_BOOTSTRAP_TOOLCHAIN_FILE` is not set;
- fmt comes from `vcpkg.json`; build, run: `Hello World!`;
- a second configure behaves the same.

Mode: shared only. The test makes a shallow clone of vcpkg as "the user's vcpkg" and bootstraps it.

## By hand

```sh
git clone --depth 1 https://github.com/microsoft/vcpkg.git user-vcpkg
./user-vcpkg/bootstrap-vcpkg.sh      # bootstrap-vcpkg.bat on Windows
cmake -S tests/user-vcpkg-toolchain -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> \
      -DCMAKE_TOOLCHAIN_FILE=$PWD/user-vcpkg/scripts/buildsystems/vcpkg.cmake
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/user-vcpkg-toolchain/run.cmake
```
