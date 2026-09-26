# vcpkg-bootstrap — integration tests

[![Linux](https://github.com/mrom1/vcpkg-bootstrap/actions/workflows/ci-linux.yml/badge.svg?branch=testing)](https://github.com/mrom1/vcpkg-bootstrap/actions/workflows/ci-linux.yml)
[![Windows](https://github.com/mrom1/vcpkg-bootstrap/actions/workflows/ci-windows.yml/badge.svg?branch=testing)](https://github.com/mrom1/vcpkg-bootstrap/actions/workflows/ci-windows.yml)
[![macOS](https://github.com/mrom1/vcpkg-bootstrap/actions/workflows/ci-macos.yml/badge.svg?branch=testing)](https://github.com/mrom1/vcpkg-bootstrap/actions/workflows/ci-macos.yml)

This branch holds the integration tests of [vcpkg-bootstrap](https://github.com/mrom1/vcpkg-bootstrap)
(`vcpkg-bootstrap.cmake` on `main`). The workflows here run on pushes to this branch and are
dispatched by `main` for every push, every tag and once a week, with the commit or tag of `main`
to test (`script_ref`).

Every folder in [`tests/`](tests) is one self-contained case:

- `README.md` — what the case proves, the expected result, and the plain cmake commands to
  reproduce it by hand;
- the project files, written exactly as a user would write them (the FetchContent snippet with
  `GIT_TAG main`);
- `run.cmake` — the automated check, run with `cmake -P`. It is plain CMake, identical on all
  operating systems, locally and in CI. The helper block at the top of each `run.cmake` is the
  same in every case, so each file can be read and copied on its own.

The tests take the script from a local checkout of `main` through
`-DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=...`; the project files never contain test variables.
Only `release-fetch` really downloads a tag from GitHub.

## Cases

Modes: **shared** = `VCPKG_BOOTSTRAP_ISOLATED=OFF` (vcpkg in the per-user cache or an existing vcpkg),
**isolated** = `ON` (vcpkg and all packages in the build directory).

| Case | What it proves | Modes |
| --- | --- | --- |
| [`example`](tests/example) | The project on the `example` branch works as published | shared, isolated |
| [`manifest-file`](tests/manifest-file) | Standard use: `vcpkg.json` + `find_package()`; vcpkg in the right place; re-configure clones nothing | shared, isolated |
| [`include-file`](tests/include-file) | `vcpkg-bootstrap.cmake` copied into the project and included before `project()`, no FetchContent | shared, isolated |
| [`manifest-file-baseline`](tests/manifest-file-baseline) | `builtin-baseline`: a managed vcpkg older than the baseline is fetched, moved forward and re-bootstrapped | shared |
| [`bundled-vcpkg`](tests/bundled-vcpkg) | A bundled vcpkg in `VCPKG_ROOT` (Visual Studio's) is only used for a manifest with a baseline | shared |
| [`install-function`](tests/install-function) | `vcpkg_bootstrap_install()` installs ports in classic mode into `<vcpkg root>/installed` | shared, isolated |
| [`install-function-manifest-mode`](tests/install-function-manifest-mode) | `vcpkg_bootstrap_install()` is a no-op with a warning in manifest mode, and fails before `project()` | shared |
| [`find-package-fallback`](tests/find-package-fallback) | Plain `find_package(... REQUIRED)` installs the matching vcpkg port if the package is not found elsewhere | shared, isolated |
| [`find-package-guard`](tests/find-package-guard) | Meta-ports, `QUIET` probes and unknown packages are never installed | shared |
| [`conan-toolchain`](tests/conan-toolchain) | `conan_toolchain.cmake` is chainloaded; Conan's package wins, vcpkg fills the rest | shared |
| [`conan-provider`](tests/conan-provider) | cmake-conan's provider wins over the fallback; explicit installs still work | shared |
| [`chainload-toolchain`](tests/chainload-toolchain) | A user toolchain (`-D` or `ENV{CMAKE_TOOLCHAIN_FILE}`) is chainloaded | shared |
| [`user-vcpkg-toolchain`](tests/user-vcpkg-toolchain) | A vcpkg toolchain given by the user wins; the script defers | shared |
| [`external-vcpkg`](tests/external-vcpkg) | `VCPKG_ROOT` / `VCPKG_BOOTSTRAP_ROOT_DIR` are used as-is and never modified; warning if older than the baseline | shared |
| [`include-after-project`](tests/include-after-project) | Fetched after `project()`: warning, no-op, no "Unknown CMake command" | shared |
| [`subproject`](tests/subproject) | Consumed by a parent with and without vcpkg-bootstrap | shared |
| [`existing-build-dir`](tests/existing-build-dir) | A build directory configured before without vcpkg: clear error, nothing cloned | shared |
| [`toolchain-switch`](tests/toolchain-switch) | vcpkg location changed in an existing build directory: clear error, nothing cloned | shared |
| [`env-vcpkg-switch`](tests/env-vcpkg-switch) | Only the environment (`VCPKG_ROOT`) changed for an existing build directory: the configured vcpkg is kept | shared |
| [`stale-provider`](tests/stale-provider) | A leftover provider entry after removing vcpkg-bootstrap is harmless | shared |
| [`release-fetch`](tests/release-fetch) | A release tag fetched from GitHub works (CI: tags only) | shared |

## Running a case locally

You need CMake ≥ 3.24, git, a C++ compiler and, for the `conan-*` cases, Conan 2 (`pip install conan`).

The tests need a checkout of `main` (the script under test) and, for the `example` case, of
`example`. Any directory works; the layout CI uses is `_script/` and `_example/` in the repository
root (both git-ignored, delete them whenever you like):

```sh
git clone -b main    . _script            # the script under test (git -C _script pull to update)
git clone -b example . _example           # only for the "example" case

cmake -DVB_SCRIPT_DIR=_script -P tests/manifest-file/run.cmake
cmake -DVB_SCRIPT_DIR=_script -DVB_ISOLATED=ON -P tests/manifest-file/run.cmake
cmake -DVB_SCRIPT_DIR=_script -DVB_EXAMPLE_DIR=_example -P tests/example/run.cmake
```

Inputs of every `run.cmake`:

| Variable | Required | Meaning |
| --- | --- | --- |
| `VB_SCRIPT_DIR` | yes (except `release-fetch`) | Checkout of `main`, passed as `FETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP` |
| `VB_SCRIPT_TAG` | only `release-fetch` | Tag to fetch from GitHub |
| `VB_ISOLATED` | no (`OFF`) | `VCPKG_BOOTSTRAP_ISOLATED` for cases that run in both modes |
| `VB_WORK_DIR` | no (`<repo>/_work`) | Build directories, clones and logs (`<work>/logs/<case>-<mode>/<step>.log`) |
| `VB_EXAMPLE_DIR` | only `example` | Checkout of the `example` branch |
| `VB_SHARED_DIR` | no | Passed as `VCPKG_BOOTSTRAP_INSTALL_DIR`, so your real per-user vcpkg cache stays untouched |

Shared mode uses the real per-user cache (`%LOCALAPPDATA%/vcpkg-bootstrap`,
`~/.cache/vcpkg-bootstrap`) unless `VB_SHARED_DIR` is set. Classic-mode installs go into that
shared vcpkg (`<root>/installed`), so `find-package-fallback` needs a shared vcpkg that does not
have fmt/nlohmann-json installed yet — in CI every job starts on a fresh runner; locally use a
fresh `VB_SHARED_DIR` (the case stops with an explanation otherwise).

## CI

`.github/workflows/ci-{linux,windows,macos}.yml` are identical except for the runner. Each matrix
entry runs one `cmake -P tests/<case>/run.cmake`; on failure the logs are uploaded as an artifact.
`release-fetch` runs only when the dispatched `script_ref` is a tag (`v*`).

Adding a case: a new self-contained folder in `tests/` plus one `include` line in all three workflows.
