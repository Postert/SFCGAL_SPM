import Testing
import Foundation
@testable import SwiftSFCGAL

// ══════════════════════════════════════════════════════════════════════════════
// Issue #15 — Transformation operations
//
// Coverage: every transformation function exposed by SFCGAL 2.2.0's C API.
//
// Expected values are derived from first principles:
//
//   • Translation preserves area, length, and shape.
//   • Rotation preserves area; rotating (1,0) by π/2 about origin → (0,1).
//   • Scale: area scales by factor², volume by factor³.
//   • Extruding a unit square by (0,0,h) produces a Solid with volume h.
// ══════════════════════════════════════════════════════════════════════════════

// MARK: - Helpers

private func almostEqual(_ a: Double, _ b: Double, tol: Double = 1e-9) -> Bool {
    abs(a - b) <= tol
}

private func unitSquare2D() throws -> Geometry {
    try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
}

private func rectangle2x3() throws -> Geometry {
    try Geometry.fromWKT("POLYGON((0 0,2 0,2 3,0 3,0 0))")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Translation
// ══════════════════════════════════════════════════════════════════════════════

@Test func testTranslate2DMovesPoint() throws {
    initializeSFCGAL()
    let p = try Point(x: 1.0, y: 2.0)
    let moved = try p.translated(dx: 3.0, dy: 4.0)
    let result = try #require(moved as? Point)
    #expect(almostEqual(result.x, 4.0))
    #expect(almostEqual(result.y, 6.0))
}

@Test func testTranslate3DMovesPoint() throws {
    initializeSFCGAL()
    let p = try Point(x: 1.0, y: 2.0, z: 3.0)
    let moved = try p.translated(dx: 10.0, dy: 20.0, dz: 30.0)
    let result = try #require(moved as? Point)
    #expect(almostEqual(result.x, 11.0))
    #expect(almostEqual(result.y, 22.0))
    #expect(almostEqual(result.z, 33.0))
}

@Test func testTranslatePreservesArea() throws {
    initializeSFCGAL()
    let original = try unitSquare2D()
    let moved    = try original.translated(dx: 100.0, dy: 200.0)
    #expect(almostEqual(try moved.area(), 1.0))
}

@Test func testTranslateIdentity() throws {
    initializeSFCGAL()
    // Translating by zero must preserve area (and effectively be identity)
    let original = try unitSquare2D()
    let moved    = try original.translated(dx: 0.0, dy: 0.0, dz: 0.0)
    #expect(almostEqual(try moved.area(), 1.0))
}

@Test func testTranslateResultIsOwned() throws {
    initializeSFCGAL()
    let result: Geometry
    do {
        let p = try Point(x: 1.0, y: 2.0)
        result = try p.translated(dx: 5.0, dy: 5.0)
    }
    // Original p is freed — result must remain valid
    let pt = try #require(result as? Point)
    #expect(almostEqual(pt.x, 6.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Rotation
// ══════════════════════════════════════════════════════════════════════════════

@Test func testRotate2DBy90Degrees() throws {
    initializeSFCGAL()
    // (1, 0) rotated by π/2 around origin → (0, 1)
    let p = try Point(x: 1.0, y: 0.0)
    let rotated = try p.rotated(angle: .pi / 2)
    let result = try #require(rotated as? Point)
    #expect(almostEqual(result.x, 0.0, tol: 1e-9))
    #expect(almostEqual(result.y, 1.0, tol: 1e-9))
}

@Test func testRotate2DFullTurnIsIdentity() throws {
    initializeSFCGAL()
    // (1, 0) rotated by 2π → back to (1, 0)
    let p = try Point(x: 1.0, y: 0.0)
    let rotated = try p.rotated(angle: 2.0 * .pi)
    let result = try #require(rotated as? Point)
    #expect(almostEqual(result.x, 1.0, tol: 1e-9))
    #expect(almostEqual(result.y, 0.0, tol: 1e-9))
}

@Test func testRotatePreservesArea() throws {
    initializeSFCGAL()
    // Rotation is rigid — areas are invariant
    let original = try unitSquare2D()
    let rotated  = try original.rotated(angle: .pi / 4)
    #expect(almostEqual(try rotated.area(), 1.0, tol: 1e-9))
}

@Test func testRotate2DAroundCenter() throws {
    initializeSFCGAL()
    // (2, 1) rotated by π around (1, 1) → (0, 1)
    let p = try Point(x: 2.0, y: 1.0)
    let rotated = try p.rotated2D(angle: .pi, cx: 1.0, cy: 1.0)
    let result = try #require(rotated as? Point)
    #expect(almostEqual(result.x, 0.0, tol: 1e-9))
    #expect(almostEqual(result.y, 1.0, tol: 1e-9))
}

@Test func testRotate3DAroundZAxisMatches2D() throws {
    initializeSFCGAL()
    // 3D rotation around the Z-axis vector (0, 0, 1) of (1, 0, 5) by π/2
    // → (0, 1, 5)  (Z is preserved, XY rotates)
    let p = try Point(x: 1.0, y: 0.0, z: 5.0)
    let rotated = try p.rotated3D(angle: .pi / 2, ax: 0.0, ay: 0.0, az: 1.0)
    let result = try #require(rotated as? Point)
    #expect(almostEqual(result.x, 0.0, tol: 1e-9))
    #expect(almostEqual(result.y, 1.0, tol: 1e-9))
    #expect(almostEqual(result.z, 5.0, tol: 1e-9))
}

@Test func testRotate3DAroundCenter() throws {
    initializeSFCGAL()
    // (2, 0, 0) rotated by π around the X-axis through (1, 0, 0) → (2, 0, 0)
    // because the point lies on the rotation axis.
    let p = try Point(x: 2.0, y: 0.0, z: 0.0)
    let rotated = try p.rotated3D(angle: .pi,
                                  ax: 1.0, ay: 0.0, az: 0.0,
                                  cx: 1.0, cy: 0.0, cz: 0.0)
    let result = try #require(rotated as? Point)
    #expect(almostEqual(result.x, 2.0, tol: 1e-9))
    #expect(almostEqual(result.y, 0.0, tol: 1e-9))
    #expect(almostEqual(result.z, 0.0, tol: 1e-9))
}

@Test func testRotateXAxis() throws {
    initializeSFCGAL()
    // (0, 1, 0) rotated by π/2 around X-axis → (0, 0, 1)
    let p = try Point(x: 0.0, y: 1.0, z: 0.0)
    let rotated = try p.rotatedX(angle: .pi / 2)
    let result = try #require(rotated as? Point)
    #expect(almostEqual(result.x, 0.0, tol: 1e-9))
    #expect(almostEqual(result.y, 0.0, tol: 1e-9))
    #expect(almostEqual(result.z, 1.0, tol: 1e-9))
}

@Test func testRotateYAxis() throws {
    initializeSFCGAL()
    // (1, 0, 0) rotated by π/2 around Y-axis → (0, 0, -1)
    let p = try Point(x: 1.0, y: 0.0, z: 0.0)
    let rotated = try p.rotatedY(angle: .pi / 2)
    let result = try #require(rotated as? Point)
    #expect(almostEqual(result.x, 0.0, tol: 1e-9))
    #expect(almostEqual(result.y, 0.0, tol: 1e-9))
    #expect(almostEqual(result.z, -1.0, tol: 1e-9))
}

@Test func testRotateZAxis() throws {
    initializeSFCGAL()
    // (1, 0, 5) rotated by π/2 around Z-axis → (0, 1, 5)
    let p = try Point(x: 1.0, y: 0.0, z: 5.0)
    let rotated = try p.rotatedZ(angle: .pi / 2)
    let result = try #require(rotated as? Point)
    #expect(almostEqual(result.x, 0.0, tol: 1e-9))
    #expect(almostEqual(result.y, 1.0, tol: 1e-9))
    #expect(almostEqual(result.z, 5.0, tol: 1e-9))
}

@Test func testRotateZeroAngleIsIdentity() throws {
    initializeSFCGAL()
    let original = try unitSquare2D()
    let rotated  = try original.rotated(angle: 0.0)
    #expect(almostEqual(try rotated.area(), 1.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Scale
// ══════════════════════════════════════════════════════════════════════════════

@Test func testUniformScaleArea() throws {
    initializeSFCGAL()
    // Unit square scaled by 2 → area = 4 (factor²)
    let original = try unitSquare2D()
    let scaled   = try original.scaled(factor: 2.0)
    #expect(almostEqual(try scaled.area(), 4.0))
}

@Test func testUniformScaleHalvesArea() throws {
    initializeSFCGAL()
    // Unit square scaled by 0.5 → area = 0.25
    let original = try unitSquare2D()
    let scaled   = try original.scaled(factor: 0.5)
    #expect(almostEqual(try scaled.area(), 0.25))
}

@Test func testUniformScaleByOneIsIdentity() throws {
    initializeSFCGAL()
    let original = try unitSquare2D()
    let scaled   = try original.scaled(factor: 1.0)
    #expect(almostEqual(try scaled.area(), 1.0))
}

@Test func testNonUniformScale3D() throws {
    initializeSFCGAL()
    // Unit square (area=1) scaled by (2,3,1) → area = 6 (sx*sy)
    let original = try unitSquare2D()
    let scaled   = try original.scaled(sx: 2.0, sy: 3.0, sz: 1.0)
    #expect(almostEqual(try scaled.area(), 6.0))
}

@Test func testScaleAroundCenter() throws {
    initializeSFCGAL()
    // Unit square centred at (0.5, 0.5) scaled by (2,2,1) around its centre
    // produces a 2×2 square — area = 4
    let original = try unitSquare2D()
    let scaled   = try original.scaled(sx: 2.0, sy: 2.0, sz: 1.0,
                                       cx: 0.5, cy: 0.5, cz: 0.0)
    #expect(almostEqual(try scaled.area(), 4.0))
}

@Test func testScalePoint() throws {
    initializeSFCGAL()
    // (3, 4) scaled by 2 → (6, 8)
    let p = try Point(x: 3.0, y: 4.0)
    let scaled = try p.scaled(factor: 2.0)
    let result = try #require(scaled as? Point)
    #expect(almostEqual(result.x, 6.0))
    #expect(almostEqual(result.y, 8.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Extrusion (CityGML LOD1)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testExtrudeUnitSquareToBox() throws {
    initializeSFCGAL()
    // Unit square extruded by (0, 0, 5) → box with volume 1×1×5 = 5
    let footprint = try unitSquare2D()
    let solid     = try footprint.extrude(dx: 0.0, dy: 0.0, dz: 5.0)
    #expect(almostEqual(try solid.volume(), 5.0))
}

@Test func testExtrudeRectangleVolume() throws {
    initializeSFCGAL()
    // 2×3 rectangle extruded by 10 m → volume = 60 m³ (the LOD1 building case)
    let footprint = try rectangle2x3()
    let building  = try footprint.extrude(dx: 0.0, dy: 0.0, dz: 10.0)
    #expect(almostEqual(try building.volume(), 60.0))
}

@Test func testExtrudeReturnsSolid() throws {
    initializeSFCGAL()
    // The extruded result must be a Solid — that's how volume() returns non-zero
    let footprint = try unitSquare2D()
    let solid     = try footprint.extrude(dx: 0.0, dy: 0.0, dz: 1.0)
    #expect(solid is Solid)
}

@Test func testExtrudeResultIsValid() throws {
    initializeSFCGAL()
    let footprint = try unitSquare2D()
    let solid     = try footprint.extrude(dx: 0.0, dy: 0.0, dz: 1.0)
    #expect(solid.isValid)
}

@Test func testExtrudeResultIsOwned() throws {
    initializeSFCGAL()
    let result: Geometry
    do {
        let footprint = try unitSquare2D()
        result = try footprint.extrude(dx: 0.0, dy: 0.0, dz: 7.0)
    }
    // footprint freed — result must still be queryable
    #expect(almostEqual(try result.volume(), 7.0))
}

@Test func testExtrudeObliqueDirection() throws {
    initializeSFCGAL()
    // Extruding straight up versus obliquely both produce the same volume:
    //   volume = base_area * |dz|  (the projected height)
    // For a 1×1 square extruded by (3, 4, 5) the volume is 1*5 = 5.
    let footprint = try unitSquare2D()
    let solid     = try footprint.extrude(dx: 3.0, dy: 4.0, dz: 5.0)
    #expect(almostEqual(try solid.volume(), 5.0))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Straight skeleton
// ══════════════════════════════════════════════════════════════════════════════

@Test func testStraightSkeletonOnSquareIsValid() throws {
    initializeSFCGAL()
    let square   = try unitSquare2D()
    let skeleton = try square.straightSkeleton()
    // The skeleton of a square is a non-trivial multilinestring
    #expect(!skeleton.asWKT().isEmpty)
    // It has non-zero length (skeleton lines exist)
    #expect(try skeleton.length() > 0.0)
}

@Test func testStraightSkeletonWithDistancesOnSquareIsValid() throws {
    initializeSFCGAL()
    let square   = try unitSquare2D()
    let skeleton = try square.straightSkeletonWithDistances()
    #expect(!skeleton.asWKT().isEmpty)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Straight skeleton extrusion (CityGML LOD2 hipped roof)
// ══════════════════════════════════════════════════════════════════════════════

@Test func testStraightSkeletonExtrudeReturnsSolidGeometry() throws {
    initializeSFCGAL()
    // Hipped-roof extrusion on a unit square at height 1 → an open
    // PolyhedralSurface of 4 sloped roof triangles meeting at the apex.
    //
    // Each face is half of a base-1 × slant-√1.25 triangle, so the total 3D
    // surface area is 4 × 0.5 × 1 × √1.25 ≈ 2.236.  We verify it is positive
    // and significantly exceeds the 1.0 footprint area (which proves the roof
    // faces tilt upward — they would equal 1.0 only at zero height).
    let square = try unitSquare2D()
    let roof   = try square.straightSkeletonExtrude(height: 1.0)
    #expect(!roof.asWKT().isEmpty)
    #expect(try roof.area3D() > 1.0)
}

@Test func testStraightSkeletonExtrudeRectangle() throws {
    initializeSFCGAL()
    // 2×3 rectangle with ridge at height 2 → roof faces still cover more
    // 3D area than the 6.0 footprint (because every face is tilted).
    let rect = try rectangle2x3()
    let roof = try rect.straightSkeletonExtrude(height: 2.0)
    #expect(try roof.area3D() > 6.0)
}

@Test func testExtrudePolygonStraightSkeletonProducesBuildingWithRoof() throws {
    initializeSFCGAL()
    // 2×3 footprint, 10 m walls, 4 m roof.
    // The result is a PolyhedralSurface (open shell of walls + roof faces).
    //
    // Wall-only 3D area = perimeter × wall_height = 2*(2+3) * 10 = 100.
    // The roof adds four more sloped faces on top, so the total 3D area
    // must exceed 100 by a strictly positive margin.
    let footprint = try rectangle2x3()
    let building  = try footprint.extrudePolygonStraightSkeleton(buildingHeight: 10.0,
                                                                 roofHeight: 4.0)
    let a3d = try building.area3D()
    #expect(a3d > 100.0,
            "Building+roof 3D surface area \(a3d) should exceed wall-only area 100")
}

@Test func testExtrudePolygonStraightSkeletonResultIsValid() throws {
    initializeSFCGAL()
    let footprint = try unitSquare2D()
    let building  = try footprint.extrudePolygonStraightSkeleton(buildingHeight: 3.0,
                                                                 roofHeight: 1.0)
    #expect(building.isValid)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Straight skeleton partition
// ══════════════════════════════════════════════════════════════════════════════

@Test func testStraightSkeletonPartitionReturnsPolyhedralSurface() throws {
    initializeSFCGAL()
    // straight_skeleton_partition splits a polygon into faces along its
    // straight skeleton.  SFCGAL returns the result as a PolyhedralSurface
    // whose patches are the partition cells.
    //
    // Verified against the C API directly (test_partition.c):
    //   • The C function returns non-NULL.
    //   • It fires neither the error nor the warning handler.
    //   • The result is a PolyhedralSurface.
    //
    // (Note: the partition cells are emitted as triangle patches that may
    // omit the closing-point in their WKT — this is purely a serialisation
    // detail and does not affect the geometry the function returns.)
    let lShape = try Geometry.fromWKT(
        "POLYGON((0 0,4 0,4 2,2 2,2 4,0 4,0 0))"
    )
    let partition = try lShape.straightSkeletonPartition(autoOrientation: true)
    #expect(!partition.asWKT().isEmpty)
    #expect(partition is PolyhedralSurface,
            "Expected PolyhedralSurface, got \(type(of: partition))")
}

@Test func testStraightSkeletonPartitionUnitSquare() throws {
    initializeSFCGAL()
    // Unit square partition — verified against the C API: returns a
    // PolyhedralSurface of 4 triangular cells meeting at the centre (0.5, 0.5).
    let square    = try unitSquare2D()
    let partition = try square.straightSkeletonPartition(autoOrientation: true)
    #expect(!partition.asWKT().isEmpty)
    #expect(partition is PolyhedralSurface)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Composition / round-trip
// ══════════════════════════════════════════════════════════════════════════════

@Test func testTranslateThenInverseTranslateIsIdentity() throws {
    initializeSFCGAL()
    let p     = try Point(x: 7.0, y: 11.0)
    let there = try p.translated(dx: 3.0, dy: -4.0)
    let back  = try there.translated(dx: -3.0, dy: 4.0)
    let result = try #require(back as? Point)
    #expect(almostEqual(result.x, 7.0))
    #expect(almostEqual(result.y, 11.0))
}

@Test func testRotateThenInverseRotateIsIdentity() throws {
    initializeSFCGAL()
    let p     = try Point(x: 3.0, y: 4.0)
    let there = try p.rotated(angle: .pi / 3)
    let back  = try there.rotated(angle: -.pi / 3)
    let result = try #require(back as? Point)
    #expect(almostEqual(result.x, 3.0, tol: 1e-9))
    #expect(almostEqual(result.y, 4.0, tol: 1e-9))
}

@Test func testScaleThenInverseScaleIsIdentity() throws {
    initializeSFCGAL()
    let p     = try Point(x: 5.0, y: 7.0)
    let big   = try p.scaled(factor: 4.0)
    let back  = try big.scaled(factor: 0.25)
    let result = try #require(back as? Point)
    #expect(almostEqual(result.x, 5.0))
    #expect(almostEqual(result.y, 7.0))
}

@Test func testTransformThenWKTRoundtrip() throws {
    initializeSFCGAL()
    // Transform results round-trip cleanly through WKT
    let original = try unitSquare2D()
    let moved    = try original.translated(dx: 100.0, dy: 200.0)
    let wkt      = moved.asWKT()
    let parsed   = try Geometry.fromWKT(wkt)
    #expect(almostEqual(try parsed.area(), 1.0))
}
