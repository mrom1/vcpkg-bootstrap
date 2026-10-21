# long-path-warning

Some ports fail to build beyond Windows' 260 character path limit. vcpkg knows their limits
(`vcpkg_buildpath_length_warning(<max>)`: the longest `<buildtrees>/<port>` a port tolerates) but
warns only from inside the port build, after downloading and extracting the sources. vcpkg-bootstrap
checks the same limits during configure, for the ports the manifest installs that are not installed
in the build directory yet. `eigen3` (limit 37, header-only, so quick to build) comes in through a
manifest feature enabled with `VCPKG_MANIFEST_FEATURES`.

- **A:** first configure in isolated mode (vcpkg in `<build>/vcpkg`, far deeper than 37
  characters). Expected on Windows: `[vcpkg-bootstrap] These ports will likely fail to build from
  source on Windows`, naming `eigen3: <build>/vcpkg/buildtrees/eigen3 has <n> characters, at most
  37 work` and the fix for isolated mode. Elsewhere: no such warning. Build, run: `Hello World!`
  (eigen3 itself builds fine; its limit is conservative).
- **B:** a second configure does not warn: eigen3 is installed in the build directory.
- **C (Windows):** a new build directory with
  `-DVCPKG_INSTALL_OPTIONS=--x-buildtrees-root=<run dir>/custom-buildtrees`. Expected: the warning
  names `<run dir>/custom-buildtrees/eigen3`.

Mode: isolated only.

## By hand

```sh
cmake -S tests/long-path-warning -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> \
      -DVCPKG_BOOTSTRAP_ISOLATED=ON
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -DVB_ISOLATED=ON -P tests/long-path-warning/run.cmake
```