# stale-provider

**Case O2.** vcpkg-bootstrap registers its `find_package()` fallback through
`<build>/vcpkg-bootstrap/provider.cmake`, listed in the cached `CMAKE_PROJECT_TOP_LEVEL_INCLUDES`.
When the project stops using vcpkg-bootstrap (here: `-DUSE_VCPKG=OFF`), that cache entry stays.
It must be harmless: `provider.cmake` only registers the provider if vcpkg-bootstrap ran in the
same configure.

Expected:

1. `-DUSE_VCPKG=ON`: `find_package(fmt CONFIG REQUIRED)` makes the fallback install fmt
   (`installing vcpkg port 'fmt'`); build, run: `Hello World!`.
2. `-DUSE_VCPKG=OFF`, same build directory: configure succeeds with no `[vcpkg-bootstrap]` output
   at all, `find_package(nlohmann_json CONFIG)` is not turned into an install; the cache still
   lists `provider.cmake`; build, run: `Hello World!`.

Mode: shared only. Step 1 passes vcpkg's `-DVCPKG_INSTALLED_DIR=<build>/vcpkg_installed`, so fmt
is really installed by the fallback, not found in the shared vcpkg.

## By hand

```sh
cmake -S tests/stale-provider -B build -DUSE_VCPKG=ON -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
cmake -S tests/stale-provider -B build -DUSE_VCPKG=OFF
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/stale-provider/run.cmake
```
