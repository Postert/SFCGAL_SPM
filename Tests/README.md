# SwiftSFCGAL Test Infrastructure

The Swift test suite uses shared WKT fixtures and setup helpers in
`Tests/SwiftSFCGALTests/GeometryFixtures.swift` and
`Tests/SwiftSFCGALTests/TestSupport.swift`.

## Shared Fixtures

Use `GeometryFixtures` for reusable WKT examples instead of duplicating common
test geometry strings. The fixture catalog covers:

- Simple 2D polygons: squares, triangles, rectangles, L-shapes
- Polygons with holes
- 3D polygons: flat surfaces, sloped surfaces, vertical walls, non-planar input
- Multi-geometries and geometry collections
- Degenerate or invalid inputs: empty polygons, bowties, collinear points
- CityGML-style building footprints, wall surfaces, and roof surfaces
- Solid and surface examples such as a unit cube, TIN, and polyhedral surface

Prefer `TestGeometry.fromWKT(_:)` when constructing fixtures in tests. It routes
all setup through `TestSupport.initializeSFCGALOnce()`.

## Local Test Commands

macOS with Homebrew SFCGAL:

```bash
brew install sfcgal
pkg-config --modversion sfcgal
swift test
```

Linux with SFCGAL installed to a custom prefix:

```bash
export SFCGAL_PREFIX=/usr/local/sfcgal
export PKG_CONFIG_PATH="${SFCGAL_PREFIX}/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="${SFCGAL_PREFIX}/lib:$LD_LIBRARY_PATH"
swift test
```

Windows with SFCGAL installed to `C:\sfcgal`:

```powershell
swift test -Xcc -IC:/sfcgal/include -Xlinker /LIBPATH:C:\sfcgal\lib
```

## Address Sanitizer

Run Address Sanitizer on macOS to catch memory ownership regressions around
SFCGAL handles and buffers:

```bash
swift test --sanitize=address
```

This is useful for detecting:

- Leaked `sfcgal_geometry_t` handles
- Double frees
- Use-after-free mistakes with borrowed child geometries
- Invalid memory access around buffers returned by SFCGAL

Sanitizer runs are slower than normal tests and may be more sensitive to local
toolchain/library setup.
