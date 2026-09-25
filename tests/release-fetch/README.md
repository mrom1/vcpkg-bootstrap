# release-fetch

**Release check.** The published tag works as users consume it: FetchContent really clones
`https://github.com/mrom1/vcpkg-bootstrap.git` at the tag (no `FETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP`
override). The test generates the project from [`CMakeLists.txt.in`](CMakeLists.txt.in) with the
tag filled in.

Expected: configure succeeds (`Using vcpkg (shared)`), vcpkg-bootstrap was cloned into
`<build>/_deps/vcpkg_bootstrap-src`, vcpkg is in the per-user cache; build, run: `Hello World!`.

Mode: shared only. CI runs it only when the dispatched `script_ref` is a tag (`v*`).

## By hand

Copy `CMakeLists.txt.in` to `CMakeLists.txt`, replace `@VB_SCRIPT_TAG@` with the tag, then:

```sh
cmake -S . -B build
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_TAG=v1.0.0 -P tests/release-fetch/run.cmake
```
