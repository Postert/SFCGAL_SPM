import Testing
import Foundation
@testable import SwiftSFCGAL

// ══════════════════════════════════════════════════════════════════════════════
// Issue #14 — Triangulation operations
//
// Geometry layout used throughout:
//
//   unitSquare2D  — POLYGON((0 0,1 0,1 1,0 1,0 0))
//                   4 unique vertices → 2 triangles → 18 floats
//
//   verticalWall  — POLYGON Z((0 0 0,1 0 0,1 0 3,0 0 3,0 0 0))
//                   Building facade (XZ plane, Y=0 constant)
//                   4 unique vertices → 2 triangles
//
//   zSquare       — POLYGON Z((0 0 0,1 0 0,1 1 10,0 1 10,0 0 0))
//                   Flat ring with mixed Z values
//                   4 unique vertices → 2 triangles
//                   Z values must appear as {0.0, 0.0, 10.0, 10.0, …}
//
//   nGon(52)      — regular 52-gon (approximates a circle)
//                   52 unique vertices → 50 triangles → 450 floats
// ══════════════════════════════════════════════════════════════════════════════

// MARK: - Helpers

private func almostEqual(_ a: Double, _ b: Double, tol: Double = 1e-9) -> Bool {
    abs(a - b) <= tol
}

private func almostEqualF(_ a: Float, _ b: Float, tol: Float = 1e-5) -> Bool {
    abs(a - b) <= tol
}

/// Counts triangles in a tesselation result regardless of result type.
private func triangleCount(_ geom: Geometry) -> Int {
    if let tin = geom as? TriangulatedSurface { return tin.numPatches }
    if let col = geom as? GeometryCollection  { return col.numGeometries }
    return 0
}

