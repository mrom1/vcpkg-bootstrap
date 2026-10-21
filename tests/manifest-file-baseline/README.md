# manifest-file-baseline

**Cases V7, V10.** `vcpkg.json` pins a `builtin-baseline` (vcpkg release `2026.07.29`), the
recommended way to get reproducible builds. vcpkg reads the versions database from its working
tree, so a vcpkg managed by vcpkg-bootstrap must contain the baseline commit. vcpkg's own
version is part of every package's ABI hash, so new and isolated clones are put on exactly the
baseline (same packages from the binary cache in every build directory).

- **A:** fresh managed clone (`-DVCPKG_BOOTSTRAP_INSTALL_DIR=<run dir>/managed`). Expected:
  `[vcpkg-bootstrap] Cloning`, `Checking out builtin-baseline <baseline>`, `Bootstrapping`;
  the clone's HEAD is exactly the baseline (not vcpkg's latest commit); build, run: `Hello World!`.
- **B:** an existing managed clone that is older than the baseline: full history up to
  release `2025.12.12`, without the baseline commit (what a clone made months ago looks like).
  Expected: `[vcpkg-bootstrap] Fetching vcpkg (need <baseline>)`,
  `Updating vcpkg to builtin-baseline`, `Bootstrapping`; no new clone; HEAD now contains the
  baseline; build, run: `Hello World!`.
- **C:** a second configure of B does not clone, fetch or bootstrap.
- **D:** an existing shared clone that is newer than the baseline (vcpkg's `master`). Expected:
  no clone, fetch, checkout or bootstrap; HEAD stays where it was (the shared clone serves other
  projects and only moves forward); build, run: `Hello World!`.
- **E:** an existing isolated clone (`<build>/vcpkg`, `-DVCPKG_BOOTSTRAP_ISOLATED=ON`) that is
  newer than the baseline. Expected: `Checking out builtin-baseline <baseline>`, `Bootstrapping`;
  no new clone; HEAD is exactly the baseline; build, run: `Hello World!`.
- **F:** a second configure of E does not clone, fetch, check out or bootstrap.

Mode: shared, with its own managed directories in the run directory (independent of the user
cache); E and F set isolated mode themselves.

## By hand

```sh
cmake -S tests/manifest-file-baseline -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> \
      -DVCPKG_BOOTSTRAP_INSTALL_DIR=$PWD/managed
cmake --build build --config Release

# older clone:
git clone --single-branch --branch 2025.12.12 https://github.com/microsoft/vcpkg.git managed2/vcpkg
git -C managed2/vcpkg config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
./managed2/vcpkg/bootstrap-vcpkg.sh
cmake -S tests/manifest-file-baseline -B build2 -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> \
      -DVCPKG_BOOTSTRAP_INSTALL_DIR=$PWD/managed2
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/manifest-file-baseline/run.cmake
```
