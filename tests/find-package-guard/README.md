# find-package-guard

**Cases G1–G3.** Where the `find_package()` fallback (see [`find-package-fallback`](../find-package-fallback))
must **not** install anything:

| Call | Why nothing is installed |
| --- | --- |
| `find_package(Boost)` | vcpkg's `boost` port is a meta-port (it would pull in all of Boost); `boost-cmake` mentions `find_package(Boost` in its usage but is a CMake helper port |
| `find_package(fmt CONFIG QUIET)` | `QUIET` without `REQUIRED` is a probe |
| `find_package(VbDefinitelyNotAPackage)` | no vcpkg port provides it |

Expected: configure succeeds; `fmt_FOUND` is empty/0/FALSE; no `installing vcpkg port ...` for
any of them; `<build>/vcpkg-bootstrap/install.log` does not exist; build, run: `Hello World!`.

Mode: shared only. The test passes vcpkg's `-DVCPKG_INSTALLED_DIR=<build>/vcpkg_installed`, so
packages another project installed into the shared vcpkg do not make `fmt` "found".

## By hand

```sh
cmake -S tests/find-package-guard -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> \
      -DVCPKG_INSTALLED_DIR=$PWD/build/vcpkg_installed
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/find-package-guard/run.cmake
```
