import Testing
@testable import SwiftSFCGAL

@Test func upstreamConvexHull2DCases() throws {
    // Upstream: algorithm/ConvexHullTest.cpp / testConvexHull2D_ColinearProduceLineString,
    // testConvexHull2D_Triangle, testConvexHull2D_Polygon
    let collinear = try UpstreamParity.geometry("MULTIPOINT ((0 0),(1 0),(2 0))").convexHull()
    #expect(collinear.geometryTypeID == UpstreamParity.lineStringTypeID)
    UpstreamParity.expectAlmostEqual(try collinear.length(), 2.0, tolerance: 1e-8,
                                     "ConvexHullTest.cpp / testConvexHull2D_ColinearProduceLineString")

    let triangle = try UpstreamParity.geometry("MULTIPOINT ((0 0),(1 0),(0 1))").convexHull()
    #expect(triangle.geometryTypeID == UpstreamParity.polygonTypeID ||
            triangle.geometryTypeID == UpstreamParity.triangleTypeID)
    UpstreamParity.expectAlmostEqual(try triangle.area(), 0.5, tolerance: 1e-8)

    let polygon = try UpstreamParity.geometry("POLYGON ((0 0,2 0,2 2,1 1,0 2,0 0))").convexHull()
    #expect(polygon.geometryTypeID == UpstreamParity.polygonTypeID)
    UpstreamParity.expectAlmostEqual(try polygon.area(), 4.0, tolerance: 1e-8)
}

@Test func upstreamConvexHull3DCases() throws {
    // Upstream: algorithm/ConvexHullTest.cpp / testConvexHull3D_Point,
    // testConvexHull3D_LineStringCollinear, testConvexHull3D_Tetrahedron
    let point = try UpstreamParity.geometry("POINT Z (1 2 3)").convexHull3D()
    #expect(point.geometryTypeID == UpstreamParity.pointTypeID)

    let line = try UpstreamParity.geometry("LINESTRING Z (0 0 0,1 1 1,2 2 2)").convexHull3D()
    #expect(line.geometryTypeID == UpstreamParity.lineStringTypeID)

    let tetrahedron = try UpstreamParity.geometry(
        "MULTIPOINT Z ((0 0 0),(1 0 0),(0 1 0),(0 0 1))"
    ).convexHull3D()
    #expect(tetrahedron.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID ||
            tetrahedron.geometryTypeID == UpstreamParity.solidTypeID)
    #expect(try tetrahedron.area3D() > 0.0)
}

#if !os(Windows)
@Test func upstreamAlphaShapes2DCases() throws {
    // Upstream: algorithm/AlphaShapesTest.cpp / triangle, polygon, multipoint cases.
    let triangle = try UpstreamParity.geometry("LINESTRING (0 0,0.5 0.5,1 0,0 1)")
        .alphaShapes()
    #expect(triangle.geometryTypeID == UpstreamParity.polygonTypeID)
    UpstreamParity.expectWKT(triangle, decimals: 1,
                             equals: "POLYGON ((0.0 0.0,0.0 1.0,0.5 0.5,1.0 0.0,0.0 0.0))",
                             "AlphaShapesTest.cpp / testAlphaShapes2D_Triangle")

    let polygon = try UpstreamParity.geometry("LINESTRING (0 0,1 0,1 1,0 1)")
        .alphaShapes()
    #expect(polygon.geometryTypeID == UpstreamParity.polygonTypeID)
    UpstreamParity.expectWKT(polygon, decimals: 1,
                             equals: "POLYGON ((0.0 0.0,0.0 1.0,1.0 1.0,1.0 0.0,0.0 0.0))",
                             "AlphaShapesTest.cpp / testAlphaShapes2D_Polygon")

    let multiPoint = try UpstreamParity.geometry("MULTIPOINT ((0 0),(1 0),(1 1),(0 1),(0.5 0.5))")
        .optimalAlphaShapes()
    #expect(multiPoint.geometryTypeID == UpstreamParity.polygonTypeID ||
            multiPoint.geometryTypeID == UpstreamParity.multiPolygonTypeID)
}
#endif

@Test func upstreamAlphaWrapping3DCases() throws {
    // Upstream: algorithm/AlphaWrapping3DTest.cpp / testAlphaWrapping3D_MultiPoint
    let wrapped = try UpstreamParity.geometry(
        "MULTIPOINT Z ((0 0 0),(1 0 0),(0 1 0),(0 0 1),(1 1 1))"
    ).alphaWrapping3D(relativeAlpha: 20, relativeOffset: 600)
    #expect(wrapped.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID ||
            wrapped.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
    #expect(!wrapped.asWKT().isEmpty)
}

@Test func upstreamApproximateMedialAxisCases() throws {
    // Upstream: algorithm/ApproximateMedialAxis.cpp / testTriangle45, testTriangle60,
    // testPolygon, testPolygonWithHole, testMultiPolygon, testInvalidTypes
    let triangle45 = try UpstreamParity.geometry("POLYGON ((0 0,4 0,0 4,0 0))")
        .approximateMedialAxis()
    #expect(triangle45.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    #expect((triangle45 as? MultiLineString)?.numGeometries ?? 0 > 0)

    let polygon = try UpstreamParity.geometry("POLYGON ((0 0,4 0,4 2,0 2,0 0))")
        .approximateMedialAxis()
    #expect(polygon.geometryTypeID == UpstreamParity.multiLineStringTypeID)

    let multiPolygon = try UpstreamParity.geometry(
        "MULTIPOLYGON (((0 0,2 0,2 2,0 2,0 0)),((3 0,5 0,5 2,3 2,3 0)))"
    ).approximateMedialAxis()
    #expect(multiPolygon.geometryTypeID == UpstreamParity.multiLineStringTypeID ||
            multiPolygon.geometryTypeID == UpstreamParity.geometryCollectionTypeID)

    let invalidTypeResult = try UpstreamParity.geometry("POINT (0 0)").approximateMedialAxis()
    #expect(invalidTypeResult.asWKT(decimals: 0).contains("EMPTY"))
}

@Test func upstreamPartition2Cases() throws {
    // Upstream: algorithm/Partition_2.cpp / YMonotone, ApproxConvex, Greene, Optimal cases
    let gross = try UpstreamParity.geometry("POLYGON ((0 0,4 0,4 1,1 1,1 4,0 4,0 0))")

    let yMonotone = try gross.yMonotonePartition()
    #expect(yMonotone.geometryTypeID == UpstreamParity.multiPolygonTypeID ||
            yMonotone.geometryTypeID == UpstreamParity.geometryCollectionTypeID)
    UpstreamParity.expectAlmostEqual(try yMonotone.area(), try gross.area(), tolerance: 1e-8)

    let approximate = try gross.approximateConvexPartition()
    #expect(approximate.geometryTypeID == UpstreamParity.multiPolygonTypeID ||
            approximate.geometryTypeID == UpstreamParity.geometryCollectionTypeID)
    UpstreamParity.expectAlmostEqual(try approximate.area(), try gross.area(), tolerance: 1e-8)

    let greene = try gross.greeneConvexPartition()
    UpstreamParity.expectAlmostEqual(try greene.area(), try gross.area(), tolerance: 1e-8)

    let optimal = try gross.optimalConvexPartition()
    UpstreamParity.expectAlmostEqual(try optimal.area(), try gross.area(), tolerance: 1e-8)
}
