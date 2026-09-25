# bundled-vcpkg

**Cases V5, V6.** The environment variable `VCPKG_ROOT` points to a *bundled* vcpkg: one with
a `vcpkg-bundle.json` and no `ports/` tree, like the vcpkg Visual Studio ships and sets in its
developer environment. vcpkg itself only supports such a vcpkg in manifest mode with a
`builtin-baseline`. vcpkg-bootstrap follows that rule.

The test does not need Visual Studio: it creates a fake bundle (`vcpkg-bundle.json` plus a
`scripts/buildsystems/vcpkg.cmake` stub that prints `fake-bundle-toolchain-loaded`).

- **A — [`no-manifest/`](no-manifest):** no `vcpkg.json`. Expected:
  `Ignoring ENV{VCPKG_ROOT} (...): no vcpkg.json found`, then `Using vcpkg (shared)` with a
  managed clone (`VCPKG_BOOTSTRAP_ROOT` = `<managed>/vcpkg`); the stub toolchain is not loaded;
  build, run: `Hello World!`.
- **B — [`with-baseline/`](with-baseline):** `vcpkg.json` with `builtin-baseline`. Expected:
  `ENV{VCPKG_ROOT} is a bundled vcpkg ...; using it`, the stub toolchain is loaded,
  `VCPKG_BOOTSTRAP_ROOT` = the bundle, nothing is cloned; build, run: `Hello World!`.

Mode: shared only. The managed vcpkg for A is cloned into the run directory
(`-DVCPKG_BOOTSTRAP_INSTALL_DIR=<run dir>/managed`), not the user cache.

## By hand

```sh
mkdir -p bundle/scripts/buildsystems
echo '{"readonly": true}' > bundle/vcpkg-bundle.json
echo 'message(STATUS "fake-bundle-toolchain-loaded")' > bundle/scripts/buildsystems/vcpkg.cmake
export VCPKG_ROOT=$PWD/bundle
cmake -S tests/bundled-vcpkg/no-manifest   -B build-a -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
cmake -S tests/bundled-vcpkg/with-baseline -B build-b -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/bundled-vcpkg/run.cmake
```
