# SFCGAL Swift Package

A Swift Package that wraps [SFCGAL](https://sfcgal.gitlab.io/SFCGAL/) to make its computational geometry functionality accessible directly from Swift.

## Goal

Provide a native Swift interface to the full SFCGAL library, enabling Swift projects to leverage advanced 2D and 3D geometry operations — including boolean operations, triangulation, Minkowski sums, and more — through the Swift Package Manager.

## Background

**SFCGAL** is a C++ library built on top of [CGAL](https://www.cgal.org/) (Computational Geometry Algorithms Library) that provides ISO 19107:2013 and OGC Simple Features Access 1.2 compliant geometry types and operations. It is commonly used as a backend for PostGIS advanced 3D functions.

### Dependency Chain

```
SFCGAL → CGAL → Boost, GMP, MPFR
```

- **CGAL** — The underlying computational geometry engine.
- **Boost** — Required by CGAL for various data structures and algorithms.
- **GMP / MPFR** — Arbitrary-precision arithmetic libraries used by CGAL for exact geometric computation.

These C/C++ dependencies may require manual configuration to build and link correctly within the Swift Package Manager environment.


### Platform-Specific

| Platform | Toolchain |
|----------|-----------|
| macOS    | Xcode 26+ |
| Ubuntu   | [Swift.org toolchain](https://www.swift.org/install/linux/) |
| Windows  | [Swift.org toolchain](https://www.swift.org/install/windows/) |

## Installing SFCGAL Dependencies

### macOS (Homebrew)

```bash
brew install sfcgal
```

This will also install CGAL, Boost, GMP, and MPFR as transitive dependencies.

### Ubuntu / Debian

```bash
sudo apt-get update
sudo apt-get install libsfcgal-dev
```

This pulls in CGAL, Boost, GMP, and MPFR automatically. On older Ubuntu releases where the packaged version is too old, you can build from source:

```bash
sudo apt-get install cmake g++ libcgal-dev libboost-all-dev libgmp-dev libmpfr-dev
git clone https://gitlab.com/sfcgal/SFCGAL.git
cd SFCGAL
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build --parallel
sudo cmake --install build
```

### Windows

Install [vcpkg](https://github.com/microsoft/vcpkg) and then:

```powershell
vcpkg install sfcgal
```

This will build and install SFCGAL along with CGAL, Boost, GMP, and MPFR.

Alternatively, install the dependencies manually with CMake:

1. Install [CMake](https://cmake.org/download/) and a C++ compiler (Visual Studio Build Tools or MinGW).
2. Install Boost, GMP, and MPFR (prebuilt binaries or via vcpkg).
3. Build and install CGAL, then SFCGAL, pointing CMake at the dependency locations.

> **Note:** On Windows, ensure the installed library paths are visible to the Swift Package Manager by setting appropriate environment variables (`LIB`, `INCLUDE`, `Path`) or by using a vcpkg toolchain file.

## Swift Interoperability with C and C++

Wrapping SFCGAL for Swift requires bridging across language boundaries. The key insight is that **we do not bundle any C/C++ source code** in this package. Instead, we rely on SFCGAL being installed on the system (via Homebrew, apt, vcpkg, etc.) and use Swift Package Manager's `systemLibrary` target with `pkgConfig` to locate the headers and libraries at build time.

### How It Works: systemLibrary + pkg-config

When SFCGAL is installed on the system, it provides a `sfcgal.pc` file (a [pkg-config](https://www.freedesktop.org/wiki/Software/pkg-config/) descriptor). For example, a Homebrew install produces:

```
# sfcgal.pc
prefix=/opt/homebrew/Cellar/sfcgal/2.2.0_2
libdir=${prefix}/lib
includedir=${prefix}/include

Name: sfcgal
Description: A wrapper around CGAL ...
Version: 2.2.0
Libs: -L${libdir} -lSFCGAL
Cflags: -I${includedir}
```

SPM reads this file to automatically resolve the correct `-I` (header) and `-L`/`-l` (linker) flags. No manual path configuration is needed — the system package manager handles the entire SFCGAL/CGAL/Boost/GMP/MPFR dependency tree, and `pkg-config` tells SPM where everything lives.


### Swift C++ Interoperability Resources

#### Official Docs
- [Mixing Swift and C++](https://www.swift.org/documentation/cxx-interop/) — the primary reference guide
- [C++ Interop Status Page](https://www.swift.org/documentation/cxx-interop/status/) — tracks what's supported vs. not
- [WWDC23 "Mix Swift and C++"](https://developer.apple.com/videos/play/wwdc2023/10172/) — practical walkthrough by Apple engineers

### Sample Projects & Hands-on Code
- 🛠️ [swiftlang/swift on GitHub](https://github.com/swiftlang/swift/blob/main/docs/CppInteroperability/GettingStartedWithC++Interop.md) — official getting-started doc with working package examples

### Package Structure

The package needs a thin `systemLibrary` target that contains only a `module.modulemap` (and optionally an umbrella header). This target has no Swift or C source files — it just tells the Swift compiler how to import the system-installed C API:

```
Sources/
  CSFCGAL/
    include/
      module.modulemap   // maps the installed C headers for Swift import
      shim.h             // #include <SFCGAL/capi/sfcgal_c.h>
```

An example `module.modulemap`:

```modulemap
module CSFCGAL {
    umbrella header "shim.h"
    link "SFCGAL"
    export *
}
```

And the corresponding `shim.h`:

```c
#include <SFCGAL/capi/sfcgal_c.h>
```

In `Package.swift`, this is declared as:

```swift
.systemLibrary(
    name: "CSFCGAL",
    pkgConfig: "sfcgal",
    providers: [
        .brew(["sfcgal"]),
        .apt(["libsfcgal-dev"])
    ]
)
```

The `providers` field is informational — if the library isn't found, SPM will suggest the appropriate install command for the user's platform.

The Swift wrapper target then depends on this system library:

```swift
.target(
    name: "SFCGAL",
    dependencies: ["CSFCGAL"]
)
```

After this, Swift code can `import CSFCGAL` to call the C API directly, and the `SFCGAL` target provides an idiomatic Swift layer on top.

### Why the C API (Not Direct C++ Interop)

SFCGAL exposes a [C API](https://sfcgal.gitlab.io/SFCGAL/group__capi.html) (`SFCGAL/capi/sfcgal_c.h`) that covers most of its functionality through opaque pointers and plain C functions. We use this rather than Swift's direct C++ interop (available since Swift 5.9 via `.interoperabilityMode(.Cxx)`) for several reasons:

| Concern | C API approach | Direct C++ interop |
|---------|---------------|-------------------|
| **Template-heavy code** | Not an issue — C API uses opaque pointers | CGAL/Boost templates cannot be imported by Swift; requires shim layers |
| **Boost headers** | Not exposed | Too complex for the Swift/C++ bridge |
| **Module maps** | Simple — one header, one link directive | Very difficult with CGAL/Boost transitive headers |
| **Platform compatibility** | Works everywhere pkg-config is available | Linker differences between libc++ (macOS), libstdc++ (Linux), and MSVC (Windows) add complexity |
| **Memory management** | Explicit create/destroy — wrapped with Swift `deinit` | Mixed ownership models are harder to get right |

### Platform Considerations for pkg-config

| Platform | pkg-config availability |
|----------|------------------------|
| macOS (Homebrew) | `sfcgal.pc` installed automatically by `brew install sfcgal` |
| Ubuntu / Debian | `sfcgal.pc` installed by `apt install libsfcgal-dev` |
| Windows | Not standard. May need to set `PKG_CONFIG_PATH` manually, generate a `.pc` file, or use `unsafeFlags` in `Package.swift` to specify paths directly |


## Usage

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/SFCGAL_SPM.git", from: "0.1.0")
]
```

Then add `"SFCGAL"` as a dependency of your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SFCGAL"]
)
```

## Project Structure

```
SFCGAL_SPM/
├── Package.swift
├── Sources/
│   └── SFCGAL_SPM/
│       └── SFCGAL.swift          # Swift wrapper around SFCGAL
└── Tests/
    └── SFCGAL_SPMTests/
        └── SFCGAL_Tests.swift    # Test suite
```

## Status

This project is in early development. The Swift wrapper API and build system integration for the native C/C++ dependencies are being established.

## License

TBD
