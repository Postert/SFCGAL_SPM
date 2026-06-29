import Testing
import Foundation
@testable import SwiftSFCGAL

// ══════════════════════════════════════════════════════════════════════════════
// Issue #16 — Analysis operations
//
// Coverage: every analysis function in SFCGAL 2.3.0's C API.
//
// Expected values are derived from first principles or geometric definitions:
//
//   • Convex hull of a convex polygon = the polygon itself (same area).
//   • Convex hull of MULTIPOINT cube corners covers volume of the cube.
//   • Medial axis of a long rectangle ≈ a horizontal line down the middle.
//   • Convex partition of any polygon = pieces summing to the original area.
//   • An L-shape requires ≥ 2 convex pieces (it is non-convex).
// ══════════════════════════════════════════════════════════════════════════════

// MARK: - Helpers

private func almostEqual(_ a: Double, _ b: Double, tol: Double = 1e-9) -> Bool {
    abs(a - b) <= tol
}

private func unitSquare2D() throws -> Geometry {
    try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
}

/// L-shaped polygon — total area = 4*4 − 2*2 = 12, non-convex.
private func lShape() throws -> Geometry {
    try Geometry.fromWKT("POLYGON((0 0,4 0,4 2,2 2,2 4,0 4,0 0))")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Convex hull (2D)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testConvexHullOfSquareIsSquare() throws {
    TestSupport.initializeSFCGALOnce()
    // A unit square is already convex — the hull has the same area.
    let square = try unitSquare2D()
    let hull   = try square.convexHull()
    #expect(almostEqual(try hull.area(), 1.0))
}

@Test func testConvexHullEnclosesNonConvexPolygon() throws {
    TestSupport.initializeSFCGALOnce()
    // L-shape vertices: (0,0),(4,0),(4,2),(2,2),(2,4),(0,4).
    // The convex hull excludes the concave corner (2,2) and connects
    // (4,2) directly to (2,4), giving the pentagon
    //   (0,0),(4,0),(4,2),(2,4),(0,4)
    // Shoelace area = |0+8+16+4+0| / 2 = 14.
    let l    = try lShape()
    let hull = try l.convexHull()
    #expect(almostEqual(try hull.area(), 14.0))
}

@Test func testConvexHullOfPointsIsPolygon() throws {
    TestSupport.initializeSFCGALOnce()
    // Convex hull of 4 corner points = unit square (area 1).
    let pts  = try Geometry.fromWKT("MULTIPOINT(0 0,1 0,1 1,0 1)")
    let hull = try pts.convexHull()
    #expect(almostEqual(try hull.area(), 1.0))
}

@Test func testConvexHullResultIsValid() throws {
    TestSupport.initializeSFCGALOnce()
    let l    = try lShape()
    let hull = try l.convexHull()
    #expect(hull.isValid)
}

@Test func testConvexHullResultIsOwned() throws {
    TestSupport.initializeSFCGALOnce()
    let result: Geometry
    do {
        let l = try lShape()
        result = try l.convexHull()
    }
    // Original freed — result must remain valid; pentagon area = 14 (see
    // testConvexHullEnclosesNonConvexPolygon for derivation).
    #expect(almostEqual(try result.area(), 14.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Convex hull (3D)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testConvexHull3DOfCubeCorners() throws {
    TestSupport.initializeSFCGALOnce()
    // 8 corner points of a unit cube → 3D convex hull is the cube.
    // Cube has 6 faces × area 1 = total 3D surface area = 6.
    let pts = try Geometry.fromWKT(
        "MULTIPOINT(0 0 0,1 0 0,1 1 0,0 1 0,0 0 1,1 0 1,1 1 1,0 1 1)"
    )
    let hull = try pts.convexHull3D()
    #expect(!hull.asWKT().isEmpty)
    #expect(almostEqual(try hull.area3D(), 6.0, tol: 1e-6))
}

@Test func testConvexHull3DResultIsOwned() throws {
    TestSupport.initializeSFCGALOnce()
    let result: Geometry
    do {
        let pts = try Geometry.fromWKT(
            "MULTIPOINT(0 0 0,1 0 0,1 1 0,0 1 0,0 0 1,1 0 1,1 1 1,0 1 1)"
        )
        result = try pts.convexHull3D()
    }
    #expect(!result.asWKT().isEmpty)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Approximate medial axis
// ══════════════════════════════════════════════════════════════════════════════

@Test func testMedialAxisOfRectangleHasPositiveLength() throws {
    TestSupport.initializeSFCGALOnce()
    // A long rectangle has a clear medial axis (centerline).  Its length must
    // be strictly positive — we don't pin a specific value because the exact
    // shape depends on SFCGAL's approximation algorithm.
    let rect    = try Geometry.fromWKT("POLYGON((0 0,10 0,10 1,0 1,0 0))")
    let medial  = try rect.approximateMedialAxis()
    #expect(!medial.asWKT().isEmpty)
    #expect(try medial.length() > 0.0)
}

@Test func testMedialAxisResultIsOwned() throws {
    TestSupport.initializeSFCGALOnce()
    let result: Geometry
    do {
        let rect = try Geometry.fromWKT("POLYGON((0 0,10 0,10 1,0 1,0 0))")
        result = try rect.approximateMedialAxis()
    }
    #expect(!result.asWKT().isEmpty)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Alpha shapes
//
// PLATFORM GATE: `sfcgal_geometry_alpha_shapes` and
// `sfcgal_geometry_optimal_alpha_shapes` are excluded from Windows MSVC builds
// of SFCGAL via `#if !_MSC_VER` in `sfcgal_c.h`.  The Swift wrappers and these
// tests are gated on `!os(Windows)` to mirror that.
// ══════════════════════════════════════════════════════════════════════════════

#if !os(Windows)
@Test func testAlphaShapesProducesNonEmpty() throws {
    TestSupport.initializeSFCGALOnce()
    // Square arrangement of 4 points + center (5 points total) — the alpha
    // shape with sufficiently large alpha should enclose them.
    let pts = try Geometry.fromWKT("MULTIPOINT(0 0,1 0,1 1,0 1,0.5 0.5)")
    let shape = try pts.alphaShapes(alpha: 100.0, allowHoles: false)
    #expect(!shape.asWKT().isEmpty)
}

@Test func testAlphaShapesLargeAlphaApproachesConvexHull() throws {
    TestSupport.initializeSFCGALOnce()
    // For 5 corner-and-centre points of a unit square, a large alpha should
    // give an alpha shape with the same area as the convex hull (1.0).
    let pts   = try Geometry.fromWKT("MULTIPOINT(0 0,1 0,1 1,0 1,0.5 0.5)")
    let shape = try pts.alphaShapes(alpha: 1000.0, allowHoles: false)
    #expect(almostEqual(try shape.area(), 1.0, tol: 1e-6))
}

@Test func testAlphaShapesAllowHolesParam() throws {
    TestSupport.initializeSFCGALOnce()
    // Both branches must be callable; we don't assert specific area since the
    // hole-permitting branch may or may not produce holes for this input.
    let pts   = try Geometry.fromWKT("MULTIPOINT(0 0,1 0,1 1,0 1,0.5 0.5)")
    let no    = try pts.alphaShapes(alpha: 100.0, allowHoles: false)
    let yes   = try pts.alphaShapes(alpha: 100.0, allowHoles: true)
    #expect(!no.asWKT().isEmpty)
    #expect(!yes.asWKT().isEmpty)
}

@Test func testOptimalAlphaShapesOneComponent() throws {
    TestSupport.initializeSFCGALOnce()
    let pts   = try Geometry.fromWKT("MULTIPOINT(0 0,1 0,1 1,0 1,0.5 0.5)")
    let shape = try pts.optimalAlphaShapes(allowHoles: false, components: 1)
    #expect(!shape.asWKT().isEmpty)
}
#endif  // !os(Windows)

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Alpha wrapping (3D)
//
// `alpha_wrapping_3d` (SFCGAL → CGAL `alpha_wrap_3`) wraps a 3D point set or
// mesh into a connected polyhedral surface.  Empirically this function shows
// non-deterministic behavior under parallel test execution and at borderline
// parameter values:
//
//   • The same input + parameters can succeed in one run and throw
//     "PolyhedralSurface is invalid : not connected" in another.
//   • Sparse inputs (e.g. 8 cube corners) are particularly unreliable.
//   • Aggressive `relativeOffset` always fragments small inputs.
//
// To get reliable AND fast tests we apply three rules:
//
//   1. The suite is `.serialized` — alpha_wrap_3 tests never run in parallel
//      with each other, eliminating racing on any shared CGAL/SFCGAL state.
//   2. Inputs are deliberately well-conditioned: a 200-point Fibonacci sphere
//      with `relativeAlpha: 4` (alpha = diag/4 ≈ 0.5 vs neighbor distance
//      ≈ 0.25 → ~100 % safety margin) — reliably connected across runs.
//   3. Validity checks use `numPatches` (O(1)) rather than `asWKT()` or
//      `area3D()`.  The wrap result holds CGAL exact rationals like
//      `614393340713411/576460752303423488`; serializing or area-summing
//      hundreds of these takes ~55 s on Windows debug builds even though
//      the wrap algorithm itself runs in milliseconds.
// ══════════════════════════════════════════════════════════════════════════════

@Suite("Alpha Wrapping 3D", .serialized)
struct AlphaWrapping3DTests {

    /// Generates a MULTIPOINT WKT sampling a unit sphere via the Fibonacci spiral.
    /// Uniform angular spacing — no pole clustering, no duplicate points.
    static func fibonacciSphereWKT(n: Int = 200) -> String {
        let phi = Double.pi * (3.0 - sqrt(5.0))   // golden angle
        var pts: [String] = []
        pts.reserveCapacity(n)
        for i in 0..<n {
            let y = 1.0 - (Double(i) / Double(n - 1)) * 2.0
            let r = sqrt(1.0 - y * y)
            let theta = phi * Double(i)
            let x = cos(theta) * r
            let z = sin(theta) * r
            pts.append(String(format: "%.6f %.6f %.6f", x, y, z))
        }
        return "MULTIPOINT(" + pts.joined(separator: ",") + ")"
    }

    @Test func producesConnectedSurface() throws {
        TestSupport.initializeSFCGALOnce()
        let cloud = try Geometry.fromWKT(Self.fibonacciSphereWKT())
        let wrap  = try cloud.alphaWrapping3D(relativeAlpha: 4, relativeOffset: 0)
        // Cheap proof of non-trivial output: PolyhedralSurface with ≥ 1 patch.
        // (asWKT()/area3D() are O(coords × exact-rational-decimal-conv) — too
        // slow on debug Windows builds for meshes this size.)
        guard let surf = wrap as? PolyhedralSurface else {
            Issue.record("Expected PolyhedralSurface, got \(type(of: wrap))")
            return
        }
        #expect(surf.numPatches > 0, "Wrap produced zero patches")
    }

    @Test func resultIsPolyhedralSurface() throws {
        TestSupport.initializeSFCGALOnce()
        // SFCGAL's algorithm::alphaWrapping3D returns
        // std::unique_ptr<PolyhedralSurface>; verify the Swift-side type matches.
        let cloud = try Geometry.fromWKT(Self.fibonacciSphereWKT())
        let wrap  = try cloud.alphaWrapping3D(relativeAlpha: 4, relativeOffset: 0)
        #expect(wrap is PolyhedralSurface)
    }

    @Test func resultIsOwned() throws {
        TestSupport.initializeSFCGALOnce()
        let result: Geometry
        do {
            let cloud = try Geometry.fromWKT(Self.fibonacciSphereWKT())
            result = try cloud.alphaWrapping3D(relativeAlpha: 4, relativeOffset: 0)
        }
        // Input freed — result must still be queryable.  Use `numPatches`
        // (O(1)) rather than asWKT/area3D for the same reason as above.
        guard let surf = result as? PolyhedralSurface else {
            Issue.record("Expected PolyhedralSurface, got \(type(of: result))")
            return
        }
        #expect(surf.numPatches > 0, "Wrap result lost patches after input freed")
    }

    @Test func aggressiveOffsetCanFragment() throws {
        TestSupport.initializeSFCGALOnce()
        // `relativeOffset` is a divisor of the bbox diagonal: huge values
        // shrink the offset to near-zero (600 → ~diag/600), fragmenting the
        // wrap output.  When that happens, `PolyhedralSurface(Mesh)` throws
        // "not connected" inside the C++ algorithm.
        //
        // We accept either outcome — this test locks in that the wrapper
        // correctly propagates the failure when CGAL fragments the output,
        // rather than silently masking it.
        let cube = try Geometry.fromWKT(
            "MULTIPOINT(0 0 0,1 0 0,1 1 0,0 1 0,0 0 1,1 0 1,1 1 1,0 1 1)"
        )
        do {
            let wrap = try cube.alphaWrapping3D(relativeAlpha: 20, relativeOffset: 600)
            #expect(wrap is PolyhedralSurface)
        } catch let SFCGALError.operationFailed(message) {
            #expect(message.contains("not connected") || message.contains("invalid"),
                    "Expected 'not connected' / 'invalid' for aggressive offset, got: \(message)")
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Polygon partitions
// ══════════════════════════════════════════════════════════════════════════════

@Test func testYMonotonePartitionPreservesArea() throws {
    TestSupport.initializeSFCGALOnce()
    // A partition of an L-shape must cover exactly the same total area (12).
    let l         = try lShape()
    let partition = try l.yMonotonePartition()
    #expect(!partition.asWKT().isEmpty)
    #expect(almostEqual(try partition.area(), 12.0, tol: 1e-6))
}

@Test func testApproximateConvexPartitionPreservesArea() throws {
    TestSupport.initializeSFCGALOnce()
    let l         = try lShape()
    let partition = try l.approximateConvexPartition()
    #expect(!partition.asWKT().isEmpty)
    #expect(almostEqual(try partition.area(), 12.0, tol: 1e-6))
}

@Test func testGreeneConvexPartitionPreservesArea() throws {
    TestSupport.initializeSFCGALOnce()
    let l         = try lShape()
    let partition = try l.greeneConvexPartition()
    #expect(!partition.asWKT().isEmpty)
    #expect(almostEqual(try partition.area(), 12.0, tol: 1e-6))
}

@Test func testOptimalConvexPartitionPreservesArea() throws {
    TestSupport.initializeSFCGALOnce()
    let l         = try lShape()
    let partition = try l.optimalConvexPartition()
    #expect(!partition.asWKT().isEmpty)
    #expect(almostEqual(try partition.area(), 12.0, tol: 1e-6))
}

@Test func testOptimalConvexPartitionLShapeProducesMultiplePieces() throws {
    TestSupport.initializeSFCGALOnce()
    // An L-shape is non-convex, so any convex partition must yield ≥ 2 pieces.
    let l         = try lShape()
    let partition = try l.optimalConvexPartition()
    if let col = partition as? GeometryCollection {
        #expect(col.numGeometries >= 2,
                "L-shape convex partition produced \(col.numGeometries) pieces, expected ≥ 2")
    } else {
        // If SFCGAL returned a single Polygon for an L-shape, that would be a bug.
        Issue.record("Expected GeometryCollection for non-convex partition, got \(type(of: partition))")
    }
}

@Test func testPartitionResultIsOwned() throws {
    TestSupport.initializeSFCGALOnce()
    let result: Geometry
    do {
        let l = try lShape()
        result = try l.optimalConvexPartition()
    }
    // Original freed — result must remain queryable
    #expect(almostEqual(try result.area(), 12.0, tol: 1e-6))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - validationDetail() — Issue #16's tuple-form sketch
// ══════════════════════════════════════════════════════════════════════════════

@Test func testValidationDetailValidGeometry() throws {
    TestSupport.initializeSFCGALOnce()
    let square = try unitSquare2D()
    let detail = square.validationDetail()
    #expect(detail.isValid)
    #expect(detail.reason == nil)
}

@Test func testValidationDetailInvalidGeometry() throws {
    TestSupport.initializeSFCGALOnce()
    // Self-intersecting bowtie polygon — should be invalid with a reason.
    let bowtie = try Geometry.fromWKT("POLYGON((0 0,1 1,1 0,0 1,0 0))")
    let detail = bowtie.validationDetail()
    #expect(!detail.isValid)
    #expect(detail.reason != nil)
    #expect(!(detail.reason ?? "").isEmpty)
}

@Test func testValidationDetailMatchesValidationResult() throws {
    TestSupport.initializeSFCGALOnce()
    // The tuple convenience must agree with the richer struct API.
    let square    = try unitSquare2D()
    let tuple     = square.validationDetail()
    let structRes = square.validationResult()
    #expect(tuple.isValid == structRes.isValid)
    #expect(tuple.reason == structRes.reason)
}
