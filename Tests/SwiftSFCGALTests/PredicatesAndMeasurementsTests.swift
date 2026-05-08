import Testing
import Foundation
@testable import SwiftSFCGAL

// ══════════════════════════════════════════════════════════════════════════════
// Issue #12 — Spatial predicates and measurements
//
// All expected values are derived from first principles so failures clearly
// indicate a real implementation problem, not a rounding choice.
// ══════════════════════════════════════════════════════════════════════════════

// MARK: - Helpers

/// Floating-point comparison with absolute tolerance.
private func almostEqual(_ a: Double, _ b: Double, tolerance: Double = 1e-10) -> Bool {
    abs(a - b) <= tolerance
}

// Reusable well-known geometries
private func unitSquare() throws -> Geometry {
    try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
}

private func shiftedSquare() throws -> Geometry {
    // Unit square offset by (2,0) — does NOT touch the unit square
    try Geometry.fromWKT("POLYGON((2 0,3 0,3 1,2 1,2 0))")
}

private func overlappingSquare() throws -> Geometry {
    // Overlaps the unit square in the strip x∈[0.5,1.5]
    try Geometry.fromWKT("POLYGON((0.5 0,1.5 0,1.5 1,0.5 1,0.5 0))")
}

private func innerSquare() throws -> Geometry {
    // Completely inside the unit square
    try Geometry.fromWKT("POLYGON((0.25 0.25,0.75 0.25,0.75 0.75,0.25 0.75,0.25 0.25))")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - intersects (2D)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testIntersectsTrueForOverlappingPolygons() throws {
    TestSupport.initializeSFCGALOnce()
    let a = try unitSquare()
    let b = try overlappingSquare()
    #expect(try a.intersects(b))
}

@Test func testIntersectsFalseForSeparatePolygons() throws {
    TestSupport.initializeSFCGALOnce()
    let a = try unitSquare()
    let b = try shiftedSquare()   // gap of 1 unit between them
    #expect(try !a.intersects(b))
}

@Test func testIntersectsTrueForSharedBoundaryPoint() throws {
    TestSupport.initializeSFCGALOnce()
    // Two squares that touch at exactly one point: (1,1)
    let a = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let b = try Geometry.fromWKT("POLYGON((1 1,2 1,2 2,1 2,1 1))")
    #expect(try a.intersects(b))
}

@Test func testIntersectsSymmetry() throws {
    TestSupport.initializeSFCGALOnce()
    let a = try unitSquare()
    let b = try overlappingSquare()
    #expect(try a.intersects(b) == b.intersects(a))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - intersects3D
// ══════════════════════════════════════════════════════════════════════════════

@Test func testIntersects3DOverlappingInAllDimensions() throws {
    TestSupport.initializeSFCGALOnce()
    // Unit-cube solid: a point strictly inside it must intersect3D.
    // Uses the same WKT format proven by testVolumeUnitCube / testSolidFromWKT.
    let wkt = """
    SOLID Z (
      (
        ((0 0 0,0 1 0,1 1 0,1 0 0,0 0 0)),
        ((0 0 1,1 0 1,1 1 1,0 1 1,0 0 1)),
        ((0 0 0,1 0 0,1 0 1,0 0 1,0 0 0)),
        ((1 0 0,1 1 0,1 1 1,1 0 1,1 0 0)),
        ((0 1 0,0 1 1,1 1 1,1 1 0,0 1 0)),
        ((0 0 0,0 0 1,0 1 1,0 1 0,0 0 0))
      )
    )
    """
    let solid = try Geometry.fromWKT(wkt)
    let inside = try Point(x: 0.5, y: 0.5, z: 0.5)
    let outside = try Point(x: 2.0, y: 2.0, z: 2.0)
    #expect(try solid.intersects3D(inside))
    #expect(try !solid.intersects3D(outside))
}

@Test func testIntersects3DFalseWhenOnlySeparatedInZ() throws {
    TestSupport.initializeSFCGALOnce()
    // Two unit squares in the same XY region but at different Z levels
    let low  = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    let high = try Geometry.fromWKT("POLYGON Z ((0 0 5,1 0 5,1 1 5,0 1 5,0 0 5))")
    // 3D: different Z → do NOT intersect
    #expect(try !low.intersects3D(high))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - covers (2D)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testCoversTrueForContainedPolygon() throws {
    TestSupport.initializeSFCGALOnce()
    let outer = try unitSquare()
    let inner = try innerSquare()
    #expect(try outer.covers(inner))
}

@Test func testCoversFalseForOverlappingPolygon() throws {
    TestSupport.initializeSFCGALOnce()
    let a = try unitSquare()
    let b = try overlappingSquare()   // extends beyond a on the right
    #expect(try !a.covers(b))
}

@Test func testCoversReflexive() throws {
    TestSupport.initializeSFCGALOnce()
    // Every geometry covers itself
    let a = try unitSquare()
    #expect(try a.covers(a))
}

@Test func testCoversTrueForBoundaryPoint() throws {
    TestSupport.initializeSFCGALOnce()
    // covers() includes boundary (unlike strict contains)
    let square = try unitSquare()
    let corner = try Point(x: 1.0, y: 1.0)   // exactly on the ring
    #expect(try square.covers(corner))
}

@Test func testCoversFalseWhenSeparated() throws {
    TestSupport.initializeSFCGALOnce()
    let a = try unitSquare()
    let b = try shiftedSquare()
    #expect(try !a.covers(b))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - covers3D
// ══════════════════════════════════════════════════════════════════════════════

@Test func testCovers3DPointOnSurface() throws {
    TestSupport.initializeSFCGALOnce()
    // A flat unit square at z=0 — a point exactly on it must be covered in 3D.
    let surface   = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    let onSurface = try Point(x: 0.5, y: 0.5, z: 0.0)
    #expect(try surface.covers3D(onSurface))
}

@Test func testCovers3DPointAboveSurfaceIsNotCovered() throws {
    TestSupport.initializeSFCGALOnce()
    // Same surface — a point lifted to z=1 must NOT be covered in 3D.
    let surface = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    let above   = try Point(x: 0.5, y: 0.5, z: 1.0)
    #expect(try !surface.covers3D(above))
}

@Test func testCovers3DReflexive() throws {
    TestSupport.initializeSFCGALOnce()
    // Every geometry covers itself in 3D.
    let surface = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    #expect(try surface.covers3D(surface))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - isPlanar
// ══════════════════════════════════════════════════════════════════════════════

@Test func testIsPlanarTrueFor2DPolygon() throws {
    TestSupport.initializeSFCGALOnce()
    // All 2D geometries are trivially planar
    let p = try unitSquare()
    #expect(try p.isPlanar())
}

@Test func testIsPlanarTrueForFlatPolygonInZ() throws {
    TestSupport.initializeSFCGALOnce()
    // 3D polygon lying exactly on z = 0
    let p = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    #expect(try p.isPlanar())
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - orientation
// ══════════════════════════════════════════════════════════════════════════════

@Test func testOrientationCCWForStandardPolygon() throws {
    TestSupport.initializeSFCGALOnce()
    // Standard OGC exterior ring: counter-clockwise
    let p = try unitSquare()
    let o = try p.orientation()
    #expect(o == .counterClockwise)
}

@Test func testOrientationCWForReversedRing() throws {
    TestSupport.initializeSFCGALOnce()
    // Reversed winding: clockwise
    let p = try Geometry.fromWKT("POLYGON((0 0,0 1,1 1,1 0,0 0))")
    let o = try p.orientation()
    #expect(o == .clockwise)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - area (2D)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testAreaUnitSquare() throws {
    TestSupport.initializeSFCGALOnce()
    // Unit square has area exactly 1.0
    let a = try unitSquare().area()
    #expect(almostEqual(a, 1.0))
}

@Test func testArea4x3Rectangle() throws {
    TestSupport.initializeSFCGALOnce()
    // 4 × 3 rectangle → area = 12
    let r = try Geometry.fromWKT("POLYGON((0 0,4 0,4 3,0 3,0 0))")
    #expect(almostEqual(try r.area(), 12.0))
}

@Test func testAreaWithHole() throws {
    TestSupport.initializeSFCGALOnce()
    // 4×4 square (area 16) minus a 2×2 hole (area 4) → net area 12.
    // OGC rule: exterior ring CCW, interior ring (hole) CW.
    // Hole ring reversed to CW: (1 1,1 3,3 3,3 1,1 1)
    let p = try Geometry.fromWKT(
        "POLYGON((0 0,4 0,4 4,0 4,0 0),(1 1,1 3,3 3,3 1,1 1))"
    )
    #expect(almostEqual(try p.area(), 12.0))
}

@Test func testAreaPointIsZero() throws {
    TestSupport.initializeSFCGALOnce()
    let pt = try Point(x: 1.0, y: 2.0)
    #expect(almostEqual(try pt.area(), 0.0))
}

@Test func testAreaLineStringIsZero() throws {
    TestSupport.initializeSFCGALOnce()
    let ls = try Geometry.fromWKT("LINESTRING(0 0,1 0,1 1)")
    #expect(almostEqual(try ls.area(), 0.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - area3D
// ══════════════════════════════════════════════════════════════════════════════

@Test func testArea3DFlatPolygonMatchesArea2D() throws {
    TestSupport.initializeSFCGALOnce()
    // Flat 3D polygon on z=0 — 3D area equals 2D area
    let p = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    #expect(almostEqual(try p.area3D(), 1.0))
}

@Test func testArea3DRightTriangle() throws {
    TestSupport.initializeSFCGALOnce()
    // Right triangle with legs 3 and 4 → area = 0.5 × 3 × 4 = 6
    let t = try Geometry.fromWKT("POLYGON Z ((0 0 0,3 0 0,0 4 0,0 0 0))")
    #expect(almostEqual(try t.area3D(), 6.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - volume
// ══════════════════════════════════════════════════════════════════════════════

@Test func testVolumeUnitCube() throws {
    TestSupport.initializeSFCGALOnce()
    let wkt = """
    SOLID Z (
      (
        ((0 0 0,0 1 0,1 1 0,1 0 0,0 0 0)),
        ((0 0 1,1 0 1,1 1 1,0 1 1,0 0 1)),
        ((0 0 0,1 0 0,1 0 1,0 0 1,0 0 0)),
        ((1 0 0,1 1 0,1 1 1,1 0 1,1 0 0)),
        ((0 1 0,0 1 1,1 1 1,1 1 0,0 1 0)),
        ((0 0 0,0 0 1,0 1 1,0 1 0,0 0 0))
      )
    )
    """
    let solid = try Geometry.fromWKT(wkt)
    #expect(almostEqual(try solid.volume(), 1.0))
}

@Test func testVolumePolygonIsZero() throws {
    TestSupport.initializeSFCGALOnce()
    // Non-solid geometry — volume is 0
    let p = try unitSquare()
    #expect(almostEqual(try p.volume(), 0.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - length (2D)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testLength345Triangle() throws {
    TestSupport.initializeSFCGALOnce()
    // The segment from (0,0) to (3,4) has length 5 (3-4-5 right triangle)
    let ls = try Geometry.fromWKT("LINESTRING(0 0,3 4)")
    #expect(almostEqual(try ls.length(), 5.0))
}

@Test func testLengthUnitSegment() throws {
    TestSupport.initializeSFCGALOnce()
    let ls = try Geometry.fromWKT("LINESTRING(0 0,1 0)")
    #expect(almostEqual(try ls.length(), 1.0))
}

@Test func testLengthMultiSegment() throws {
    TestSupport.initializeSFCGALOnce()
    // Three unit segments: total length 3
    let ls = try Geometry.fromWKT("LINESTRING(0 0,1 0,2 0,3 0)")
    #expect(almostEqual(try ls.length(), 3.0))
}

@Test func testLengthPolygonIsZero() throws {
    TestSupport.initializeSFCGALOnce()
    #expect(almostEqual(try unitSquare().length(), 0.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - length3D
// ══════════════════════════════════════════════════════════════════════════════

@Test func testLength3DDiagonal() throws {
    TestSupport.initializeSFCGALOnce()
    // (0,0,0) → (1,1,1): 3D length = √3 ≈ 1.7320508...
    let ls = try Geometry.fromWKT("LINESTRING Z (0 0 0,1 1 1)")
    let expected = 3.0.squareRoot()
    #expect(almostEqual(try ls.length3D(), expected))
}

@Test func testLength3DFlatSegmentMatchesLength2D() throws {
    TestSupport.initializeSFCGALOnce()
    // Flat segment on z=0: 3D length == 2D length
    let ls = try Geometry.fromWKT("LINESTRING Z (0 0 0,3 4 0)")
    #expect(almostEqual(try ls.length3D(), 5.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - distance (2D)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testDistanceZeroForIntersectingGeometries() throws {
    TestSupport.initializeSFCGALOnce()
    let a = try unitSquare()
    let b = try overlappingSquare()
    #expect(almostEqual(try a.distance(to: b), 0.0))
}

@Test func testDistanceSeparatedPolygons() throws {
    TestSupport.initializeSFCGALOnce()
    // Unit square [0,1]×[0,1] and square [2,3]×[0,1]: gap of 1 unit
    let a = try unitSquare()
    let b = try shiftedSquare()
    #expect(almostEqual(try a.distance(to: b), 1.0))
}

@Test func testDistanceBetweenTwoPoints() throws {
    TestSupport.initializeSFCGALOnce()
    // (0,0) to (3,4): distance = 5 (3-4-5)
    let p1 = try Point(x: 0.0, y: 0.0)
    let p2 = try Point(x: 3.0, y: 4.0)
    #expect(almostEqual(try p1.distance(to: p2), 5.0))
}

@Test func testDistanceSymmetry() throws {
    TestSupport.initializeSFCGALOnce()
    let a = try unitSquare()
    let b = try shiftedSquare()
    #expect(almostEqual(try a.distance(to: b), try b.distance(to: a)))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - distance3D
// ══════════════════════════════════════════════════════════════════════════════

@Test func testDistance3DBetweenPoints() throws {
    TestSupport.initializeSFCGALOnce()
    // (0,0,0) to (1,1,1): distance = √3
    let p1 = try Point(x: 0.0, y: 0.0, z: 0.0)
    let p2 = try Point(x: 1.0, y: 1.0, z: 1.0)
    let expected = 3.0.squareRoot()
    #expect(almostEqual(try p1.distance3D(to: p2), expected))
}

@Test func testDistance3DFlatGeometryMatchesDistance2D() throws {
    TestSupport.initializeSFCGALOnce()
    // Both points at z=0: 3D distance == 2D distance
    let p1 = try Point(x: 0.0, y: 0.0, z: 0.0)
    let p2 = try Point(x: 3.0, y: 4.0, z: 0.0)
    #expect(almostEqual(try p1.distance3D(to: p2), 5.0))
}

@Test func testDistance3DSymmetry() throws {
    TestSupport.initializeSFCGALOnce()
    let p1 = try Point(x: 1.0, y: 2.0, z: 3.0)
    let p2 = try Point(x: 4.0, y: 5.0, z: 6.0)
    #expect(almostEqual(try p1.distance3D(to: p2), try p2.distance3D(to: p1)))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Error handling
// ══════════════════════════════════════════════════════════════════════════════

@Test func testIntersectsOnValidGeometriesDoesNotThrow() throws {
    TestSupport.initializeSFCGALOnce()
    let a = try unitSquare()
    let b = try shiftedSquare()
    // Must not throw for valid inputs
    _ = try a.intersects(b)
}

@Test func testAreaOnValidGeometryDoesNotThrow() throws {
    TestSupport.initializeSFCGALOnce()
    _ = try unitSquare().area()
}

@Test func testDistanceOnValidGeometriesDoesNotThrow() throws {
    TestSupport.initializeSFCGALOnce()
    let a = try unitSquare()
    let b = try shiftedSquare()
    _ = try a.distance(to: b)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - validationResult (sfcgal_geometry_is_valid_detail)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testValidationResultValidGeometry() throws {
    TestSupport.initializeSFCGALOnce()
    let p = try unitSquare()
    let result = p.validationResult()
    #expect(result.isValid)
    #expect(result.reason == nil)
    // Valid geometry — no location needed
    #expect(result.location == nil)
}

@Test func testValidationResultInvalidGeometry() throws {
    TestSupport.initializeSFCGALOnce()
    // Self-intersecting polygon (bowtie) — definitively invalid.
    // The two triangles share only the centre point, making the ring self-intersect.
    let bowtie = try Geometry.fromWKT("POLYGON((0 0,1 1,1 0,0 1,0 0))")
    let result = bowtie.validationResult()
    #expect(!result.isValid)
    // SFCGAL must provide a reason string for an invalid geometry
    #expect(result.reason != nil)
    #expect(!(result.reason?.isEmpty ?? true))
}

@Test func testValidationResultValidPolygonWithHole() throws {
    TestSupport.initializeSFCGALOnce()
    // Valid polygon with correctly-wound hole — must pass validation
    let p = try Geometry.fromWKT(
        "POLYGON((0 0,4 0,4 4,0 4,0 0),(1 1,1 3,3 3,3 1,1 1))"
    )
    let result = p.validationResult()
    #expect(result.isValid)
    #expect(result.reason == nil)
}

@Test func testValidationResultAgreesWithIsValid() throws {
    TestSupport.initializeSFCGALOnce()
    // validationResult().isValid must agree with the base isValid property
    // for both valid and invalid geometries.
    let valid   = try unitSquare()
    let invalid = try Geometry.fromWKT("POLYGON((0 0,1 1,1 0,0 1,0 0))")
    #expect(valid.validationResult().isValid   == valid.isValid)
    #expect(invalid.validationResult().isValid == invalid.isValid)
}
