# external-vcpkg

**Cases V3, V4.** A vcpkg the user already has is used as-is. vcpkg-bootstrap never fetches,
checks out or bootstraps a vcpkg it did not create.

- **A:** the user's vcpkg is found through the environment variable `VCPKG_ROOT`.
  Expected: `Using vcpkg (ENV{VCPKG_ROOT})`, `VCPKG_BOOTSTRAP_ROOT` = that vcpkg; build, run:
  `Hello World!`; `git rev-parse HEAD` and `git status --porcelain` of the vcpkg are unchanged.
- **B:** the same vcpkg given with `-DVCPKG_BOOTSTRAP_ROOT_DIR=<dir>` (environment variable not set).
  Expected: `Using vcpkg (VCPKG_BOOTSTRAP_ROOT_DIR)`, rest as A.
- **C — [`old-baseline/`](old-baseline):** the user's vcpkg is a checkout of an older release
  (`2025.12.12`) than the manifest's `builtin-baseline` (`2026.07.29`). Expected: warning
  `is older than builtin-baseline` (the configure itself may then fail in vcpkg), and the
  vcpkg checkout is still unchanged.

Mode: shared only. The test makes shallow clones of vcpkg as "the user's vcpkg" and bootstraps them.

## By hand

```sh
git clone --depth 1 https://github.com/microsoft/vcpkg.git ext && ./ext/bootstrap-vcpkg.sh
VCPKG_ROOT=$PWD/ext cmake -S tests/external-vcpkg -B build-a -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
cmake -S tests/external-vcpkg -B build-b -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> -DVCPKG_BOOTSTRAP_ROOT_DIR=$PWD/ext

git clone --depth 1 --branch 2025.12.12 https://github.com/microsoft/vcpkg.git ext-old && ./ext-old/bootstrap-vcpkg.sh
VCPKG_ROOT=$PWD/ext-old cmake -S tests/external-vcpkg/old-baseline -B build-c -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/external-vcpkg/run.cmake
```
