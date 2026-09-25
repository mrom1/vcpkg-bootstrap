# example

**Case S1.** The project on the [`example`](https://github.com/mrom1/vcpkg-bootstrap/tree/example)
branch works exactly as published. This folder has no project files of its own; the test uses a
checkout of the `example` branch as the source directory.

Expected (same as [`manifest-file`](../manifest-file)):

- configure succeeds, `Using vcpkg (shared)` / `Using vcpkg (isolated)`;
- vcpkg is in the per-user cache (shared) or `<build>/vcpkg` (isolated);
- build, run: `Hello World!`;
- a second configure does not clone, fetch or bootstrap.

Modes: shared and isolated.

## By hand

```sh
git clone -b example . _example          # git-ignored, same layout as CI
cmake -S _example -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> [-DVCPKG_BOOTSTRAP_ISOLATED=ON]
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -DVB_EXAMPLE_DIR=_example -P tests/example/run.cmake
cmake -DVB_SCRIPT_DIR=<checkout of main> -DVB_EXAMPLE_DIR=_example -DVB_ISOLATED=ON -P tests/example/run.cmake
```
