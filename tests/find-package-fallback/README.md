# find-package-fallback

**Cases F1–F5.** No `vcpkg.json` and no `vcpkg_bootstrap_install()`: a plain
`find_package(<Name> ... REQUIRED)` installs the vcpkg port that provides `<Name>`, but only when
the package is not found anywhere else. This is an extra of vcpkg-bootstrap, not vcpkg behaviour.
Installs are classic-mode installs, so they go to `<vcpkg root>/installed` (vcpkg's default).

- **A — [`basic/`](basic)** (shared and isolated): `find_package(Threads REQUIRED)`,
  `find_package(fmt CONFIG REQUIRED)`, `find_package(nlohmann_json CONFIG REQUIRED)`. Expected:
  `'fmt' not found elsewhere; installing vcpkg port 'fmt'`,
  `'nlohmann_json' not found elsewhere; installing vcpkg port 'nlohmann-json'`, nothing for
  `Threads`; both ports in `<vcpkg root>/installed/<triplet>`; build, run: `Hello World!`.
  A second configure installs nothing (`not found elsewhere` does not appear) and does not clone,
  fetch or bootstrap.
- **B — [`old-version/`](old-version)** (shared only): a fake fmt 1.0.0 on `CMAKE_PREFIX_PATH`
  and `find_package(fmt 10 CONFIG REQUIRED)`. The old version does not count as found. Expected:
  `installing vcpkg port 'fmt'` and `fmt_VERSION=1x.`; build, run.
- **C** (shared only): `basic/` again with an unrelated `-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=`[`noop-include.cmake`](noop-include.cmake).
  Expected: `noop-include-loaded`, `installing vcpkg port 'fmt'`, no
  `Another dependency provider`; the cache entry starts with `.../vcpkg-bootstrap/provider.cmake`
  and still lists the user's file.

B and C use vcpkg's own `-DVCPKG_INSTALLED_DIR=<build>/vcpkg_installed`, because A has already
installed fmt into the shared vcpkg. For the same reason A needs a shared vcpkg that does not
have fmt/nlohmann-json installed yet (fresh CI runner, or a fresh `-DVB_SHARED_DIR` locally).

## By hand

```sh
cmake -S tests/find-package-fallback/basic -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> [-DVCPKG_BOOTSTRAP_ISOLATED=ON]
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/find-package-fallback/run.cmake
cmake -DVB_SCRIPT_DIR=<checkout of main> -DVB_ISOLATED=ON -P tests/find-package-fallback/run.cmake
```
