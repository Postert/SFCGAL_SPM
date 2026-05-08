import Testing
@testable import SwiftSFCGAL

// MARK: - PointTest.cpp

@Test func upstreamPointXYConstructor() throws {
    // Upstream: PointTest.cpp / xyConstructor
    TestSupport.initializeSFCGALOnce()
    let point = try Point(x: 2.0, y: 3.0)
    #expect(!point.is3D)
    #expect(point.x == 2.0)
    #expect(point.y == 3.0)
    #expect(point.z == 0.0)
}

@Test func upstreamPointXYZConstructor() throws {
    // Upstream: PointTest.cpp / xyzConstructor
    TestSupport.initializeSFCGALOnce()
    let point = try Point(x: 2.0, y: 3.0, z: 4.0)
    #expect(point.is3D)
    #expect(point.x == 2.0)
    #expect(point.y == 3.0)
    #expect(point.z == 4.0)
}

@Test func upstreamPointCloneKeepsTypeAndCoordinates() throws {
    // Upstream: PointTest.cpp / testClone
    TestSupport.initializeSFCGALOnce()
    let point = try Point(x: 3.0, y: 4.0)
    let clone = try #require(point.clone() as? Point)
    #expect(clone.x == 3.0)
    #expect(clone.y == 4.0)
    #expect(clone.geometryType == "Point")
}

@Test func upstreamPointAsTextAndTypeMetadata() throws {
    // Upstream: PointTest.cpp / asText2d, asText3d, testGeometryType, testGeometryTypeId, testIs3D
    TestSupport.initializeSFCGALOnce()
    let point2D = try Point(x: 2.0, y: 3.0)
    let point3D = try Point(x: 2.0, y: 3.0, z: 4.0)
    UpstreamParity.expectWKT(point2D, decimals: 3, equals: "POINT (2.000 3.000)",
                             "PointTest.cpp / asText2d")
    UpstreamParity.expectWKT(point3D, decimals: 3, equals: "POINT Z (2.000 3.000 4.000)",
                             "PointTest.cpp / asText3d")
    #expect(point2D.geometryType == "Point")
    #expect(point2D.geometryTypeID == UpstreamParity.pointTypeID)
    #expect(!point2D.is3D)
    #expect(point3D.is3D)
}

@Test func upstreamPointAccessorsFromWKT() throws {
    // Upstream: PointTest.cpp / testAccessors, WktReaderTest.cpp / pointXY, pointXYZ_implicit, pointXYZ_explicit
    let xy = try UpstreamParity.point("POINT (4.0 6.0)")
    #expect(xy.x == 4.0)
    #expect(xy.y == 6.0)
    #expect(!xy.is3D)

    let xyzImplicit = try UpstreamParity.point("POINT (4.0 5.0 6.0)")
    #expect(xyzImplicit.is3D)
    #expect(xyzImplicit.x == 4.0)
    #expect(xyzImplicit.y == 5.0)
    #expect(xyzImplicit.z == 6.0)

    let xyzExplicit = try UpstreamParity.point("POINT Z (4.0 5.0 6.0)")
    #expect(xyzExplicit.is3D)
    #expect(xyzExplicit.x == 4.0)
    #expect(xyzExplicit.y == 5.0)
    #expect(xyzExplicit.z == 6.0)
}

// MARK: - LineStringTest.cpp

@Test func upstreamLineStringDefaultConstructorAndAccessors() throws {
    // Upstream: LineStringTest.cpp / defaultConstructor, testAccessors
    TestSupport.initializeSFCGALOnce()
    let line = try LineString()
    #expect(line.geometryType == "LineString")
    #expect(line.geometryTypeID == UpstreamParity.lineStringTypeID)
    #expect(line.numPoints == 0)

    try line.addPoint(Point(x: 2.0, y: 3.0))
    try line.addPoint(Point(x: 4.0, y: 5.0))
    #expect(line.numPoints == 2)
    #expect(line.pointAt(0).x == 2.0)
    #expect(line.pointAt(0).y == 3.0)
    #expect(line.pointAt(1).x == 4.0)
    #expect(line.pointAt(1).y == 5.0)
}