/// Generates the WKT for a regular N-gon centred at the origin with unit radius.
/// A closed ring has N+1 points (first == last).
/// A convex N-gon tessellates into N-2 triangles.
private func nGonWKT(_ n: Int, radius: Double = 1.0) -> String {
    var pts = (0..<n).map { i -> String in
        let angle = 2.0 * Double.pi * Double(i) / Double(n)
        return String(format: "%.10f %.10f", radius * cos(angle), radius * sin(angle))
    }
    pts.append(pts[0])  // close the ring
    return "POLYGON((\(pts.joined(separator: ","))))"
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - tesselate() — basic behaviour
// ══════════════════════════════════════════════════════════════════════════════

@Test func testTesselateReturnsValidGeometry() throws {
    initializeSFCGAL()
    let poly = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let result = try poly.tesselate()
    #expect(!result.asWKT().isEmpty)
    #expect(result.isValid)
}

@Test func testTesselateSquareGivesTwoTriangles() throws {
    initializeSFCGAL()
    // A square has 4 unique vertices → N-2 = 2 triangles
    let poly = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let result = try poly.tesselate()
    #expect(triangleCount(result) == 2)
}

@Test func testTesselateResultIsTriangulatedSurface() throws {
    initializeSFCGAL()
    // Polygon tesselation normally returns a TriangulatedSurface
    let poly = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let result = try poly.tesselate()
    #expect(result is TriangulatedSurface)
}

@Test func testTesselateResultIsOwned() throws {
    initializeSFCGAL()
    // Result must remain valid after the input is deallocated
    let result: Geometry
    do {
        let poly = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
        result = try poly.tesselate()
    }
    // poly is freed here — result must still be usable
    #expect(triangleCount(result) == 2)
}

@Test func testTesselatePolygonWithHole() throws {
    initializeSFCGAL()
    // 4×4 square with a 2×2 hole — more triangles than a plain square
    let poly = try Geometry.fromWKT(
        "POLYGON((0 0,4 0,4 4,0 4,0 0),(1 1,1 3,3 3,3 1,1 1))"
    )
    let result = try poly.tesselate()
    // A square with a hole produces more than 2 triangles
    #expect(triangleCount(result) > 2)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - tesselate() — vertical surface (the hard CityGML case)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testTesselateVerticalWallSucceeds() throws {
    initializeSFCGAL()
    // Building facade: lies in the XZ plane (Y = 0 for all vertices).
    // 2D triangulators project to XY and produce zero-area triangles here.
    // SFCGAL operates in 3D and handles this correctly.
    let wall = try Geometry.fromWKT(
        "POLYGON Z ((0 0 0,1 0 0,1 0 3,0 0 3,0 0 0))"
    )
    let result = try wall.tesselate()
    #expect(triangleCount(result) == 2)
}

@Test func testTesselateVerticalWallVerticesAreFinite() throws {
    initializeSFCGAL()
    let wall = try Geometry.fromWKT(
        "POLYGON Z ((0 0 0,1 0 0,1 0 3,0 0 3,0 0 0))"
    )
    let vertices = try wall.triangleVertices()
    // Every coordinate must be a finite, non-NaN float
    for v in vertices {
        #expect(v.isFinite)
    }
}

@Test func testTesselateVerticalWallYIsConstant() throws {
    initializeSFCGAL()
    // All input vertices have Y = 0 → all output Y values must be 0
    let wall = try Geometry.fromWKT(
        "POLYGON Z ((0 0 0,1 0 0,1 0 3,0 0 3,0 0 0))"
    )
    let vertices = try wall.triangleVertices()
    // vertices layout: [x,y,z, x,y,z, ...]
    for i in stride(from: 1, to: vertices.count, by: 3) {
        #expect(almostEqualF(vertices[i], 0.0), "Y at index \(i) should be 0.0")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - tesselate() — large polygon (performance / correctness)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testTesselateLargePolygonTriangleCount() throws {
    initializeSFCGAL()
    // A convex N-gon with N unique vertices produces N-2 triangles.
    // 52-gon → 50 triangles
    let poly = try Geometry.fromWKT(nGonWKT(52))
    let result = try poly.tesselate()
    #expect(triangleCount(result) == 50)
}

@Test func testTesselateLargePolygonVertexCount() throws {
    initializeSFCGAL()
    // 50 triangles × 3 vertices × 3 floats = 450 floats
    let poly = try Geometry.fromWKT(nGonWKT(52))
    let vertices = try poly.triangleVertices()
    #expect(vertices.count == 450)
}

@Test func testTesselateLargePolygonAllFinite() throws {
    initializeSFCGAL()
    let poly = try Geometry.fromWKT(nGonWKT(52))
    let vertices = try poly.triangleVertices()
    for v in vertices {
        #expect(v.isFinite)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - triangleVertices() — known-correct values
// ══════════════════════════════════════════════════════════════════════════════

@Test func testTriangleVerticesCountSquare() throws {
    initializeSFCGAL()
    // Unit square: 2 triangles × 3 verts × 3 floats = 18
    let poly = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let vertices = try poly.triangleVertices()
    #expect(vertices.count == 18)
}

@Test func testTriangleVerticesAllFinite() throws {
    initializeSFCGAL()
    let poly = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let vertices = try poly.triangleVertices()
    for v in vertices {
        #expect(v.isFinite)
    }
}

@Test func testTriangleVerticesZeroZ_for2DPolygon() throws {
    initializeSFCGAL()
    // 2D polygon → Z channel must be 0.0 everywhere
    let poly = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let vertices = try poly.triangleVertices()
    // Z values are at indices 2, 5, 8, 11, 14, 17
    for i in stride(from: 2, to: vertices.count, by: 3) {
        #expect(almostEqualF(vertices[i], 0.0), "Z at index \(i) should be 0.0")
    }
}

@Test func testTriangleVerticesXYBoundsSquare() throws {
    initializeSFCGAL()
    // Unit square: all X in [0,1], all Y in [0,1]
    let poly = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let vertices = try poly.triangleVertices()
    for i in stride(from: 0, to: vertices.count, by: 3) {
        let x = vertices[i], y = vertices[i + 1]
        #expect(x >= -1e-5 && x <= 1 + 1e-5, "X \(x) out of [0,1]")
        #expect(y >= -1e-5 && y <= 1 + 1e-5, "Y \(y) out of [0,1]")
    }
}

@Test func testTriangleVerticesZPreservedFor3DPolygon() throws {
    initializeSFCGAL()
    // Square with Z=0 on bottom, Z=10 on top.
    // All output Z values must be either 0.0 or 10.0 (no interpolation).
    let poly = try Geometry.fromWKT(
        "POLYGON Z ((0 0 0,1 0 0,1 1 10,0 1 10,0 0 0))"
    )
    let vertices = try poly.triangleVertices()
    let allowedZ: Set<Float> = [0.0, 10.0]
    for i in stride(from: 2, to: vertices.count, by: 3) {
        let z = vertices[i]
        let isAllowed = allowedZ.contains(where: { almostEqualF(z, $0) })
        #expect(isAllowed, "Z value \(z) not in {0.0, 10.0}")
    }
}

@Test func testTriangleVerticesCountMatchesTriangleCount() throws {
    initializeSFCGAL()
    // Float count must always equal numTriangles × 9
    let poly = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let result = try poly.tesselate()
    let vertices = try poly.triangleVertices()
    #expect(vertices.count == triangleCount(result) * 9)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - triangulate2DZ()
// ══════════════════════════════════════════════════════════════════════════════

@Test func testTriangulate2DZReturnsValidGeometry() throws {
    initializeSFCGAL()
    let poly = try Geometry.fromWKT(
        "POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))"
    )
    let result = try poly.triangulate2DZ()
    #expect(!result.asWKT().isEmpty)
    #expect(result.isValid)
}

@Test func testTriangulate2DZSquareGivesTwoTriangles() throws {
    initializeSFCGAL()
    let poly = try Geometry.fromWKT(
        "POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))"
    )
    let result = try poly.triangulate2DZ()
    #expect(triangleCount(result) == 2)
}

@Test func testTriangulate2DZPreservesZValues() throws {
    initializeSFCGAL()
    // Three vertices with distinct Z values (5, 10, 15).
    // The single output triangle must carry those exact Z values.
    let poly = try Geometry.fromWKT(
        "POLYGON Z ((0 0 5,1 0 10,0.5 1 15,0 0 5))"
    )
    let result = try poly.triangulate2DZ()
    guard let tin = result as? TriangulatedSurface else {
        Issue.record("Expected TriangulatedSurface from triangulate2DZ")
        return
    }
    #expect(tin.numPatches == 1)
    let tri = tin.patchAt(0)
    let zValues = Set((0..<3).map { Float(tri.vertex($0).z) })
    let allowedZ: Set<Float> = [5.0, 10.0, 15.0]
    for z in zValues {
        let isAllowed = allowedZ.contains(where: { almostEqualF(z, $0) })
        #expect(isAllowed, "Unexpected Z value \(z)")
    }
}

@Test func testTriangulate2DZResultIsOwned() throws {
    initializeSFCGAL()
    let result: Geometry
    do {
        let poly = try Geometry.fromWKT(
            "POLYGON Z ((0 0 0,1 0 0,1 1 5,0 1 5,0 0 0))"
        )
        result = try poly.triangulate2DZ()
    }
    // Input freed — result must still be valid
    #expect(triangleCount(result) == 2)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Consistency checks
// ══════════════════════════════════════════════════════════════════════════════

@Test func testTesselateAndTriangleVerticesAreConsistent() throws {
    initializeSFCGAL()
    // triangleVertices() internally calls tesselate(); their triangle counts
    // must agree.
    let poly = try Geometry.fromWKT(nGonWKT(20))
    let tin  = try poly.tesselate()
    let verts = try poly.triangleVertices()
    #expect(verts.count == triangleCount(tin) * 9)
}

@Test func testTriangleVerticesFromTINMatchDirectIteration() throws {
    initializeSFCGAL()
    // Build expected vertices by manually iterating the TIN, then compare
    // with the output of triangleVertices() to confirm internal consistency.
    let poly = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let tin  = try poly.tesselate()
    guard let tinSurface = tin as? TriangulatedSurface else {
        Issue.record("Expected TriangulatedSurface")
        return
    }
    var expected: [Float] = []
    for i in 0..<tinSurface.numPatches {
        let tri = tinSurface.patchAt(i)
        for j in 0..<3 {
            let pt = tri.vertex(j)
            expected.append(Float(pt.x))
            expected.append(Float(pt.y))
            expected.append(pt.is3D ? Float(pt.z) : 0.0)
        }
    }
    let actual = try poly.triangleVertices()
    #expect(actual.count == expected.count)
    for (a, e) in zip(actual, expected) {
        #expect(almostEqualF(a, e))
    }
}
