import Testing
import Foundation
@testable import SwiftSFCGAL

// ══════════════════════════════════════════════════════════════════════════════
// Issue #10 — Concrete geometry subclass tests
// ══════════════════════════════════════════════════════════════════════════════

// MARK: - Point

@Test func testPointCreate2D() throws {
    initializeSFCGAL()
    let p = try Point(x: 3.0, y: 4.0)
    #expect(p.x == 3.0)
    #expect(p.y == 4.0)
    #expect(!p.is3D)
    #expect(p.geometryType == "Point")
}

@Test func testPointCreate3D() throws {
    initializeSFCGAL()
    let p = try Point(x: 1.0, y: 2.0, z: 5.5)
    #expect(p.x == 1.0)
    #expect(p.y == 2.0)
    #expect(p.z == 5.5)
    #expect(p.is3D)
}

@Test func testPointWKTRoundtrip() throws {
    initializeSFCGAL()
    let p = try Point(x: 7.0, y: 8.0, z: 9.0)
    let wkt = p.asWKT()
    #expect(wkt.contains("POINT"))
    #expect(wkt.contains("7"))
    #expect(wkt.contains("8"))
    #expect(wkt.contains("9"))
}

@Test func testPointFromWKT() throws {
    initializeSFCGAL()
    let geom = try Geometry.fromWKT("POINT(10 20 30)")
    let p = try #require(geom as? Point)
    #expect(p.x == 10.0)
    #expect(p.y == 20.0)
    #expect(p.z == 30.0)
}

@Test func testPointCloneIsTyped() throws {
    initializeSFCGAL()
    let original = try Point(x: 1.0, y: 2.0, z: 3.0)
    let cloned = try original.clone()
    let typedClone = try #require(cloned as? Point)
    #expect(typedClone.x == 1.0)
    #expect(typedClone.y == 2.0)
    #expect(typedClone.z == 3.0)
    #expect(original !== typedClone)
}

// MARK: - LineString

@Test func testLineStringCreateAndAddPoints() throws {
    initializeSFCGAL()
    let ls = try LineString()
    let p0 = try Point(x: 0.0, y: 0.0)
    let p1 = try Point(x: 1.0, y: 1.0)
    let p2 = try Point(x: 2.0, y: 0.0)
    try ls.addPoint(p0)
    try ls.addPoint(p1)
    try ls.addPoint(p2)
    #expect(ls.numPoints == 3)
}

@Test func testLineStringPointAt() throws {
    initializeSFCGAL()
    let ls = try LineString()
    try ls.addPoint(Point(x: 5.0, y: 6.0))
    try ls.addPoint(Point(x: 7.0, y: 8.0))
    let first = ls.pointAt(0)
    #expect(first.x == 5.0)
    #expect(first.y == 6.0)
    let second = ls.pointAt(1)
    #expect(second.x == 7.0)
    #expect(second.y == 8.0)
}

@Test func testLineStringFromWKT() throws {
    initializeSFCGAL()
    let geom = try Geometry.fromWKT("LINESTRING(0 0,1 1,2 0)")
    let ls = try #require(geom as? LineString)
    #expect(ls.numPoints == 3)
    #expect(ls.geometryType == "LineString")
}

@Test func testLineStringPoints() throws {
    initializeSFCGAL()
    let ls = try LineString()
    try ls.addPoint(Point(x: 1.0, y: 2.0))
    try ls.addPoint(Point(x: 3.0, y: 4.0))
    let pts = try ls.points()
    #expect(pts.count == 2)
    #expect(pts[0].x == 1.0)
    #expect(pts[1].x == 3.0)
}

// MARK: - Polygon

@Test func testPolygonCreate() throws {
    initializeSFCGAL()
    let p = try Polygon()
    #expect(p.geometryType == "Polygon")
    #expect(p.numInteriorRings == 0)
}

@Test func testPolygonFromExteriorRing() throws {
    initializeSFCGAL()
    let ring = try LineString()
    for (x, y) in [(0.0,0.0),(1.0,0.0),(1.0,1.0),(0.0,1.0),(0.0,0.0)] {
        try ring.addPoint(Point(x: x, y: y))
    }
    let polygon = try Polygon(exteriorRing: ring)
    #expect(polygon.geometryType == "Polygon")
    #expect(polygon.exteriorRing.numPoints == 5)
    #expect(polygon.numInteriorRings == 0)
}

