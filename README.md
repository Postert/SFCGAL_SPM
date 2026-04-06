# SwiftSFCGAL

A Swift Package wrapping the [SFCGAL](https://sfcgal.gitlab.io/SFCGAL/) computational geometry library for iOS, macOS, Linux, and Windows.

## Overview

SwiftSFCGAL provides idiomatic Swift access to SFCGAL's full suite of 2D and 3D computational geometry operations — triangulation, Boolean operations, measurements, straight skeletons, extrusions, and more. It is designed primarily for iOS (ARKit/RealityKit pipelines, CityGML rendering), with macOS, Linux, and Windows as secondary targets.

SFCGAL is a C++ library built on top of [CGAL](https://www.cgal.org/) (the Computational Geometry Algorithms Library) that provides ISO 19107:2013 and OGC Simple Features Access 1.2 compliant geometry types and operations. It serves as the geometry backend for PostGIS's 3D spatial functions and is an [OSGeo project](https://www.osgeo.org/projects/sfcgal/).

## Supported platforms

| Platform | Toolchain | SFCGAL source |
|----------|-----------|---------------|
| macOS    | Xcode 16+ | System library via Homebrew |
| Linux (Ubuntu/Debian) | [Swift.org toolchain](https://www.swift.org/install/linux/) | Built from source (Ubuntu's apt ships an older version) |
| Windows  | [Swift.org toolchain](https://www.swift.org/install/windows/) + Visual Studio 2022 | Built from source with vcpkg dependencies |
| iOS / tvOS / watchOS / visionOS | Xcode 16+ | Prebuilt XCFrameworks (downloaded automatically by SPM) |

## Version pinning

SwiftSFCGAL pins an **exact** SFCGAL version (currently **2.2.0**) and enforces this at compile time via a C++ `static_assert` in [`version_check.cc`](Sources/CSFCGAL_Shim/version_check.cc). If the installed SFCGAL version does not match, the build fails with a clear error message. This guarantees that the Swift wrapper, the system library, and the iOS XCFrameworks are always binary-compatible.

The required version is defined in a single place:

```c
// Sources/CSFCGAL_Shim/include/sfcgal_swift_shim.h
#define SWIFTSFCGAL_REQUIRED_VERSION "2.2.0"
```

## Usage

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Postert/SFCGAL_SPM.git", from: "0.1.0")
]
```

Then add `"SwiftSFCGAL"` as a dependency of your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "SwiftSFCGAL", package: "SwiftSFCGAL")
    ]
)
```

## Development setup

### Prerequisites

| Platform | Swift | Additional tooling |
|----------|-------|--------------------|
| macOS | Included with Xcode 16+ | [Homebrew](https://brew.sh/) |
| Linux | [Swift.org toolchain](https://www.swift.org/install/linux/) (6.1+) | `cmake`, `pkg-config`, C/C++ compiler |
| Windows | [Swift.org toolchain](https://www.swift.org/install/windows/) (6.1+) | Visual Studio 2022, [vcpkg](https://vcpkg.io/), CMake, Ninja |
| iOS | Included with Xcode 16+ | None — XCFrameworks are downloaded automatically |

### macOS

SFCGAL is available via Homebrew as a single install:

```bash
brew install sfcgal

# Verify the installed version matches the one pinned by SwiftSFCGAL (2.2.0):
pkg-config --modversion sfcgal

# Build and test:
swift build
swift test
```

> **Tip:** You can also open the package in Xcode and build/test from there.

### Linux (Ubuntu / Debian)

Ubuntu's `apt` repositories ship an older SFCGAL (1.5.1 on 24.04 LTS), which does not match the pinned version. You need to build SFCGAL **2.2.0** from source.

**1. Install build dependencies:**

```bash
sudo apt-get update
sudo apt-get install -y \
    cmake \
    libcgal-dev \
    libboost-serialization-dev \
    libgmp-dev \
    libmpfr-dev \
    pkg-config
```

**2. Build and install SFCGAL 2.2.0:**

```bash
SFCGAL_VERSION=2.2.0
SFCGAL_PREFIX=/usr/local/sfcgal

curl -sL "https://gitlab.com/sfcgal/SFCGAL/-/archive/v${SFCGAL_VERSION}/SFCGAL-v${SFCGAL_VERSION}.tar.gz" | tar xz
cd SFCGAL-v${SFCGAL_VERSION}
cmake -B build \
    -DCMAKE_INSTALL_PREFIX=${SFCGAL_PREFIX} \
    -DCMAKE_BUILD_TYPE=Release \
    -DSFCGAL_BUILD_TESTS=OFF \
    -DSFCGAL_BUILD_EXAMPLES=OFF \
    -DSFCGAL_BUILD_BENCH=OFF
cmake --build build --parallel $(nproc)
sudo cmake --install build
```

**3. Build and test SwiftSFCGAL:**

Since SFCGAL is installed to a custom prefix, you need to tell SPM and the dynamic linker where to find it:

```bash
export PKG_CONFIG_PATH="${SFCGAL_PREFIX}/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="${SFCGAL_PREFIX}/lib:$LD_LIBRARY_PATH"

# Verify:
pkg-config --modversion sfcgal   # should print 2.2.0

# Build and test:
swift build
swift test
```

### Windows

Windows requires Visual Studio 2022 (for the MSVC toolchain and CRT headers), the [Swift.org toolchain for Windows](https://www.swift.org/install/windows/), and [vcpkg](https://vcpkg.io/) for the transitive C++ dependencies (CGAL, Boost, GMP, MPFR).

**1. Build and install SFCGAL 2.2.0 from source:**

Open a **Developer Command Prompt for VS 2022** (or run `vcvars64.bat` manually) and run:

```cmd
set SFCGAL_VERSION=2.2.0
set SFCGAL_PREFIX=C:\sfcgal

curl -sL "https://gitlab.com/sfcgal/SFCGAL/-/archive/v%SFCGAL_VERSION%/SFCGAL-v%SFCGAL_VERSION%.tar.gz" | tar xz
cd SFCGAL-v%SFCGAL_VERSION%

cmake -B build -G Ninja ^
    -DCMAKE_C_COMPILER=cl ^
    -DCMAKE_CXX_COMPILER=cl ^
    -DCMAKE_INSTALL_PREFIX=%SFCGAL_PREFIX% ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_TOOLCHAIN_FILE=%VCPKG_INSTALLATION_ROOT%\scripts\buildsystems\vcpkg.cmake ^
    -DSFCGAL_BUILD_TESTS=OFF ^
    -DSFCGAL_BUILD_EXAMPLES=OFF ^
    -DSFCGAL_BUILD_BENCH=OFF
cmake --build build --parallel
cmake --install build
```

> **Note:** SFCGAL ships its own `vcpkg.json` (manifest mode), so vcpkg automatically downloads and builds the correct versions of CGAL, Boost, GMP, and MPFR during the CMake configure step. No manual `vcpkg install` is needed.

**2. Bundle runtime DLLs:**

SFCGAL's vcpkg manifest pins specific dependency versions (e.g. Boost 1.86) that may differ from a global vcpkg install. Copy the DLLs that SFCGAL was actually linked against into the install directory so the Windows loader can find them at runtime:

```cmd
copy /Y build\vcpkg_installed\x64-windows\bin\*.dll %SFCGAL_PREFIX%\bin\
```

**3. Build and test SwiftSFCGAL:**

SPM's built-in pkg-config parser cannot handle the `.pc` file that SFCGAL's CMake generates on Windows (it has an empty `prefix=` variable). Instead, pass paths through the native MSVC environment variables. From a **Developer Command Prompt**:

```cmd
set "PATH=%SFCGAL_PREFIX%\bin;%PATH%"
set "LIB=%SFCGAL_PREFIX%\lib;%LIB%"
set "INCLUDE=%SFCGAL_PREFIX%\include;%INCLUDE%"

swift build -Xcc -I%SFCGAL_PREFIX%/include
swift test  -Xcc -I%SFCGAL_PREFIX%/include
```

> **Note:** The `vcvars64.bat` path varies by Visual Studio edition:
> - **Community:** `C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat`
> - **Professional:** replace `Community` with `Professional`
> - **Enterprise:** replace `Community` with `Enterprise`

### iOS / tvOS / watchOS / visionOS

**No setup required.** The prebuilt XCFrameworks (SFCGAL, GMP, MPFR) are hosted on GitHub releases and downloaded automatically by SPM when you add the package. Just add the dependency to your Xcode project or `Package.swift` and build.

To verify the iOS build from the command line:

```bash
xcodebuild build \
    -scheme SwiftSFCGAL \
    -destination 'generic/platform=iOS Simulator'
```

If you need to rebuild the XCFrameworks from source (e.g. to target a different SFCGAL version), see [`scripts/create-xcframeworks.sh`](scripts/create-xcframeworks.sh) and the [build-xcframeworks workflow](.github/workflows/build-xcframeworks.yml).

## Architecture

### Why a C API bridge (not Swift-C++ interop)

SFCGAL depends on CGAL, which is one of the most template-heavy C++ libraries in existence. Swift's C++ interoperability (introduced in Swift 5.9) **cannot import uninstantiated C++ templates** — it only supports explicitly pre-instantiated specializations exposed via `typedef` or `using`. CGAL's architecture is built entirely on template metaprogramming: geometric kernels parameterized on number types, traits classes, template template parameters, and deep Boost dependency chains. Additional unsupported features critical to CGAL include rvalue references, C++ exceptions, variadic templates, and `std::function`.

Attempting to pre-instantiate all needed CGAL types is impractical given the sheer volume and interdependency of CGAL's template graph. **Direct Swift-C++ interop with CGAL is a dead end.**

Instead, this package bridges through **SFCGAL's existing C API** (`sfcgal_c.h`), which uses the opaque pointer pattern — all geometry types are represented as `typedef void sfcgal_geometry_t*` with create/access/delete functions. This C API covers roughly 70-80% of SFCGAL's full functionality and is the same API used by PostGIS, PySFCGAL (Python), and sfcgal-rs (Rust).

**Performance impact: zero.** C function calls from Swift have no measurable overhead in release builds. The computational geometry operations themselves (triangulation, Boolean ops, etc.) are orders of magnitude more expensive than the function-call boundary.

| Concern | C API approach | Direct C++ interop |
|---------|---------------|-------------------|
| **Template-heavy code** | Not an issue — C API uses opaque pointers | CGAL/Boost templates cannot be imported by Swift; requires shim layers |
| **Boost headers** | Not exposed | Too complex for the Swift/C++ bridge |
| **Module maps** | Simple — one header, one link directive | Very difficult with CGAL/Boost transitive headers |
| **Platform compatibility** | Works everywhere pkg-config is available | Linker differences between libc++ (macOS), libstdc++ (Linux) add complexity |
| **Memory management** | Explicit create/destroy — wrapped with Swift `deinit` | Mixed ownership models are harder to get right |

For background on Swift's C++ interoperability capabilities and limitations, see [Mixing Swift and C++](https://www.swift.org/documentation/cxx-interop/) and the [C++ Interop Status Page](https://www.swift.org/documentation/cxx-interop/status/).

### C API coverage

The SFCGAL C API (`sfcgal_c.h`) exposes:

- **All geometry types:** Point, LineString, Polygon, Triangle, MultiPoint, MultiLineString, MultiPolygon, GeometryCollection, PolyhedralSurface, TriangulatedSurface, Solid
- **I/O:** WKT, EWKT, WKB reading and writing
- **Predicates:** intersects, covers (2D and 3D)
- **Boolean operations:** intersection, difference, union (2D and 3D)
- **Measurements:** area, volume, distance (2D and 3D)
- **Hulls:** convex hull (2D and 3D)
- **Triangulation:** tesselate, triangulate_2dz, constrained Delaunay triangulation
- **Transformations:** extrude, straight skeleton extrusion, translate/rotate/scale (v2.0+)
- **Analysis:** straight skeleton, medial axis, polygon partitioning, alpha shapes, optimal convex partition, visibility
- **Validation:** `is_valid` with detailed error reporting

**Known gaps** relative to the C++ API: direct CGAL kernel access, fine-grained algorithm parameter control, exact rational coordinate access (C API works with `double`), and iterator-based traversal of internal triangulation structures.

### Package structure

The package uses a **hybrid architecture** with platform-conditional dependencies ([SE-0273](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0273-swiftpm-conditional-target-dependencies.md)):

```
SwiftSFCGAL/
├── Package.swift                       # Hybrid: systemLibrary + binaryTarget
├── Sources/
│   ├── CSFCGAL_System/                 # systemLibrary target (macOS/Linux/Windows)
│   │   ├── module.modulemap
│   │   └── sfcgal_shim.h              # Umbrella header (#include <SFCGAL/capi/sfcgal_c.h>)
│   ├── CSFCGAL_Shim/                   # Cross-platform C shim layer
│   │   ├── include/
│   │   │   └── sfcgal_swift_shim.h    # Public header + SWIFTSFCGAL_REQUIRED_VERSION
│   │   ├── sfcgal_swift_shim.c        # Empty .c so SPM recognizes the target
│   │   └── version_check.cc           # Compile-time static_assert on SFCGAL version
│   └── SwiftSFCGAL/
│       └── SwiftSFCGAL.swift           # Public Swift API
├── Tests/
│   └── SwiftSFCGALTests/
│       └── SwiftSFCGALTests.swift
├── scripts/
│   └── create-xcframeworks.sh          # Builds iOS XCFrameworks from source
└── .github/workflows/
    ├── ci.yml                          # CI: macOS, iOS Simulator, Linux, Windows
    └── build-xcframeworks.yml          # Builds + publishes XCFramework releases
```

On **macOS, Linux, and Windows**, the package links against a locally installed SFCGAL via `pkg-config` (or, on Windows, via `LIB`/`INCLUDE` env vars). The `CSFCGAL_System` target contains only a module map and umbrella header:

```modulemap
module CSFCGAL_System [system] {
    header "sfcgal_shim.h"
    link "SFCGAL"
    export *
}
```

On **iOS** (and tvOS, watchOS, visionOS), there is no system library ecosystem. The package uses prebuilt XCFrameworks downloaded from GitHub releases by SPM. These contain static libraries for SFCGAL, GMP, and MPFR cross-compiled for ARM64.

### Platform-specific notes

| Platform | pkg-config | How paths are resolved |
|----------|------------|----------------------|
| macOS (Homebrew) | `sfcgal.pc` installed by `brew install sfcgal` | Automatic via SPM's built-in pkg-config parser |
| Ubuntu / Debian | `sfcgal.pc` generated by `cmake --install` | Automatic via SPM, with `PKG_CONFIG_PATH` pointing to the install prefix |
| Windows | SFCGAL's `.pc` file has an empty `prefix=` that SPM cannot parse | Bypassed entirely; paths set through `LIB`/`INCLUDE` env vars and `-Xcc -I` flags |
| iOS / tvOS / watchOS / visionOS | N/A | XCFrameworks are self-contained; no system paths needed |

## Dependency chain

SFCGAL sits atop a deep dependency stack:

```
SwiftSFCGAL (this package)
  └── SFCGAL  (C++ library, LGPL-2.0+)
        ├── CGAL    (C++ headers-only since v5.0, GPL-3+ for many packages)
        │     ├── Boost   (C++ headers-only for CGAL, BSL-1.0)
        │     ├── GMP     (C library, LGPL-2.0+)
        │     └── MPFR    (C library, LGPL-3.0+)
        └── Boost   (C++ headers, BSL-1.0)
```

### Cross-compilation notes

- **GMP** is the trickiest dependency for iOS. Its hand-tuned assembly code produces `"unknown AArch64 fixup kind!"` errors when targeting `arm64-apple-iphoneos`. The solution is `./configure --disable-assembly`, which forces generic C fallback code. This incurs a 2-5x slowdown for pure arbitrary-precision arithmetic, but the practical impact on SFCGAL operations is modest because CGAL uses interval filtering (exact arithmetic only triggers on degenerate cases).
- **MPFR** is pure C and cross-compiles cleanly once GMP is built — just pass `--with-gmp=<path>`.
- **CGAL** is header-only since v5.0 — no compilation needed, just include the headers.
- **Boost** only needs headers for CGAL (no compiled Boost libraries required).
- **SFCGAL** uses CMake. Cross-compile with `-DCMAKE_SYSTEM_NAME=iOS` or the `leetal/ios-cmake` toolchain.
- **Alternative:** CGAL 6.x supports `Boost.Multiprecision` as a backend (`-DCGAL_CMAKE_EXACT_NT_BACKEND=BOOST_BACKEND`), which would eliminate GMP/MPFR entirely at the cost of slower exact arithmetic. Whether SFCGAL supports this backend is unverified.

## Licensing

This package is licensed under **GPL-3.0-or-later**, matching the license of the CGAL packages that SFCGAL depends on.

### Dependency licenses

- **SFCGAL** — LGPL-2.0+ (compatible with GPL-3)
- **CGAL** — dual-licensed: some packages LGPL, many GPL-3+ (Nef polyhedra, Boolean operations, convex hulls, straight skeletons, Minkowski sums, polygon mesh processing). Since SFCGAL links GPL-3+ packages, the combined binary is GPL-3+.
- **GMP** — LGPL-2.0+ (compatible with GPL-3)
- **MPFR** — LGPL-3.0+ (compatible with GPL-3)
- **Boost** — BSL-1.0 (permissive, compatible with everything)

All dependencies are GPL-3 compatible. Licensing SwiftSFCGAL under GPL-3+ is fully compliant with the entire dependency chain.

### Note for app developers: Apple App Store distribution

The GPL-3 and Apple's App Store Terms of Service are widely considered to be in conflict. The FSF's position is that the App Store's Usage Rules impose restrictions on redistribution that the GPL prohibits. Apple has historically removed GPL-licensed apps (GNU Go, VLC) from the App Store when copyright holders raised objections.

This **does not affect the SwiftSFCGAL package itself** — it only matters for apps that link SwiftSFCGAL and are distributed through the App Store. If you are building such an app, your options include:

1. **Distribute outside the App Store** under GPL-3 terms — TestFlight, ad-hoc, enterprise provisioning, AltStore, or EU sideloading under the DMA all work without conflict.
2. **Purchase a commercial CGAL license** from [GeometryFactory](https://www.geometryfactory.com/) — this eliminates all GPL obligations on the CGAL portions, allowing you to choose a different license for your app.
3. **Accept the legal ambiguity** — some GPL-licensed apps do exist on the App Store in practice. Enforcement requires a CGAL copyright holder to actively file a complaint. This is a risk, not a right.

GPLv3 Section 7 allows copyright holders to add "additional permissions" (such as an App Store exception) to their own code, but this only covers code you hold copyright to — it cannot override the GPL on CGAL's code.

## Prior art and references

- **[Azul](https://github.com/tudelft3d/azul)** — macOS-only 3D CityGML viewer from TU Delft. Uses Objective-C++ to bridge CGAL C++ to Swift UI. Ships prebuilt static `.a` files for GMP/MPFR. Key insight: uses hand-crafted Xcode project, not CMake-generated, for CGAL integration. macOS only — no iOS support.
- **[CGALKit](https://cocoapods.org/pods/CGALKit_Pods)** — v0.0.0 CocoaPod wrapping a tiny subset of CGAL (convex hull, volume only) using Swift 5.9+ C++ interop. Proves the concept but extremely limited.
- **[sfcgal-rs](https://github.com/mthh/sfcgal-sys)** — Rust FFI bindings for SFCGAL's C API using `bindgen`. Closest architectural analog to what we're building — wraps `sfcgal_c.h` via FFI with safe Rust types on top.
- **[PySFCGAL](https://gitlab.com/sfcgal/pysfcgal)** — Official Python bindings for SFCGAL's C API. Another reference for the C API wrapping pattern.
- **[GEOSwift/geos](https://github.com/GEOSwift/geos)** — SPM package that vendors all of libgeos C/C++ source. Reference for the vendored-source approach (though impractical for our dependency chain).
- **[boost-iosx](https://github.com/apotocki/boost-iosx)** — Builds Boost as XCFrameworks for all Apple platforms. Template for the cross-compilation pipeline.

## Swift wrapper design

The Swift layer wraps SFCGAL's opaque C pointers in classes with RAII semantics (`deinit` calls the C cleanup function). This guarantees automatic memory management with zero risk of leaks:

```swift
// Example usage
let polygon = try SFCGALGeometry(wkt: "POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))")
let triangulated = polygon.tesselate()
let area = polygon.area()
print("Area: \(area)")  // polygon and triangulated freed automatically when scope exits
```

A thin C shim layer sits between the raw SFCGAL C API and Swift to handle:
- **Error handling:** SFCGAL's default error handler calls `printf`/`abort()`. The shim installs a custom handler that captures errors into a thread-local buffer, which Swift retrieves and throws as proper Swift errors.
- **Batch operations:** For processing large geometry datasets (e.g., hundreds of CityGML building surfaces), batch shims minimize Swift-C boundary crossings by processing arrays of geometries in a single C call.

## CI

The project has automated CI on all supported platforms via GitHub Actions. See [`.github/workflows/ci.yml`](.github/workflows/ci.yml) for the full workflow. The setup instructions in this README are derived directly from the CI workflow and are verified on every push.

| Job | Runner | Swift setup |
|-----|--------|-------------|
| macOS | `macos-latest` | Xcode-bundled Swift |
| iOS Simulator | `macos-latest` | Xcode-bundled Swift + `xcodebuild` |
| Linux | `ubuntu-latest` | [swift-actions/setup-swift](https://github.com/swift-actions/setup-swift) |
| Windows | `windows-latest` | [compnerd/gha-setup-swift](https://github.com/compnerd/gha-setup-swift) |

## Status

This project is in early development. The architecture and build strategy are established; the Swift wrapper API and iOS cross-compilation pipeline are being implemented. See the Roadmap below for current progress.

## Roadmap

See [GitHub Issues](../../issues) for the full breakdown. The work is organized in phases, with blockers prioritized first:

1. **Phase 0 — Risk Mitigation:** GMP cross-compilation spike, Boost.Multiprecision feasibility
2. **Phase 1 — Build Infrastructure:** Cross-compile full dependency chain, XCFramework packaging, CI automation
3. **Phase 2 — SPM Package Structure:** Hybrid package layout, module maps, C shim layer
4. **Phase 3 — Swift Wrapper (Core Types):** Geometry types, collections, WKT/WKB I/O
5. **Phase 4 — Swift Wrapper (Operations):** Predicates, measurements, Boolean ops, triangulation, transformations, analysis
6. **Phase 5 — Quality & Distribution:** Testing, documentation, Linux CI

## License

This project is licensed under the [GNU General Public License v3.0 or later](https://www.gnu.org/licenses/gpl-3.0.html) — see the [LICENSE](LICENSE) file for details.

SFCGAL is LGPL-2.0+. CGAL packages used by SFCGAL are GPL-3+. GMP is LGPL-2.0+. MPFR is LGPL-3.0+. Boost is BSL-1.0. All are compatible with this package's GPL-3+ license.
