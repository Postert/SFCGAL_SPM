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

Wrapping SFCGAL for Swift requires bridging across language boundaries. There are two main strategies, each with distinct trade-offs.

### Option A: Bridge via the SFCGAL C API

SFCGAL provides a [C API](https://sfcgal.gitlab.io/SFCGAL/group__capi.html) (`sfcgal_c.h`) that exposes most of its functionality through opaque pointers and plain C functions. Swift can import C libraries natively using a **system library target** with a `module.modulemap`:

```
Sources/
  CSFCGAL/
    include/
      module.modulemap   // maps the C headers for Swift
      shim.h             // #includes <sfcgal_c.h>
```

In `Package.swift`, this would be declared as:

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

This is the **simplest and most portable** approach — it works on all platforms and avoids any C++ interop complexity.

### Option B: Direct C++ Interoperability

Since Swift 5.9, Swift supports [direct C++ interop](https://www.swift.org/documentation/cxx-interop/). This allows Swift to call C++ APIs without a C shim. To enable it in `Package.swift`:

```swift
.target(
    name: "SFCGAL",
    dependencies: ["CSFCGAL"],
    swiftSettings: [
        .interoperabilityMode(.Cxx)
    ]
)
```

This could allow wrapping SFCGAL's richer C++ types directly, but comes with significant challenges (see below).


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
