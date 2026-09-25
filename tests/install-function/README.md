# install-function

**Case I1.** No `vcpkg.json`. The project asks for ports explicitly with
`vcpkg_bootstrap_install(fmt nlohmann-json)` after `project()`, then uses plain `find_package()`.

vcpkg installs the ports in classic mode, so they go where vcpkg puts classic installs by
default: `<vcpkg root>/installed`. In shared mode that is the shared vcpkg (all projects see
them); in isolated mode the vcpkg root is `<build>/vcpkg`, so everything stays in the build
directory.

Expected:

- configure prints `[vcpkg-bootstrap] Installing fmt nlohmann-json`;
- vcpkg is where the mode says (see [`manifest-file`](../manifest-file));
- `<vcpkg root>/installed/<triplet>/share/fmt` and `.../share/nlohmann-json` exist,
  `<build>/vcpkg_installed` does not;
- build, run: `Hello World!` (built through nlohmann::json, printed with fmt);
- a second configure does not clone, fetch or bootstrap.

Modes: shared and isolated.

## By hand

```sh
cmake -S tests/install-function -B build -DFETCHCONTENT_SOURCE_DIR_VCPKG_BOOTSTRAP=<checkout of main> [-DVCPKG_BOOTSTRAP_ISOLATED=ON]
cmake --build build --config Release
```

## Automated

```sh
cmake -DVB_SCRIPT_DIR=<checkout of main> -P tests/install-function/run.cmake
cmake -DVB_SCRIPT_DIR=<checkout of main> -DVB_ISOLATED=ON -P tests/install-function/run.cmake
```