@Test func upstreamLineStringCloneAndAsText() throws {
    // Upstream: LineStringTest.cpp / testClone, asText2d, asText3d, testIs3D_false, testIs3D_true
    let line2D = try UpstreamParity.lineString("LINESTRING (0.0 0.0,1.0 1.0)")
    let clone = try #require(line2D.clone() as? LineString)
    #expect(clone.numPoints == 2)
    UpstreamParity.expectWKT(line2D, decimals: 3,
                             equals: "LINESTRING (0.000 0.000,1.000 1.000)",
                             "LineStringTest.cpp / asText2d")

    let line3D = try UpstreamParity.lineString("LINESTRING (0.0 0.0 0.0,1.0 1.0 1.0)")
    #expect(line3D.pointAt(0).is3D)
    #expect(line3D.pointAt(1).is3D)
    UpstreamParity.expectWKT(line3D, decimals: 3,
                             equals: "LINESTRING Z (0.000 0.000 0.000,1.000 1.000 1.000)",
                             "LineStringTest.cpp / asText3d")
}

@Test func upstreamLineStringTypeMetadata() throws {
    // Upstream: LineStringTest.cpp / testGeometryType, testGeometryTypeId
    TestSupport.initializeSFCGALOnce()
    let line = try LineString()
    #expect(line.geometryType == "LineString")
    #expect(line.geometryTypeID == UpstreamParity.lineStringTypeID)
}

// MARK: - PolygonTest.cpp

@Test func upstreamPolygonDefaultConstructor() throws {
    // Upstream: PolygonTest.cpp / defaultConstructor
    TestSupport.initializeSFCGALOnce()
    let polygon = try Polygon()
    #expect(polygon.geometryType == "Polygon")
    #expect(polygon.geometryTypeID == UpstreamParity.polygonTypeID)
    #expect(polygon.numInteriorRings == 0)
}

@Test func upstreamPolygonExteriorRingConstructor2DAnd3D() throws {
    // Upstream: PolygonTest.cpp / exteriorRingConstructor, exteriorRingConstructor3D
    TestSupport.initializeSFCGALOnce()
    let ring2D = try LineString()
    for (x, y) in [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0), (0.0, 0.0)] {
        try ring2D.addPoint(Point(x: x, y: y))
    }
    let polygon2D = try Polygon(exteriorRing: ring2D)
    #expect(polygon2D.exteriorRing.numPoints == 5)
    #expect(polygon2D.numInteriorRings == 0)
    #expect(!polygon2D.exteriorRing.pointAt(0).is3D)

    let polygon3D = try UpstreamParity.polygon(
        "POLYGON Z ((0.0 0.0 2.0,1.0 0.0 2.0,1.0 1.0 2.0,0.0 1.0 2.0,0.0 0.0 2.0))"
    )
    #expect(polygon3D.exteriorRing.numPoints == 5)
    #expect(polygon3D.exteriorRing.pointAt(0).is3D)
    #expect(polygon3D.numInteriorRings == 0)
}

@Test func upstreamPolygonCloneAndAsText() throws {
    // Upstream: PolygonTest.cpp / testClone, asText2d, asText3d
    let polygon2D = try UpstreamParity.polygon(
        "POLYGON ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0))"
    )
    let clone = try #require(polygon2D.clone() as? Polygon)
    #expect(clone.exteriorRing.numPoints == 5)
    #expect(clone.numInteriorRings == 0)
    UpstreamParity.expectWKT(polygon2D, decimals: 1,
                             equals: "POLYGON ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0))",
                             "PolygonTest.cpp / asText2d")

    let polygon3D = try UpstreamParity.polygon(
        "POLYGON Z ((0.0 0.0 2.0,1.0 0.0 2.0,1.0 1.0 2.0,0.0 1.0 2.0,0.0 0.0 2.0))"
    )
    UpstreamParity.expectWKT(polygon3D, decimals: 1,
                             equals: "POLYGON Z ((0.0 0.0 2.0,1.0 0.0 2.0,1.0 1.0 2.0,0.0 1.0 2.0,0.0 0.0 2.0))",
                             "PolygonTest.cpp / asText3d")
}

