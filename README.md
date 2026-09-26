# vcpkg-bootstrap

[![Linux](https://github.com/mrom1/vcpkg-bootstrap/actions/workflows/ci-linux.yml/badge.svg?branch=testing)](https://github.com/mrom1/vcpkg-bootstrap/actions/workflows/ci-linux.yml)
[![Windows](https://github.com/mrom1/vcpkg-bootstrap/actions/workflows/ci-windows.yml/badge.svg?branch=testing)](https://github.com/mrom1/vcpkg-bootstrap/actions/workflows/ci-windows.yml)
[![macOS](https://github.com/mrom1/vcpkg-bootstrap/actions/workflows/ci-macos.yml/badge.svg?branch=testing)](https://github.com/mrom1/vcpkg-bootstrap/actions/workflows/ci-macos.yml)

A single CMake script that makes [vcpkg](https://github.com/microsoft/vcpkg) available before
`project()`: it uses an existing vcpkg or clones and bootstraps one, and sets vcpkg up as the
toolchain. After that, packages come from plain `find_package()`, and dependencies are declared
the way vcpkg documents it, in a `vcpkg.json`.

Requires **CMake 3.24** or newer, git and a C++ compiler.

## Usage

Add this to your top-level `CMakeLists.txt`, **before** the first `project()`:

```cmake
cmake_minimum_required(VERSION 3.24)

include(FetchContent)
FetchContent_Declare(vcpkg_bootstrap
  GIT_REPOSITORY https://github.com/mrom1/vcpkg-bootstrap.git
  GIT_TAG        main              # better: a release tag or commit hash
)
# Optional: isolated mode keeps vcpkg and all packages in the build folder.
option(VCPKG_BOOTSTRAP_ISOLATED "Virtual Environment Mode" OFF)
FetchContent_MakeAvailable(vcpkg_bootstrap)

project(myproject CXX)

find_package(fmt CONFIG REQUIRED)
```

and list your dependencies in a [`vcpkg.json`](https://learn.microsoft.com/vcpkg/reference/vcpkg-json)
next to it:

```json
{
  "dependencies": [ "fmt" ]
}
```

That's all: configure as usual (`cmake -S . -B build`). A complete, working project lives on the
[`example`](https://github.com/mrom1/vcpkg-bootstrap/tree/example) branch.

### Without FetchContent: copy the file

`vcpkg-bootstrap.cmake` is self-contained. Copy it into your project and include it before
`project()`:

```cmake
cmake_minimum_required(VERSION 3.24)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/vcpkg-bootstrap.cmake)

project(myproject CXX)
```

## Isolated mode ("virtual environment")

| `VCPKG_BOOTSTRAP_ISOLATED` | Where vcpkg comes from | Where packages are installed |
| --- | --- | --- |
| `OFF` (default) | An existing vcpkg if there is one (see below), otherwise one shared clone in a per-user cache, used by all your projects | vcpkg's defaults: `<build>/vcpkg_installed` with a `vcpkg.json`, otherwise `<vcpkg>/installed` |
| `ON` | A private clone in `<build>/vcpkg`; `VCPKG_ROOT` is ignored | Everything stays in the build folder |

With `ON`, deleting the build folder removes vcpkg and every package it installed; nothing is
written outside of it. The price is a full vcpkg clone and bootstrap per build folder.

Choose the mode on the first configure of a build folder (`-DVCPKG_BOOTSTRAP_ISOLATED=ON`). It is
remembered; changing it later in the same build folder is refused with an error (see
[Troubleshooting](#troubleshooting)).

## Where vcpkg comes from

The first match wins:

| # | Source | Modified by the script? |
| --- | --- | --- |
| 1 | `-DVCPKG_BOOTSTRAP_ROOT_DIR=<dir>`: an existing vcpkg checkout | never |
| 2 | Isolated mode: `<build>/vcpkg` | cloned, updated, bootstrapped |
| 3 | The `VCPKG_ROOT` environment variable: your own vcpkg, a CI runner's vcpkg, ... | never |
| 4 | A shared clone in `<VCPKG_BOOTSTRAP_INSTALL_DIR>/vcpkg` or the per-user cache | cloned, updated, bootstrapped |

Per-user cache: `%LOCALAPPDATA%\vcpkg-bootstrap\vcpkg` on Windows,
`$XDG_CACHE_HOME/vcpkg-bootstrap/vcpkg` or `~/.cache/vcpkg-bootstrap/vcpkg` on Linux and macOS.
It is cloned and bootstrapped once and shared by all projects and build folders.

- A vcpkg **toolchain you pass yourself** (`-DCMAKE_TOOLCHAIN_FILE=<vcpkg>/scripts/buildsystems/vcpkg.cmake`,
  a preset, an IDE integration) always wins: the script then only uses it.
- **Visual Studio** sets `VCPKG_ROOT` to its bundled vcpkg, which has no ports of its own and
  only works with a `vcpkg.json` that has a `builtin-baseline` (vcpkg's own rule). Without such a
  manifest the script says so and uses the shared clone instead.
- vcpkg checkouts the script did not create are only read. If one is older than your
  `builtin-baseline`, you get a warning telling you to update it.
- Clones made by the script are full clones (vcpkg's versioning needs the history). A file lock
  makes parallel configures safe. To start over, delete the directory.

## Getting packages

1. **`vcpkg.json` (recommended).** vcpkg's manifest mode: everything listed is installed during
   configure into `<build>/vcpkg_installed`.
2. **`vcpkg_bootstrap_install(<port>...)`** after `project()`, anywhere in the tree, for
   projects without a manifest:

   ```cmake
   project(myproject CXX)
   vcpkg_bootstrap_install(fmt nlohmann-json)
   find_package(fmt CONFIG REQUIRED)
   find_package(nlohmann_json CONFIG REQUIRED)
   ```

   Port names use vcpkg syntax (`fmt`, `fmt[core]`). This is `vcpkg install` in classic mode, so
   the packages go to `<vcpkg>/installed`. In manifest mode the call does nothing and warns
   about ports missing from `vcpkg.json`.
3. **Plain `find_package(<Name> ... REQUIRED)`** without a manifest (an extra of this project,
   not vcpkg behaviour): if `<Name>` is not found anywhere else (system, other toolchains, prefix
   paths), the vcpkg port that provides it is installed. It is deliberately strict: never for
   `find_package(... QUIET)` without `REQUIRED`, never meta-ports like `boost`, never guessed
   names. If a package is not picked up, use `vcpkg_bootstrap_install(<port>)`.

## Versions

- **Ports:** set `builtin-baseline` in `vcpkg.json` for reproducible builds
  (`vcpkg x-update-baseline --add-initial-baseline`). Without a baseline, versions come from
  whatever commit the vcpkg checkout is on — not "the latest".
- If a vcpkg clone made by the script does not contain your baseline yet, it is fetched once,
  moved forward to the baseline and bootstrapped again. Otherwise configure does not go to the
  network for vcpkg itself.
- **vcpkg itself:** `-DVCPKG_BOOTSTRAP_REF=<tag or commit>` checks out that vcpkg release in a
  clone made by the script. The shared clone is shared, so give projects that pin different refs
  their own `VCPKG_BOOTSTRAP_INSTALL_DIR` (or use isolated mode).
- **The script:** pin `GIT_TAG` to a release tag or commit hash.

## Cross-compiling and other toolchains

A toolchain you already use (`-DCMAKE_TOOLCHAIN_FILE`, a preset, or the `CMAKE_TOOLCHAIN_FILE`
environment variable) is not replaced: it is passed to vcpkg as `VCPKG_CHAINLOAD_TOOLCHAIN_FILE`,
so Android, Emscripten and embedded toolchains keep working. Select the vcpkg triplet as usual,
e.g. `-DVCPKG_TARGET_TRIPLET=arm64-android`.

## Conan and other dependency providers

- `conan_toolchain.cmake` as toolchain is chainloaded; packages found through Conan are used from
  Conan, and the `find_package()` fallback only fills in what is missing.
- If another dependency provider is configured (e.g. [cmake-conan](https://github.com/conan-io/cmake-conan)
  in `CMAKE_PROJECT_TOP_LEVEL_INCLUDES`), it takes precedence and the fallback is off (the script
  says so). `vcpkg.json` and `vcpkg_bootstrap_install()` keep working.

## Offline and local development

Once vcpkg is cloned and contains your baseline, configuring only needs the network for ports
that vcpkg has not built or cached yet. To use a local copy of this repository instead of
downloading it:

```sh
cmake -S . -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=/path/to/vcpkg-bootstrap
```

## Troubleshooting

- **"configured before without vcpkg's toolchain"** / **"The vcpkg location changed"**: CMake
  reads the toolchain file only on the first configure of a build folder. Delete the build
  folder (or its `CMakeCache.txt`) and configure again.
- **"The environment points to another vcpkg … keeping …"**: the same build folder was
  configured from a different shell, e.g. once from a plain terminal and once from a Visual
  Studio developer prompt (or an IDE that loads it, like VS Code's CMake Tools), which sets
  `VCPKG_ROOT` to its bundled vcpkg. When only the environment differs, the vcpkg the folder was
  configured with is kept. A location you choose with a setting (`VCPKG_BOOTSTRAP_ROOT_DIR`,
  `VCPKG_BOOTSTRAP_ISOLATED`, `VCPKG_BOOTSTRAP_INSTALL_DIR`) still fails with the error above.
- **"older than builtin-baseline"**: your own vcpkg (`VCPKG_ROOT`, `VCPKG_BOOTSTRAP_ROOT_DIR`) is
  outdated: `git -C <vcpkg> pull`, then run its `bootstrap-vcpkg` script.
- **Included after `project()`**: the script only warns and does nothing; move it before the first
  `project()` call.
- **A package is not installed automatically**: list it in `vcpkg.json`, or call
  `vcpkg_bootstrap_install(<port>)` before `find_package()`.

## Known limitations

- Dependencies declared with `FetchContent_Declare(... FIND_PACKAGE_ARGS ...)` go through
  `find_package()` first, so without a manifest they may come from vcpkg instead of being fetched.
- Tool ports whose usage declares a CMake package (e.g. `Python3`) are installed when that package
  is really missing.

## Reference

| Variable | Default | Meaning |
| --- | --- | --- |
| `VCPKG_BOOTSTRAP_ISOLATED` | `OFF` | vcpkg and all packages in the build folder; `VCPKG_ROOT` ignored |
| `VCPKG_BOOTSTRAP_ROOT_DIR` | — | Use this existing vcpkg as-is (wins over everything) |
| `VCPKG_BOOTSTRAP_INSTALL_DIR` | per-user cache | Shared mode: manage vcpkg in `<dir>/vcpkg` |
| `VCPKG_BOOTSTRAP_REF` | — | vcpkg tag or commit for a clone made by the script |
| `VCPKG_BOOTSTRAP_DISABLE` | `OFF` | Do nothing |
| `VCPKG_BOOTSTRAP_ROOT` | output | The vcpkg root in use (cache) |

Relative paths are relative to the top-level source directory. vcpkg's own variables
(`VCPKG_MANIFEST_DIR`, `VCPKG_MANIFEST_MODE`, `VCPKG_TARGET_TRIPLET`, `VCPKG_INSTALLED_DIR`,
`VCPKG_OVERLAY_PORTS`, `VCPKG_OVERLAY_TRIPLETS`, `VCPKG_INSTALL_OPTIONS`) work as documented by vcpkg.

Function: `vcpkg_bootstrap_install(<port>...)` — see [Getting packages](#getting-packages).

## Branches

- [`example`](https://github.com/mrom1/vcpkg-bootstrap/tree/example): a minimal, copyable project.
- [`testing`](https://github.com/mrom1/vcpkg-bootstrap/tree/testing): the integration tests
  (one self-contained folder per case) and the CI behind the badges.

## License

[MIT](LICENSE)
