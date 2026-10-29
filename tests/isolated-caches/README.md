# isolated-caches

Isolated mode keeps everything vcpkg writes in the build directory. By default vcpkg also writes
to the user profile: its binary cache (`%LOCALAPPDATA%\vcpkg\archives`, `~/.cache/vcpkg/archives`)
and its git registry cache (`.../vcpkg/registries`). Settings in the environment can send downloads
and binary caches anywhere. In isolated mode vcpkg-bootstrap keeps them all in the build directory
(`<build>/vcpkg-bootstrap/archives`, `<build>/vcpkg-bootstrap/registries`, `<build>/vcpkg/downloads`)
and ignores those settings, like `VCPKG_ROOT`.

The case points the user profile (`LOCALAPPDATA`, `APPDATA`, `XDG_CACHE_HOME`) and the settings
(`VCPKG_BINARY_SOURCES`, `VCPKG_DEFAULT_BINARY_CACHE`, `X_VCPKG_REGISTRIES_CACHE`, `VCPKG_DOWNLOADS`)
to directories in the run directory, and checks that nothing is written there. The only exception
is Visual Studio's own telemetry (`%LOCALAPPDATA%\Microsoft\VSApplicationInsights`): Microsoft's
build tools that vcpkg runs on Windows write it now and then and delete it after sending. It is not
data of vcpkg or vcpkg-bootstrap, and they cannot turn it off.

- **A:** first configure in isolated mode. Expected: nothing written to the profile or the
  settings' directories (vcpkg installs during the configure), and
  `[vcpkg-bootstrap] Isolated mode: ignoring VCPKG_BINARY_SOURCES, VCPKG_DEFAULT_BINARY_CACHE,
  X_VCPKG_REGISTRIES_CACHE, VCPKG_DOWNLOADS from the environment`. Build, run: `Hello World!`.
  Still nothing written outside; fmt's package is in `<build>/vcpkg-bootstrap/archives` and its
  sources in `<build>/vcpkg/downloads`.
- **B:** a second build directory has its own binary cache: fmt is built again, nothing is
  restored, nothing is written outside.

Mode: isolated only.

## By hand

```sh
cmake -S tests/isolated-caches -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> \
      -DVCPKG_BOOTSTRAP_ISOLATED=ON
cmake --build build --config Release
```

Then check that `%LOCALAPPDATA%\vcpkg` (`~/.cache/vcpkg`) did not change.

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -DVB_ISOLATED=ON -P tests/isolated-caches/run.cmake
```
