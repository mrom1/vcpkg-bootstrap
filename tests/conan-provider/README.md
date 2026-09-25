# conan-provider

**Case O1.** [cmake-conan](https://github.com/conan-io/cmake-conan)'s dependency provider is
configured next to vcpkg-bootstrap: `-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=conan_provider.cmake`.
CMake allows only one dependency provider. vcpkg-bootstrap prepends its own, so Conan's (listed
later) wins; vcpkg-bootstrap says so, and `vcpkg_bootstrap_install()` keeps working.

[`conanfile.txt`](conanfile.txt) requires `fmt/11.0.2`; `nlohmann-json` comes from vcpkg through
`vcpkg_bootstrap_install(nlohmann-json)`.

Expected:

- configure prints `Another dependency provider is configured`, and cmake-conan installs fmt
  (`CMake-Conan: first find_package() found`);
- `[vcpkg-bootstrap] Installing nlohmann-json`, but no `not found elsewhere; installing` (the
  fallback is not active);
- cache `CMAKE_PROJECT_TOP_LEVEL_INCLUDES` = `<build>/vcpkg-bootstrap/provider.cmake;<conan_provider.cmake>`;
- build, run: `Hello World!`; a second configure does not clone, fetch or bootstrap.

Mode: shared only. Needs Conan 2 on `PATH` (`pip install conan`). The test downloads
`conan_provider.cmake` from a pinned cmake-conan commit (SHA-256 checked) and sets `CONAN_HOME` to
its run directory, so your Conan profiles and cache are untouched.

## By hand

```sh
curl -LO https://raw.githubusercontent.com/conan-io/cmake-conan/b1593849dd842c37ff198b9d3e7a6d4e03803121/conan_provider.cmake
cmake -S tests/conan-provider -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> \
      -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=$PWD/conan_provider.cmake -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/conan-provider/run.cmake
```
