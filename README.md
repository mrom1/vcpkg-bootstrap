# vcpkg-bootstrap example

A minimal C++ project that gets its dependencies from [vcpkg](https://github.com/microsoft/vcpkg)
through [vcpkg-bootstrap](https://github.com/mrom1/vcpkg-bootstrap). Copy it as a starting point.

- [`CMakeLists.txt`](CMakeLists.txt) fetches vcpkg-bootstrap before `project()` and uses plain
  `find_package(fmt CONFIG REQUIRED)`.
- [`vcpkg.json`](vcpkg.json) lists the dependencies (`fmt`) and pins a `builtin-baseline`, so
  everyone gets the same versions.
- [`source/main.cpp`](source/main.cpp) prints `Hello World!` with fmt.

No vcpkg installation is needed: on the first configure vcpkg-bootstrap uses an existing vcpkg
(`VCPKG_ROOT`) or clones and bootstraps one, then vcpkg installs `fmt`.

Requires CMake 3.24 or newer, git and a C++ compiler.

## Build and run

```sh
cmake -S . -B build
cmake --build build --config Release
./build/main              # Windows (Visual Studio): build\Release\main.exe
```

### Isolated mode ("virtual environment")

```sh
cmake -S . -B build -DVCPKG_BOOTSTRAP_ISOLATED=ON
```

vcpkg and all packages are then kept in the build folder; deleting it removes everything.
By default (`OFF`) one vcpkg clone is shared by all your projects.

## Adding dependencies

1. Add the port to `"dependencies"` in `vcpkg.json` (port names: [vcpkg.io](https://vcpkg.io/en/packages)).
2. Add `find_package(...)` and `target_link_libraries(...)` to `CMakeLists.txt` as the port's usage text says (vcpkg prints it after installing).

To move to newer package versions, update `builtin-baseline` to a newer vcpkg commit (`vcpkg x-update-baseline`).

For a real project, pin `GIT_TAG` in `CMakeLists.txt` to a release tag or commit hash of vcpkg-bootstrap instead of `main`.

Everything else (where vcpkg comes from, other ways to get packages, cross-compiling,
troubleshooting) is in the [vcpkg-bootstrap README](https://github.com/mrom1/vcpkg-bootstrap#readme).

## License

[MIT](LICENSE)