@Test func testPolygonFromWKT() throws {
    initializeSFCGAL()
    let geom = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let polygon = try #require(geom as? Polygon)
    #expect(polygon.exteriorRing.numPoints == 5)
}

@Test func testPolygonWithHole() throws {
    initializeSFCGAL()
    let geom = try Geometry.fromWKT(
        "POLYGON((0 0,10 0,10 10,0 10,0 0),(2 2,2 8,8 8,8 2,2 2))"
    )
    let polygon = try #require(geom as? Polygon)
    #expect(polygon.numInteriorRings == 1)
    let hole = polygon.interiorRingAt(0)
    #expect(hole.numPoints == 5)
}

// MARK: - Triangle

@Test func testTriangleCreate() throws {
    initializeSFCGAL()
    let a = try Point(x: 0.0, y: 0.0, z: 0.0)
    let b = try Point(x: 1.0, y: 0.0, z: 0.0)
    let c = try Point(x: 0.0, y: 1.0, z: 0.0)
    let tri = try Triangle(a: a, b: b, c: c)
    #expect(tri.geometryType == "Triangle")
    #expect(tri.vertexA.x == 0.0)
    #expect(tri.vertexB.x == 1.0)
    #expect(tri.vertexC.y == 1.0)
}

@Test func testTriangleFromWKT() throws {
    initializeSFCGAL()
    let geom = try Geometry.fromWKT("TRIANGLE((0 0 0,1 0 0,0 1 0,0 0 0))")
    let tri = try #require(geom as? Triangle)
    #expect(tri.vertex(0).x == 0.0)
    #expect(tri.vertex(1).x == 1.0)
}

// MARK: - GeometryCollection

@Test func testGeometryCollectionCreate() throws {
    initializeSFCGAL()
    let col = try GeometryCollection()
    #expect(col.numGeometries == 0)
    try col.addGeometry(Point(x: 1.0, y: 2.0))
    #expect(col.numGeometries == 1)
}

@Test func testGeometryCollectionFromWKT() throws {
    initializeSFCGAL()
    let geom = try Geometry.fromWKT(
        "GEOMETRYCOLLECTION(POINT(1 2),LINESTRING(0 0,1 1))"
    )
    let col = try #require(geom as? GeometryCollection)
    #expect(col.numGeometries == 2)
    let first = col.geometryAt(0)
    #expect(first is Point)
    let second = col.geometryAt(1)
    #expect(second is LineString)
}

// MARK: - MultiPoint

@Test func testMultiPointCreate() throws {
    initializeSFCGAL()
    let mp = try MultiPoint()
    try mp.addGeometry(Point(x: 1.0, y: 2.0))
    try mp.addGeometry(Point(x: 3.0, y: 4.0))
    #expect(mp.numGeometries == 2)
    #expect(mp.pointAt(0).x == 1.0)
    #expect(mp.pointAt(1).x == 3.0)
}

@Test func testMultiPointFromWKT() throws {
    initializeSFCGAL()
    let geom = try Geometry.fromWKT("MULTIPOINT((0 0),(1 1),(2 2))")
    let mp = try #require(geom as? MultiPoint)
    #expect(mp.numGeometries == 3)
}

// MARK: - MultiLineString

@Test func testMultiLineStringFromWKT() throws {
    initializeSFCGAL()
    let geom = try Geometry.fromWKT("MULTILINESTRING((0 0,1 1),(2 2,3 3))")
    let mls = try #require(geom as? MultiLineString)
    #expect(mls.numGeometries == 2)
    #expect(mls.lineStringAt(0).numPoints == 2)
}

// MARK: - MultiPolygon

@Test func testMultiPolygonFromWKT() throws {
    initializeSFCGAL()
    let geom = try Geometry.fromWKT(
        "MULTIPOLYGON(((0 0,1 0,1 1,0 1,0 0)),((2 2,3 2,3 3,2 3,2 2)))"
    )
    let mp = try #require(geom as? MultiPolygon)
    #expect(mp.numGeometries == 2)
    #expect(mp.polygonAt(0).exteriorRing.numPoints == 5)
}

// MARK: - PolyhedralSurface

