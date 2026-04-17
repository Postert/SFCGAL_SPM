import Testing
import Foundation
@testable import SwiftSFCGAL

// ══════════════════════════════════════════════════════════════════════════════
// Issue #13 — Boolean set operations
//
// All expected values are derived from first principles so test failures
// clearly indicate an implementation problem, not a rounding choice.
//
// Geometry layout used throughout:
//
//   unitSquare    = [0,1]×[0,1]  area = 1.0
//   rightSquare   = [0.5,1.5]×[0,1]  area = 1.0
//   overlap strip = [0.5,1]×[0,1]   area = 0.5
//   disjointSquare= [2,3]×[0,1]  area = 1.0  (1-unit gap from unitSquare)
// ══════════════════════════════════════════════════════════════════════════════

// MARK: - Helpers

private func almostEqual(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance
}

// Shared 2D fixtures
private func unitSquare() throws -> Geometry {
    try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
}
private func rightSquare() throws -> Geometry {
    // Overlaps unitSquare in the strip x∈[0.5,1], full overlap area = 0.5
    try Geometry.fromWKT("POLYGON((0.5 0,1.5 0,1.5 1,0.5 1,0.5 0))")
}
private func disjointSquare() throws -> Geometry {
    // Completely separate from unitSquare — gap of 1 unit
    try Geometry.fromWKT("POLYGON((2 0,3 0,3 1,2 1,2 0))")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 2D intersection
// ══════════════════════════════════════════════════════════════════════════════

@Test func testIntersection2DOverlap() throws {
    initializeSFCGAL()
    // Overlap strip [0.5,1]×[0,1] → area = 0.5
    let result = try unitSquare().intersection(rightSquare())
    #expect(almostEqual(try result.area(), 0.5))
}

@Test func testIntersection2DDisjoint() throws {
    initializeSFCGAL()
    // No overlap → empty geometry, area = 0
    let result = try unitSquare().intersection(disjointSquare())
    #expect(almostEqual(try result.area(), 0.0))
}

@Test func testIntersection2DIdentical() throws {
    initializeSFCGAL()
    // A ∩ A = A → area preserved
    let a = try unitSquare()
    let result = try a.intersection(a)
    #expect(almostEqual(try result.area(), 1.0))
}

@Test func testIntersection2DIsSymmetric() throws {
    initializeSFCGAL()
    // A ∩ B == B ∩ A  (area-wise)
    let a = try unitSquare()
    let b = try rightSquare()
    let ab = try a.intersection(b)
    let ba = try b.intersection(a)
    #expect(almostEqual(try ab.area(), try ba.area()))
}

@Test func testIntersection2DResultIsOwned() throws {
    initializeSFCGAL()
    // The result survives the inputs going out of scope
    let result: Geometry
    do {
        let a = try unitSquare()
        let b = try rightSquare()
        result = try a.intersection(b)
    }
    // a and b are now freed — result must still be valid
    #expect(almostEqual(try result.area(), 0.5))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 2D union
// ══════════════════════════════════════════════════════════════════════════════

@Test func testUnion2DOverlap() throws {
    initializeSFCGAL()
    // area(A) + area(B) − area(A∩B) = 1 + 1 − 0.5 = 1.5
    let result = try unitSquare().union(rightSquare())
    #expect(almostEqual(try result.area(), 1.5))
}

@Test func testUnion2DDisjoint() throws {
    initializeSFCGAL()
    // Separate polygons → combined area = 1 + 1 = 2.0
    let result = try unitSquare().union(disjointSquare())
    #expect(almostEqual(try result.area(), 2.0))
}

@Test func testUnion2DIdentical() throws {
    initializeSFCGAL()
    // A ∪ A = A → area = 1.0
    let a = try unitSquare()
    let result = try a.union(a)
    #expect(almostEqual(try result.area(), 1.0))
}

@Test func testUnion2DIsSymmetric() throws {
    initializeSFCGAL()
    let a = try unitSquare()
    let b = try rightSquare()
    let ab = try a.union(b)
    let ba = try b.union(a)
    #expect(almostEqual(try ab.area(), try ba.area()))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 2D difference
// ══════════════════════════════════════════════════════════════════════════════

@Test func testDifference2DOverlap() throws {
    initializeSFCGAL()
    // unitSquare minus rightSquare → left strip [0,0.5]×[0,1] → area = 0.5
    let result = try unitSquare().difference(rightSquare())
    #expect(almostEqual(try result.area(), 0.5))
}

@Test func testDifference2DDisjoint() throws {
    initializeSFCGAL()
    // unitSquare minus something far away → unchanged → area = 1.0
    let result = try unitSquare().difference(disjointSquare())
    #expect(almostEqual(try result.area(), 1.0))
}

@Test func testDifference2DIdentical() throws {
    initializeSFCGAL()
    // A − A = empty → area = 0
    let a = try unitSquare()
    let result = try a.difference(a)
    #expect(almostEqual(try result.area(), 0.0))
}

@Test func testDifference2DIsAsymmetric() throws {
    initializeSFCGAL()
    // A − B ≠ B − A when they only partially overlap
    let a = try unitSquare()
    let b = try rightSquare()
    let ab = try a.difference(b)  // left strip,  area ≈ 0.5
    let ba = try b.difference(a)  // right strip, area ≈ 0.5
    // Both are 0.5 in this symmetric case — verify their WKT differs to confirm
    // the operation is genuinely asymmetric (different spatial regions).
    #expect(ab.asWKT() != ba.asWKT())
}

// Inclusion–exclusion: area(A) = area(A∩B) + area(A−B)
@Test func testDifference2DInclusionExclusion() throws {
    initializeSFCGAL()
    let a = try unitSquare()
    let b = try rightSquare()
    let inter = try a.intersection(b)
    let diff  = try a.difference(b)
    let total = try inter.area() + diff.area()
    #expect(almostEqual(total, try a.area()))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 3D intersection
// ══════════════════════════════════════════════════════════════════════════════

@Test func testIntersection3DCoplanarOverlap() throws {
    initializeSFCGAL()
    // Two flat polygons at z=0, overlapping in strip x∈[0.5,1] → area3D = 0.5
    let a = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    let b = try Geometry.fromWKT("POLYGON Z ((0.5 0 0,1.5 0 0,1.5 1 0,0.5 1 0,0.5 0 0))")
    let result = try a.intersection3D(b)
    #expect(almostEqual(try result.area3D(), 0.5))
}

@Test func testIntersection3DDifferentZIsEmpty() throws {
    initializeSFCGAL()
    // Same XY footprint but at different Z → no 3D intersection
    let low  = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    let high = try Geometry.fromWKT("POLYGON Z ((0 0 5,1 0 5,1 1 5,0 1 5,0 0 5))")
    let result = try low.intersection3D(high)
    #expect(almostEqual(try result.area3D(), 0.0))
}

@Test func testIntersection3DIsSymmetric() throws {
    initializeSFCGAL()
    let a = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    let b = try Geometry.fromWKT("POLYGON Z ((0.5 0 0,1.5 0 0,1.5 1 0,0.5 1 0,0.5 0 0))")
    let ab = try a.intersection3D(b)
    let ba = try b.intersection3D(a)
    #expect(almostEqual(try ab.area3D(), try ba.area3D()))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 3D union
// ══════════════════════════════════════════════════════════════════════════════

@Test func testUnion3DCoplanarOverlap() throws {
    initializeSFCGAL()
    // area(A) + area(B) − area(A∩B) = 1 + 1 − 0.5 = 1.5
    let a = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    let b = try Geometry.fromWKT("POLYGON Z ((0.5 0 0,1.5 0 0,1.5 1 0,0.5 1 0,0.5 0 0))")
    let result = try a.union3D(b)
    #expect(almostEqual(try result.area3D(), 1.5))
}

@Test func testUnion3DIsSymmetric() throws {
    initializeSFCGAL()
    let a = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    let b = try Geometry.fromWKT("POLYGON Z ((0.5 0 0,1.5 0 0,1.5 1 0,0.5 1 0,0.5 0 0))")
    let ab = try a.union3D(b)
    let ba = try b.union3D(a)
    #expect(almostEqual(try ab.area3D(), try ba.area3D()))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 3D difference
// ══════════════════════════════════════════════════════════════════════════════

@Test func testDifference3DCoplanarOverlap() throws {
    initializeSFCGAL()
    // a minus overlapping b → left strip [0,0.5]×[0,1] → area3D = 0.5
    let a = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    let b = try Geometry.fromWKT("POLYGON Z ((0.5 0 0,1.5 0 0,1.5 1 0,0.5 1 0,0.5 0 0))")
    let result = try a.difference3D(b)
    #expect(almostEqual(try result.area3D(), 0.5))
}

@Test func testDifference3DIdentical() throws {
    initializeSFCGAL()
    // A − A = empty → area3D = 0
    let a = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    let result = try a.difference3D(a)
    #expect(almostEqual(try result.area3D(), 0.0))
}

// Inclusion–exclusion in 3D: area3D(A) = area3D(A∩B) + area3D(A−B)
@Test func testDifference3DInclusionExclusion() throws {
    initializeSFCGAL()
    let a = try Geometry.fromWKT("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    let b = try Geometry.fromWKT("POLYGON Z ((0.5 0 0,1.5 0 0,1.5 1 0,0.5 1 0,0.5 0 0))")
    let inter = try a.intersection3D(b)
    let diff  = try a.difference3D(b)
    let total = try inter.area3D() + diff.area3D()
    #expect(almostEqual(total, try a.area3D()))
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Result ownership
// ══════════════════════════════════════════════════════════════════════════════

@Test func testBooleanResultIsTyped() throws {
    initializeSFCGAL()
    // Intersection of two polygons should come back as a Polygon (or subtype)
    let result = try unitSquare().intersection(rightSquare())
    // Result must be a non-empty geometry with valid WKT
    #expect(!result.asWKT().isEmpty)
    #expect(result.isValid)
}

@Test func testUnionResultIsTyped() throws {
    initializeSFCGAL()
    let result = try unitSquare().union(rightSquare())
    #expect(!result.asWKT().isEmpty)
    #expect(result.isValid)
}

@Test func testDifferenceResultIsTyped() throws {
    initializeSFCGAL()
    let result = try unitSquare().difference(rightSquare())
    #expect(!result.asWKT().isEmpty)
    #expect(result.isValid)
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - WKB round-trip through boolean result
// ══════════════════════════════════════════════════════════════════════════════

@Test func testIntersectionResultRoundtripsWKB() throws {
    initializeSFCGAL()
    let result = try unitSquare().intersection(rightSquare())
    let wkb    = result.asWKB()
    #expect(!wkb.isEmpty)
    let parsed = try Geometry.fromWKB(wkb)
    #expect(almostEqual(try parsed.area(), try result.area()))
}