@Test func upstreamPolygonInteriorRingAccessors() throws {
    // Upstream: PolygonTest.cpp / interior ring accessors covered through public addInteriorRing
    TestSupport.initializeSFCGALOnce()
    let exterior = try UpstreamParity.lineString("LINESTRING (0 0,5 0,5 5,0 5,0 0)")
    let hole = try UpstreamParity.lineString("LINESTRING (1 1,2 1,2 2,1 2,1 1)")
    let polygon = try Polygon(exteriorRing: exterior)
    try polygon.addInteriorRing(hole)
    #expect(polygon.exteriorRing.numPoints == 5)
    #expect(polygon.numInteriorRings == 1)
    #expect(polygon.interiorRingAt(0).numPoints == 5)
}

@Test func upstreamPolygonTypeMetadata() throws {
    // Upstream: PolygonTest.cpp / testGeometryType, testGeometryTypeId
    TestSupport.initializeSFCGALOnce()
    let polygon = try Polygon()
    #expect(polygon.geometryType == "Polygon")
    #expect(polygon.geometryTypeID == UpstreamParity.polygonTypeID)
}

// MARK: - TriangleTest.cpp

@Test func upstreamTriangleConstructorsAndAccessors() throws {
    // Upstream: TriangleTest.cpp / testDefaultConstructor, testConstructorTriangle_2, testConstructorTriangle_3
    TestSupport.initializeSFCGALOnce()
    let empty = try Triangle()
    #expect(empty.geometryType == "Triangle")
    #expect(empty.geometryTypeID == UpstreamParity.triangleTypeID)

    let triangle2D = try Triangle(a: Point(x: 0.0, y: 0.0),
                                  b: Point(x: 1.0, y: 0.0),
                                  c: Point(x: 1.0, y: 1.0))
    #expect(!triangle2D.vertexA.is3D)
    #expect(triangle2D.vertexB.x == 1.0)
    #expect(triangle2D.vertexC.y == 1.0)

    let triangle3D = try Triangle(a: Point(x: 0.0, y: 0.0, z: 6.0),
                                  b: Point(x: 1.0, y: 0.0, z: 6.0),
                                  c: Point(x: 1.0, y: 1.0, z: 6.0))
    #expect(triangle3D.vertexA.is3D)
    #expect(triangle3D.vertexA.z == 6.0)
}

@Test func upstreamTriangleCloneAsTextAndTypeMetadata() throws {
    // Upstream: TriangleTest.cpp / testClone, asText2d, asText3d, testGeometryType, testGeometryTypeId
    let triangle2D = try UpstreamParity.triangle("TRIANGLE ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 0.0))")
    let clone = try #require(triangle2D.clone() as? Triangle)
    #expect(clone.vertexA.x == 0.0)
    #expect(clone.vertexB.x == 1.0)
    UpstreamParity.expectWKT(triangle2D, decimals: 3,
                             equals: "TRIANGLE ((0.000 0.000,1.000 0.000,1.000 1.000,0.000 0.000))",
                             "TriangleTest.cpp / asText2d")

    let triangle3D = try UpstreamParity.triangle(
        "TRIANGLE Z ((0.0 0.0 6.0,1.0 0.0 6.0,1.0 1.0 6.0,0.0 0.0 6.0))"
    )
    UpstreamParity.expectWKT(triangle3D, decimals: 3,
                             equals: "TRIANGLE Z ((0.000 0.000 6.000,1.000 0.000 6.000,1.000 1.000 6.000,0.000 0.000 6.000))",
                             "TriangleTest.cpp / asText3d")
    #expect(triangle3D.geometryType == "Triangle")
    #expect(triangle3D.geometryTypeID == UpstreamParity.triangleTypeID)
}
