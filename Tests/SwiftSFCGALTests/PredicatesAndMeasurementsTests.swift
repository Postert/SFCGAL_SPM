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
    initializeSFCGAL()
    let a = try unitSquare()
    let b = try overlappingSquare()
    #expect(try a.intersects(b))
}

@Test func testIntersectsFalseForSeparatePolygons() throws {
    initializeSFCGAL()
    let a = try unitSquare()
    let b = try shiftedSquare()   // gap of 1 unit between them
    #expect(try !a.intersects(b))
}

@Test func testIntersectsTrueForSharedBoundaryPoint() throws {
    initializeSFCGAL()
    // Two squares that touch at exactly one point: (1,1)
    let a = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let b = try Geometry.fromWKT("POLYGON((1 1,2 1,2 2,1 2,1 1))")
    #expect(try a.intersects(b))
}

@Test func testIntersectsSymmetry() throws {
    initializeSFCGAL()
    let a = try unitSquare()
    let b = try overlappingSquare()
    #expect(try a.intersects(b) == b.intersects(a))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - intersects3D
// ══════════════════════════════════════════════════════════════════════════════

@Test func testIntersects3DOverlappingInAllDimensions() throws {
    initializeSFCGAL()
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
    initializeSFCGAL()
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
    initializeSFCGAL()
    let outer = try unitSquare()
    let inner = try innerSquare()
    #expect(try outer.covers(inner))
}

@Test func testCoversFalseForOverlappingPolygon() throws {
    initializeSFCGAL()
    let a = try unitSquare()
    let b = try overlappingSquare()   // extends beyond a on the right
    #expect(try !a.covers(b))
}

@Test func testCoversReflexive() throws {
    initializeSFCGAL()
    // Every geometry covers itself
    let a = try unitSquare()
    #expect(try a.covers(a))
}

@Test func testCoversTrueForBoundaryPoint() throws {
    initializeSFCGAL()
    // covers() includes boundary (unlike strict contains)
    let square = try unitSquare()
    let corner = try Point(x: 1.0, y: 1.0)   // exactly on the ring
    #expect(try square.covers(corner))
}

@Test func testCoversFalseWhenSeparated() throws {
    initializeSFCGAL()
    let a = try unitSquare()
    let b = try shiftedSquare()
    #expect(try !a.covers(b))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - isPlanar
// ══════════════════════════════════════════════════════════════════════════════

@Test func testIsPlanarTrueFor2DPolygon() throws {
    initializeSFCGAL()
    // All 2D geometries are trivially planar
    let p = try unitSquare()
    #expect(try p.isPlanar())
}

@Test func testIsPlanarTrueForFlatPolygonInZ() throws {
    initializeSFCGAL()
    // 3D polygon lying exactly on z = 0
    let p = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    #expect(try p.isPlanar())
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - orientation
// ══════════════════════════════════════════════════════════════════════════════

@Test func testOrientationCCWForStandardPolygon() throws {
    initializeSFCGAL()
    // Standard OGC exterior ring: counter-clockwise
    let p = try unitSquare()
    let o = try p.orientation()
    #expect(o == .counterClockwise)
}

@Test func testOrientationCWForReversedRing() throws {
    initializeSFCGAL()
    // Reversed winding: clockwise
    let p = try Geometry.fromWKT("POLYGON((0 0,0 1,1 1,1 0,0 0))")
    let o = try p.orientation()
    #expect(o == .clockwise)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - area (2D)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testAreaUnitSquare() throws {
    initializeSFCGAL()
    // Unit square has area exactly 1.0
    let a = try unitSquare().area()
    #expect(almostEqual(a, 1.0))
}

@Test func testArea4x3Rectangle() throws {
    initializeSFCGAL()
    // 4 × 3 rectangle → area = 12
    let r = try Geometry.fromWKT("POLYGON((0 0,4 0,4 3,0 3,0 0))")
    #expect(almostEqual(try r.area(), 12.0))
}

@Test func testAreaWithHole() throws {
    initializeSFCGAL()
    // 4×4 square (area 16) minus a 2×2 hole (area 4) → net area 12.
    // OGC rule: exterior ring CCW, interior ring (hole) CW.
    // Hole ring reversed to CW: (1 1,1 3,3 3,3 1,1 1)
    let p = try Geometry.fromWKT(
        "POLYGON((0 0,4 0,4 4,0 4,0 0),(1 1,1 3,3 3,3 1,1 1))"
    )
    #expect(almostEqual(try p.area(), 12.0))
}

@Test func testAreaPointIsZero() throws {
    initializeSFCGAL()
    let pt = try Point(x: 1.0, y: 2.0)
    #expect(almostEqual(try pt.area(), 0.0))
}

@Test func testAreaLineStringIsZero() throws {
    initializeSFCGAL()
    let ls = try Geometry.fromWKT("LINESTRING(0 0,1 0,1 1)")
    #expect(almostEqual(try ls.area(), 0.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - area3D
// ══════════════════════════════════════════════════════════════════════════════

@Test func testArea3DFlatPolygonMatchesArea2D() throws {
    initializeSFCGAL()
    // Flat 3D polygon on z=0 — 3D area equals 2D area
    let p = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    #expect(almostEqual(try p.area3D(), 1.0))
}

@Test func testArea3DRightTriangle() throws {
    initializeSFCGAL()
    // Right triangle with legs 3 and 4 → area = 0.5 × 3 × 4 = 6
    let t = try Geometry.fromWKT("POLYGON Z ((0 0 0,3 0 0,0 4 0,0 0 0))")
    #expect(almostEqual(try t.area3D(), 6.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - volume
// ══════════════════════════════════════════════════════════════════════════════

@Test func testVolumeUnitCube() throws {
    initializeSFCGAL()
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
    initializeSFCGAL()
    // Non-solid geometry — volume is 0
    let p = try unitSquare()
    #expect(almostEqual(try p.volume(), 0.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - length (2D)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testLength345Triangle() throws {
    initializeSFCGAL()
    // The segment from (0,0) to (3,4) has length 5 (3-4-5 right triangle)
    let ls = try Geometry.fromWKT("LINESTRING(0 0,3 4)")
    #expect(almostEqual(try ls.length(), 5.0))
}

@Test func testLengthUnitSegment() throws {
    initializeSFCGAL()
    let ls = try Geometry.fromWKT("LINESTRING(0 0,1 0)")
    #expect(almostEqual(try ls.length(), 1.0))
}

@Test func testLengthMultiSegment() throws {
    initializeSFCGAL()
    // Three unit segments: total length 3
    let ls = try Geometry.fromWKT("LINESTRING(0 0,1 0,2 0,3 0)")
    #expect(almostEqual(try ls.length(), 3.0))
}

@Test func testLengthPolygonIsZero() throws {
    initializeSFCGAL()
    #expect(almostEqual(try unitSquare().length(), 0.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - length3D
// ══════════════════════════════════════════════════════════════════════════════

@Test func testLength3DDiagonal() throws {
    initializeSFCGAL()
    // (0,0,0) → (1,1,1): 3D length = √3 ≈ 1.7320508...
    let ls = try Geometry.fromWKT("LINESTRING Z (0 0 0,1 1 1)")
    let expected = 3.0.squareRoot()
    #expect(almostEqual(try ls.length3D(), expected))
}

@Test func testLength3DFlatSegmentMatchesLength2D() throws {
    initializeSFCGAL()
    // Flat segment on z=0: 3D length == 2D length
    let ls = try Geometry.fromWKT("LINESTRING Z (0 0 0,3 4 0)")
    #expect(almostEqual(try ls.length3D(), 5.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - distance (2D)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testDistanceZeroForIntersectingGeometries() throws {
    initializeSFCGAL()
    let a = try unitSquare()
    let b = try overlappingSquare()
    #expect(almostEqual(try a.distance(to: b), 0.0))
}

@Test func testDistanceSeparatedPolygons() throws {
    initializeSFCGAL()
    // Unit square [0,1]×[0,1] and square [2,3]×[0,1]: gap of 1 unit
    let a = try unitSquare()
    let b = try shiftedSquare()
    #expect(almostEqual(try a.distance(to: b), 1.0))
}

@Test func testDistanceBetweenTwoPoints() throws {
    initializeSFCGAL()
    // (0,0) to (3,4): distance = 5 (3-4-5)
    let p1 = try Point(x: 0.0, y: 0.0)
    let p2 = try Point(x: 3.0, y: 4.0)
    #expect(almostEqual(try p1.distance(to: p2), 5.0))
}

@Test func testDistanceSymmetry() throws {
    initializeSFCGAL()
    let a = try unitSquare()
    let b = try shiftedSquare()
    #expect(almostEqual(try a.distance(to: b), try b.distance(to: a)))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - distance3D
// ══════════════════════════════════════════════════════════════════════════════

@Test func testDistance3DBetweenPoints() throws {
    initializeSFCGAL()
    // (0,0,0) to (1,1,1): distance = √3
    let p1 = try Point(x: 0.0, y: 0.0, z: 0.0)
    let p2 = try Point(x: 1.0, y: 1.0, z: 1.0)
    let expected = 3.0.squareRoot()
    #expect(almostEqual(try p1.distance3D(to: p2), expected))
}

@Test func testDistance3DFlatGeometryMatchesDistance2D() throws {
    initializeSFCGAL()
    // Both points at z=0: 3D distance == 2D distance
    let p1 = try Point(x: 0.0, y: 0.0, z: 0.0)
    let p2 = try Point(x: 3.0, y: 4.0, z: 0.0)
    #expect(almostEqual(try p1.distance3D(to: p2), 5.0))
}

@Test func testDistance3DSymmetry() throws {
    initializeSFCGAL()
    let p1 = try Point(x: 1.0, y: 2.0, z: 3.0)
    let p2 = try Point(x: 4.0, y: 5.0, z: 6.0)
    #expect(almostEqual(try p1.distance3D(to: p2), try p2.distance3D(to: p1)))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Error handling
// ══════════════════════════════════════════════════════════════════════════════

@Test func testIntersectsOnValidGeometriesDoesNotThrow() throws {
    initializeSFCGAL()
    let a = try unitSquare()
    let b = try shiftedSquare()
    // Must not throw for valid inputs
    _ = try a.intersects(b)
}

@Test func testAreaOnValidGeometryDoesNotThrow() throws {
    initializeSFCGAL()
    _ = try unitSquare().area()
}

@Test func testDistanceOnValidGeometriesDoesNotThrow() throws {
    initializeSFCGAL()
    let a = try unitSquare()
    let b = try shiftedSquare()
    _ = try a.distance(to: b)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - validationResult (sfcgal_geometry_is_valid_detail)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testValidationResultValidGeometry() throws {
    initializeSFCGAL()
    let p = try unitSquare()
    let result = p.validationResult()
    #expect(result.isValid)
    #expect(result.reason == nil)
    // Valid geometry — no location needed
    #expect(result.location == nil)
}

@Test func testValidationResultInvalidGeometry() throws {
    initializeSFCGAL()
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
    initializeSFCGAL()
    // Valid polygon with correctly-wound hole — must pass validation
    let p = try Geometry.fromWKT(
        "POLYGON((0 0,4 0,4 4,0 4,0 0),(1 1,1 3,3 3,3 1,1 1))"
    )
    let result = p.validationResult()
    #expect(result.isValid)
    #expect(result.reason == nil)
}

@Test func testValidationResultAgreesWithIsValid() throws {
    initializeSFCGAL()
    // validationResult().isValid must agree with the base isValid property
    // for both valid and invalid geometries.
    let valid   = try unitSquare()
    let invalid = try Geometry.fromWKT("POLYGON((0 0,1 1,1 0,0 1,0 0))")
    #expect(valid.validationResult().isValid   == valid.isValid)
    #expect(invalid.validationResult().isValid == invalid.isValid)
}
