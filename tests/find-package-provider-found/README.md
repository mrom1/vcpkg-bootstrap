# find-package-provider-found

The `find_package()` fallback (see [`find-package-fallback`](../find-package-fallback)) is a CMake
dependency provider. When it does not answer a call itself (in manifest mode it never does),
CMake must run its own search. CMake decides that by `<Package>_FOUND` after the provider: if it
is true, the provider counts as having found the package. So a value that is true **before** the
call must not count:

| Call | Where `<Package>_FOUND` is already true |
| --- | --- |
| `find_package(VbParts COMPONENTS First)`, then `find_package(VbParts COMPONENTS Second)` | the first call set `VbParts_FOUND`; Qt finds XCB like this, one component per call |
| `find_package(VbCached)`, configured twice | the first configure cached `VbCached_FOUND`, as `pkg_check_modules(VbCached ...)` does; Qt's `FindLibb2` is one of these |

Without the search, the targets of the later call do not exist: `VbParts::Second` on the first
configure, `VbCached::VbCached` from the second configure on (with Qt on Linux: `XCB::CURSOR`,
`XCB::GLX`, `Libb2::Libb2`, ...). The find modules are in [`modules/`](modules), so no vcpkg port
is involved.

Two projects, each configured twice:

- **[`manifest/`](manifest)**: with a `vcpkg.json`, the fallback steps aside.
- **[`classic/`](classic)**: without one, the fallback searches first itself.

Expected, for both: each configure prints `All test targets exist` (and no `... does not exist`);
build, run: `Hello World!`.

Mode: shared only.

## By hand

```sh
cmake -S tests/find-package-provider-found/manifest -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main>
cmake -S tests/find-package-provider-found/manifest -B build    # again: VbCached_FOUND is cached now
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/find-package-provider-found/run.cmake
```
