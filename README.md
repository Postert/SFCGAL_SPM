# SwiftSFCGAL

A Swift Package wrapping the [SFCGAL](https://sfcgal.gitlab.io/SFCGAL/) computational geometry library for iOS, macOS, and Linux.

## Overview

SwiftSFCGAL provides idiomatic Swift access to SFCGAL's full suite of 2D and 3D computational geometry operations — triangulation, Boolean operations, measurements, straight skeletons, extrusions, and more. It is designed primarily for iOS (ARKit/RealityKit pipelines, CityGML rendering), with macOS and Linux as secondary targets.

SFCGAL is a C++ library built on top of [CGAL](https://www.cgal.org/) (the Computational Geometry Algorithms Library) that provides ISO 19107:2013 and OGC Simple Features Access 1.2 compliant geometry types and operations. It serves as the geometry backend for PostGIS's 3D spatial functions and is an [OSGeo project](https://www.osgeo.org/projects/sfcgal/).

## Supported platforms

| Platform | Toolchain | SFCGAL source |
|----------|-----------|---------------|
| macOS    | Xcode 16+ | System library via Homebrew |
| Linux (Ubuntu/Debian) | [Swift.org toolchain](https://www.swift.org/install/linux/) | System library via apt |
| iOS / visionOS | Xcode 16+ | Bundled XCFramework |

## Usage

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/SwiftSFCGAL.git", from: "0.1.0")
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

## Architecture

### Why a C API bridge (not Swift–C++ interop)

SFCGAL depends on CGAL, which is one of the most template-heavy C++ libraries in existence. Swift's C++ interoperability (introduced in Swift 5.9) **cannot import uninstantiated C++ templates** — it only supports explicitly pre-instantiated specializations exposed via `typedef` or `using`. CGAL's architecture is built entirely on template metaprogramming: geometric kernels parameterized on number types, traits classes, template template parameters, and deep Boost dependency chains. Additional unsupported features critical to CGAL include rvalue references, C++ exceptions, variadic templates, and `std::function`.

Attempting to pre-instantiate all needed CGAL types is impractical given the sheer volume and interdependency of CGAL's template graph. **Direct Swift–C++ interop with CGAL is a dead end.**

Instead, this package bridges through **SFCGAL's existing C API** (`sfcgal_c.h`), which uses the opaque pointer pattern — all geometry types are represented as `typedef void sfcgal_geometry_t*` with create/access/delete functions. This C API covers roughly 70–80% of SFCGAL's full functionality and is the same API used by PostGIS, PySFCGAL (Python), and sfcgal-rs (Rust).

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

The package uses a **hybrid architecture** with platform-conditional dependencies (SE-0273):

```
SwiftSFCGAL/
├── Package.swift                    # Hybrid: systemLibrary (macOS/Linux) + binaryTarget (iOS)
├── Sources/
│   ├── CSFCGAL_System/              # systemLibrary target (macOS/Linux)
│   │   ├── module.modulemap
│   │   └── sfcgal_shim.h            # Umbrella header
│   ├── CSFCGAL_Shim/                # Custom C shims (error handling, batch ops)
│   │   ├── include/
│   │   │   └── sfcgal_swift_shim.h
│   │   └── sfcgal_swift_shim.c
│   └── SwiftSFCGAL/                 # Idiomatic Swift wrapper layer
│       ├── Geometry.swift            # Base geometry class (RAII via deinit)
│       ├── Point.swift
│       ├── Polygon.swift
│       ├── Operations.swift          # Spatial operations
│       ├── IO.swift                  # WKT/WKB I/O
│       └── ...
├── SFCGAL.xcframework/              # Prebuilt static libraries for iOS
├── GMP.xcframework/
├── MPFR.xcframework/
└── Tests/
    └── SwiftSFCGALTests/
```

On **macOS and Linux**, the package links against system-installed SFCGAL via `pkg-config` (e.g., `brew install sfcgal` on macOS, `apt install libsfcgal-dev` on Linux). The `CSFCGAL_System` target contains only a module map and umbrella header — no source code. These tell the Swift compiler how to import the system-installed C API:

`Sources/CSFCGAL_System/module.modulemap`:
```modulemap
module CSFCGAL_System [system] {
    umbrella header "sfcgal_shim.h"
    link "SFCGAL"
    export *
}
```

`Sources/CSFCGAL_System/sfcgal_shim.h`:
```c
#include <SFCGAL/capi/sfcgal_c.h>
```

When SFCGAL is installed on the system, it provides a `sfcgal.pc` file (a [pkg-config](https://www.freedesktop.org/wiki/Software/pkg-config/) descriptor). SPM reads this file to automatically resolve the correct `-I` (header) and `-L`/`-l` (linker) flags. No manual path configuration is needed — the system package manager handles the entire dependency tree, and `pkg-config` tells SPM where everything lives.

| Platform | pkg-config availability |
|----------|------------------------|
| macOS (Homebrew) | `sfcgal.pc` installed automatically by `brew install sfcgal` |
| Ubuntu / Debian | `sfcgal.pc` installed by `apt install libsfcgal-dev` |

On **iOS** (and visionOS, tvOS, watchOS), there is no system library ecosystem. iOS apps must bundle all non-Apple code inside the `.app` directory. The package therefore includes prebuilt static libraries packaged as XCFrameworks. These are compiled from the same SFCGAL source code but cross-compiled for the iOS ARM64 architecture and platform.

### Why XCFrameworks are required for iOS

SPM's `.systemLibrary` with `pkgConfig` is fundamentally host-platform-only. At package resolution time, SPM's built-in pkg-config parser searches the *build machine's* filesystem for `.pc` files and extracts compiler/linker flags. These flags point to macOS-architecture binaries (e.g., `/opt/homebrew/lib/libSFCGAL.dylib`). When Xcode cross-compiles for `arm64-apple-iphoneos`, the linker rejects these macOS binaries because the `LC_BUILD_VERSION` load command encodes the platform — the linker produces: `ld: building for iOS, but linking in object file built for macOS`.

There is no mechanism in SPM to make `systemLibrary` find iOS-compatible libraries. iOS has no user-installable library ecosystem, no `/usr/lib` for third-party code, and the kernel enforces code-signing at page-fault time (`CS_KILL` flag). All non-Apple code must be embedded in the `.app` bundle.

Vendoring the full source tree (GMP + MPFR + Boost + CGAL + SFCGAL) into SPM is impractical because GMP requires a `./configure` step that generates platform-specific headers, Boost alone is 20,000+ header files, and clean builds would take many minutes.

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

- **GMP** is the trickiest dependency for iOS. Its hand-tuned assembly code produces `"unknown AArch64 fixup kind!"` errors when targeting `arm64-apple-iphoneos`. The solution is `./configure --disable-assembly`, which forces generic C fallback code. This incurs a 2–5× slowdown for pure arbitrary-precision arithmetic, but the practical impact on SFCGAL operations is modest because CGAL uses interval filtering (exact arithmetic only triggers on degenerate cases).
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
- **Batch operations:** For processing large geometry datasets (e.g., hundreds of CityGML building surfaces), batch shims minimize Swift↔C boundary crossings by processing arrays of geometries in a single C call.

## Development setup

### macOS

```bash
brew install sfcgal
# Then open in Xcode or:
swift build
swift test
```

### Linux (Ubuntu/Debian)

```bash
sudo apt install libsfcgal-dev
swift build
swift test
```

### iOS

iOS builds require the prebuilt XCFrameworks to be present in the package root. See the [XCFramework build instructions](docs/xcframework-build.md) for details on cross-compiling the dependency chain.

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