@Test func testPolyhedralSurfaceCreate() throws {
    initializeSFCGAL()
    let ps = try PolyhedralSurface()
    #expect(ps.numPatches == 0)
    #expect(ps.geometryType == "PolyhedralSurface")
}

@Test func testPolyhedralSurfaceFromWKT() throws {
    initializeSFCGAL()
    let wkt = """
    POLYHEDRALSURFACE Z (
      ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0)),
      ((0 0 0,0 0 1,1 0 1,1 0 0,0 0 0))
    )
    """
    let geom = try Geometry.fromWKT(wkt)
    let ps = try #require(geom as? PolyhedralSurface)
    #expect(ps.numPatches == 2)
    let face = ps.patchAt(0)
    #expect(face.geometryType == "Polygon")
}

// MARK: - TriangulatedSurface

@Test func testTriangulatedSurfaceCreate() throws {
    initializeSFCGAL()
    let tin = try TriangulatedSurface()
    #expect(tin.numPatches == 0)
    #expect(tin.geometryType == "TriangulatedSurface")
}

@Test func testTriangulatedSurfaceFromWKT() throws {
    initializeSFCGAL()
    let wkt = "TIN Z (((0 0 0,1 0 0,0 1 0,0 0 0)),((1 0 0,1 1 0,0 1 0,1 0 0)))"
    let geom = try Geometry.fromWKT(wkt)
    let tin = try #require(geom as? TriangulatedSurface)
    #expect(tin.numPatches == 2)
    let tri = tin.patchAt(0)
    #expect(tri.geometryType == "Triangle")
}

// MARK: - Solid

@Test func testSolidCreate() throws {
    initializeSFCGAL()
    let solid = try Solid()
    #expect(solid.geometryType == "Solid")
}

@Test func testSolidFromWKT() throws {
    initializeSFCGAL()
    // Simple unit-cube solid
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
    let geom = try Geometry.fromWKT(wkt)
    let solid = try #require(geom as? Solid)
    #expect(solid.numShells >= 1)
    let shell = solid.exteriorShell
    #expect(shell.geometryType == "PolyhedralSurface")
    #expect(shell.numPatches == 6)
}

// MARK: - fromWKT factory dispatch

@Test func testFromWKTReturnsCorrectSubclasses() throws {
    initializeSFCGAL()
    // AnyClass (= AnyObject.Type) lets us store heterogeneous class metatypes.
    // ObjectIdentifier gives a stable identity comparison between metatypes.
    let cases: [(String, AnyClass)] = [
        ("POINT(1 2)",                                 Point.self),
        ("LINESTRING(0 0,1 1)",                        LineString.self),
        ("POLYGON((0 0,1 0,1 1,0 1,0 0))",            Polygon.self),
        ("TRIANGLE((0 0 0,1 0 0,0 1 0,0 0 0))",       Triangle.self),
        ("MULTIPOINT((0 0),(1 1))",                    MultiPoint.self),
        ("MULTILINESTRING((0 0,1 1),(2 2,3 3))",       MultiLineString.self),
        ("MULTIPOLYGON(((0 0,1 0,1 1,0 1,0 0)))",     MultiPolygon.self),
        ("GEOMETRYCOLLECTION(POINT(0 0))",             GeometryCollection.self),
    ]
    for (wkt, expectedType): (String, AnyClass) in cases {
        let geom = try Geometry.fromWKT(wkt)
        #expect(
            ObjectIdentifier(type(of: geom)) == ObjectIdentifier(expectedType),
            "Expected \(expectedType) for \(wkt), got \(type(of: geom))"
        )
    }
}

// MARK: - Borrowed-handle lifetime safety

@Test func testBorrowedPointFromLineStringIsStable() throws {
    initializeSFCGAL()
    let ls = try LineString()
    try ls.addPoint(Point(x: 42.0, y: 99.0))
    let borrowed = ls.pointAt(0)
    // Read coordinate while ls is still alive
    #expect(borrowed.x == 42.0)
    // borrowed goes out of scope first — ls is still alive so no dangling access
}

@Test func testBorrowedRingFromPolygonIsStable() throws {
    initializeSFCGAL()
    let geom = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let polygon = try #require(geom as? Polygon)
    let ring = polygon.exteriorRing   // borrowed reference
    #expect(ring.numPoints == 5)
    // ring and polygon both released here — no double-free
}
