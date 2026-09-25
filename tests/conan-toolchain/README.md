# conan-toolchain

**Case C5.** The project already gets packages from Conan the classic way: `conan install`, then
`-DCMAKE_TOOLCHAIN_FILE=<output>/conan_toolchain.cmake`. vcpkg-bootstrap keeps Conan's toolchain by
chainloading it through vcpkg's toolchain. Packages Conan provides are used from Conan; the
`find_package()` fallback only fills in what is missing.

[`conanfile.txt`](conanfile.txt) requires `fmt/11.0.2`; the project also needs `nlohmann_json`,
which Conan does not provide here.

Expected:

- configure prints `Chainloading toolchain: .../conan_toolchain.cmake`;
- `fmt_DIR` points into the Conan output folder, and no `installing vcpkg port 'fmt'`;
- `installing vcpkg port 'nlohmann-json'` (vcpkg fills the gap);
- cache: `VCPKG_CHAINLOAD_TOOLCHAIN_FILE` = Conan's toolchain;
- build, run: `Hello World!`; a second configure does not clone, fetch or bootstrap.

Mode: shared only. Needs Conan 2 on `PATH` (`pip install conan`). The test sets `CONAN_HOME` to
its run directory, so your Conan profiles and cache are untouched. It passes vcpkg's
`-DVCPKG_INSTALLED_DIR=<build>/vcpkg_installed`, so nlohmann-json is really installed by the
fallback, not found in the shared vcpkg.

## By hand

```sh
conan profile detect --force
conan install tests/conan-toolchain --output-folder=conan --build=missing -s build_type=Release
cmake -S tests/conan-toolchain -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> \
      -DCMAKE_TOOLCHAIN_FILE=$PWD/conan/conan_toolchain.cmake -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/conan-toolchain/run.cmake
```
