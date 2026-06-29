import Testing
@testable import SwiftSFCGAL

@Test func upstreamConvexHull2DCases() throws {
    // Upstream: algorithm/ConvexHullTest.cpp / testConvexHull2D_Empty
    let empty = try emptyPolygonCollection().convexHull()
    UpstreamParity.expectEmptyWKT(empty,
                                  equals: "GEOMETRYCOLLECTION EMPTY",
                                  "ConvexHullTest.cpp / testConvexHull2D_Empty")

    // Upstream: algorithm/ConvexHullTest.cpp / testConvexHull2D_ColinearProduceLineString
    let collinear = try UpstreamParity.geometry("LINESTRING (0 0,1 1,2 2)").convexHull()
    #expect(collinear.geometryTypeID == UpstreamParity.lineStringTypeID)
    #expect((collinear as? LineString)?.numPoints == 2)
    let collinearWKT = collinear.asWKT(decimals: 1)
    #expect(collinearWKT == "LINESTRING (0.0 0.0,2.0 2.0)" ||
            collinearWKT == "LINESTRING (2.0 2.0,0.0 0.0)",
            "ConvexHullTest.cpp / testConvexHull2D_ColinearProduceLineString")

    // Upstream: algorithm/ConvexHullTest.cpp / testConvexHull2D_Triangle
    let triangle = try UpstreamParity.geometry("LINESTRING (0 0,0.5 0.5,1 0,0 1)").convexHull()
    #expect(triangle.geometryTypeID == UpstreamParity.triangleTypeID)

    // Upstream: algorithm/ConvexHullTest.cpp / testConvexHull2D_Polygon
    let polygon = try UpstreamParity.geometry("LINESTRING (0 0,1 0,1 1,0 1)").convexHull()
    #expect(polygon.geometryTypeID == UpstreamParity.polygonTypeID)
}

@Test func upstreamConvexHull3DCases() throws {
    // Upstream: algorithm/ConvexHullTest.cpp / testConvexHull3D_Empty
    let empty = try emptyPolygonCollection().convexHull3D()
    UpstreamParity.expectEmptyWKT(empty,
                                  equals: "GEOMETRYCOLLECTION EMPTY",
                                  "ConvexHullTest.cpp / testConvexHull3D_Empty")

    // Upstream: algorithm/ConvexHullTest.cpp / testConvexHull3D_Point
    let point = try #require(UpstreamParity.geometry("POINT Z (1 2 3)").convexHull3D() as? Point)
    #expect(point.x == 1.0)
    #expect(point.y == 2.0)
    #expect(point.z == 3.0)

    // Upstream: algorithm/ConvexHullTest.cpp / testConvexHull3D_LineStringCollinear
    let line = try UpstreamParity.geometry("LINESTRING Z (0 0 0,1 1 1,2 2 2,3 3 3)").convexHull3D()
    #expect(line.geometryTypeID == UpstreamParity.lineStringTypeID)

    // Upstream: algorithm/ConvexHullTest.cpp / testConvexHull3D_LineStringCoplanar
    let coplanar = try #require(UpstreamParity.geometry(
        "LINESTRING Z (0 0 1,1 0 1,1 1 1,0 1 1)"
    ).convexHull3D() as? PolyhedralSurface)
    #expect(coplanar.numPatches == 2)

    // Upstream: algorithm/ConvexHullTest.cpp / testConvexHull3D_Tetrahedron
    let tetrahedron = try #require(UpstreamParity.geometry(
        "LINESTRING Z (0 0 0,1 0 0,0 1 0,0 0 1)"
    ).convexHull3D() as? PolyhedralSurface)
    #expect(tetrahedron.numPatches == 4)
}

#if !os(Windows)
@Test func upstreamAlphaShapes2DCases() throws {
    // Upstream: algorithm/AlphaShapesTest.cpp / testAlphaShapes2D_ComputeAlpha
    let computed = try UpstreamParity.geometry("LINESTRING (0 0,1 0,1 1,0 1)")
        .optimalAlphaShapes(allowHoles: false, components: 3)
    #expect(!computed.asWKT(decimals: 1).isEmpty)

    // Upstream: algorithm/AlphaShapesTest.cpp / testAlphaShapes2D_Empty
    let empty = try emptyPolygonCollection().alphaShapes()
    UpstreamParity.expectEmptyWKT(empty,
                                  equals: "GEOMETRYCOLLECTION EMPTY",
                                  "AlphaShapesTest.cpp / testAlphaShapes2D_Empty")

    // Upstream: algorithm/AlphaShapesTest.cpp / testAlphaShapes2D_ColinearProduceEmpty
    let collinear = try UpstreamParity.geometry("LINESTRING (0 0,1 1,2 2)").alphaShapes()
    UpstreamParity.expectEmptyWKT(collinear,
                                  equals: "GEOMETRYCOLLECTION EMPTY",
                                  "AlphaShapesTest.cpp / testAlphaShapes2D_ColinearProduceEmpty")

    // Upstream: algorithm/AlphaShapesTest.cpp / testAlphaShapes2D_Triangle
    let triangle = try UpstreamParity.geometry("LINESTRING (0 0,0.5 0.5,1 0,0 1)")
        .alphaShapes()
    #expect(triangle.geometryTypeID == UpstreamParity.polygonTypeID)
    UpstreamParity.expectWKT(triangle, decimals: 1,
                             equals: "POLYGON ((0.0 0.0,0.0 1.0,0.5 0.5,1.0 0.0,0.0 0.0))",
                             "AlphaShapesTest.cpp / testAlphaShapes2D_Triangle")

    // Upstream: algorithm/AlphaShapesTest.cpp / testAlphaShapes2D_Polygon
    let polygon = try UpstreamParity.geometry("LINESTRING (0 0,1 0,1 1,0 1)")
        .alphaShapes()
    #expect(polygon.geometryTypeID == UpstreamParity.polygonTypeID)
    UpstreamParity.expectWKT(polygon, decimals: 1,
                             equals: "POLYGON ((0.0 0.0,0.0 1.0,1.0 1.0,1.0 0.0,0.0 0.0))",
                             "AlphaShapesTest.cpp / testAlphaShapes2D_Polygon")

    // Compact alpha-shapes smoke coverage. Full upstream fixture parity is in
    // upstreamAlphaShapes2DMultiPointFixtureCases.
    let multiPoint = try UpstreamParity.geometry("MULTIPOINT ((0 0),(1 0),(1 1),(0 1),(0.5 0.5))")
    let alpha = try multiPoint.alphaShapes(alpha: 1000.0)
    #expect(alpha.geometryTypeID == UpstreamParity.polygonTypeID ||
            alpha.geometryTypeID == UpstreamParity.multiPolygonTypeID)
    let optimal = try multiPoint.optimalAlphaShapes()
    #expect(optimal.geometryTypeID == UpstreamParity.polygonTypeID ||
            optimal.geometryTypeID == UpstreamParity.multiPolygonTypeID)
    let optimalHoles = try multiPoint.optimalAlphaShapes(allowHoles: true)
    #expect(optimalHoles.geometryTypeID == UpstreamParity.polygonTypeID ||
            optimalHoles.geometryTypeID == UpstreamParity.multiPolygonTypeID)

    // Upstream: algorithm/AlphaShapesTest.cpp / testAlphaShapes2D_InvalidPolygon_Issue254
    #expect(throws: SFCGALError.self) {
        _ = try UpstreamParity.geometry("LINESTRING (1 2,1 2,1 2,1 2)")
            .alphaShapes(alpha: 20.1, allowHoles: false)
    }
}
#endif

@Test func upstreamAlphaWrapping3DCases() throws {
    // Upstream: algorithm/AlphaWrapping3DTest.cpp / testAlphaWrapping3D_Empty
    let empty = try emptyPolygonCollection().alphaWrapping3D(relativeAlpha: 300, relativeOffset: 5000)
    UpstreamParity.expectEmptyWKT(empty,
                                  equals: "POLYHEDRALSURFACE EMPTY",
                                  "AlphaWrapping3DTest.cpp / testAlphaWrapping3D_Empty")

    // Compact alpha-wrapping smoke coverage; full fixture parity is tested separately.
    let wrapped = try UpstreamParity.geometry(
        "MULTIPOINT Z ((0 0 0),(1 0 0),(0 1 0),(0 0 1),(1 1 1))"
    ).alphaWrapping3D(relativeAlpha: 20, relativeOffset: 600)
    #expect(wrapped.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID ||
            wrapped.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
    #expect(!wrapped.asWKT().isEmpty)
}

@Test func upstreamApproximateMedialAxisCases() throws {
    // Upstream: algorithm/ApproximateMedialAxis.cpp / testTriangle45
    let triangle45 = try UpstreamParity.geometry("TRIANGLE ((1 1,2 1,2 2,1 1))")
        .approximateMedialAxis()
    UpstreamParity.expectWKT(triangle45, decimals: 1,
                             equals: "MULTILINESTRING ((1.0 1.0,1.7 1.3),(2.0 2.0,1.7 1.3))",
                             "ApproximateMedialAxis.cpp / testTriangle45")

    // Upstream: algorithm/ApproximateMedialAxis.cpp / testTriangle60
    let triangle60 = try #require(UpstreamParity.geometry("TRIANGLE ((1 1,3 1,2 3,1 1))")
        .approximateMedialAxis() as? MultiLineString)
    #expect(triangle60.numGeometries == 0)
    UpstreamParity.expectEmptyWKT(triangle60,
                                  equals: "MULTILINESTRING EMPTY",
                                  "ApproximateMedialAxis.cpp / testTriangle60")

    // Upstream: algorithm/ApproximateMedialAxis.cpp / testPolygon
    let polygon = try #require(UpstreamParity.geometry("POLYGON ((0 0,20 0,20 10,0 10,0 0))")
        .approximateMedialAxis() as? MultiLineString)
    #expect(polygon.numGeometries == 1)
    UpstreamParity.expectWKT(polygon, decimals: 0,
                             equals: "MULTILINESTRING ((5 5,15 5))",
                             "ApproximateMedialAxis.cpp / testPolygon")

    // Upstream: algorithm/ApproximateMedialAxis.cpp / testPolygonWithHole
    let polygonWithHole = try #require(UpstreamParity.geometry(
        "POLYGON ((0 0,10 0,10 10,0 10,0 0),(4 4,4 6,6 6,6 4,4 4))"
    ).approximateMedialAxis() as? MultiLineString)
    #expect(polygonWithHole.numGeometries == 4)
    let expected = try UpstreamParity.geometry(
        "MULTILINESTRING ((2 2,8 2),(2 2,2 8),(8 2,8 8),(2 8,8 8))"
    )
    #expect(try polygonWithHole.covers(expected),
            "ApproximateMedialAxis.cpp / testPolygonWithHole")

    // Upstream: algorithm/ApproximateMedialAxis.cpp / testPolygonWithTouchingHoles
    #expect(throws: SFCGALError.self) {
        _ = try UpstreamParity.geometry(
            "POLYGON ((-1.0 -1.0,1.0 -1.0,1.0 1.0,-1.0 1.0,-1.0 -1.0),(-0.5 -0.5,-0.5 0.5,-0.1 0.5,0.1 -0.5,-0.5 -0.5),(0.1 -0.5,0.1 0.5,0.5 0.5,0.5 -0.5,0.1 -0.5))"
        ).approximateMedialAxis()
    }

    // Upstream: algorithm/ApproximateMedialAxis.cpp / testMultiPolygon
    let multiPolygon = try #require(UpstreamParity.geometry(upstreamMedialAxisMultiPolygonWKT)
        .approximateMedialAxis() as? MultiLineString)
    #expect(multiPolygon.numGeometries == 108)

    // Upstream: algorithm/ApproximateMedialAxis.cpp / testInvalidTypes
    for wkt in ["POINT (1 2)", "LINESTRING (0 0,1 1)"] {
        let result = try #require(UpstreamParity.geometry(wkt).approximateMedialAxis() as? MultiLineString)
        #expect(result.numGeometries == 0)
    }
}

@Test func upstreamPartition2Cases() throws {
    // Upstream: algorithm/Partition_2.cpp / testPartition2_NoPolygon
    let noPolygon = try UpstreamParity.geometry("LINESTRING (0 0,2 0,2 2,1 1,0 2)")
        .yMonotonePartition()
    UpstreamParity.expectEmptyWKT(noPolygon,
                                  equals: "GEOMETRYCOLLECTION EMPTY",
                                  "Partition_2.cpp / testPartition2_NoPolygon")

    // Upstream: algorithm/Partition_2.cpp / testPartition2_Empty
    let empty = try Polygon().yMonotonePartition()
    UpstreamParity.expectEmptyWKT(empty,
                                  equals: "GEOMETRYCOLLECTION EMPTY",
                                  "Partition_2.cpp / testPartition2_Empty")

    // Upstream: algorithm/Partition_2.cpp / testPartition2_YMonotonePartition2
    let simple = try UpstreamParity.geometry("POLYGON ((0 0,2 0,2 2,1 1,0 2,0 0))")
        .yMonotonePartition()
    UpstreamParity.expectWKT(simple, decimals: 1,
                             equals: "GEOMETRYCOLLECTION (POLYGON ((2.0 0.0,2.0 2.0,1.0 1.0,2.0 0.0)),POLYGON ((0.0 0.0,2.0 0.0,1.0 1.0,0.0 2.0,0.0 0.0)))",
                             "Partition_2.cpp / testPartition2_YMonotonePartition2")

    let gross = try UpstreamParity.geometry(upstreamPartitionGrossWKT)

    // Upstream: algorithm/Partition_2.cpp / testPartition2_YMonotonePartition2_gross
    UpstreamParity.expectWKT(try gross.yMonotonePartition(), decimals: 1,
                             equals: upstreamYMonotoneGrossExpectedWKT,
                             "Partition_2.cpp / testPartition2_YMonotonePartition2_gross")

    // Upstream: algorithm/Partition_2.cpp / testPartition2_ApproxConvexPartition2_gross
    UpstreamParity.expectWKT(try gross.approximateConvexPartition(), decimals: 1,
                             equals: upstreamApproxConvexGrossExpectedWKT,
                             "Partition_2.cpp / testPartition2_ApproxConvexPartition2_gross")

    // Upstream: algorithm/Partition_2.cpp / testPartition2_GreeneApproxConvexPartition2_gross
    UpstreamParity.expectWKT(try gross.greeneConvexPartition(), decimals: 1,
                             equals: upstreamGreeneGrossExpectedWKT,
                             "Partition_2.cpp / testPartition2_GreeneApproxConvexPartition2_gross")

    // Upstream: algorithm/Partition_2.cpp / testPartition2_OptimalConvexPartition2_gross
    UpstreamParity.expectWKT(try gross.optimalConvexPartition(), decimals: 1,
                             equals: upstreamOptimalGrossExpectedWKT,
                             "Partition_2.cpp / testPartition2_OptimalConvexPartition2_gross")
}

private func emptyPolygonCollection() throws -> GeometryCollection {
    let collection = try GeometryCollection()
    try collection.addGeometry(Polygon())
    try collection.addGeometry(Polygon())
    return collection
}

private let upstreamPartitionGrossWKT =
    "POLYGON ((391 374,240 431,252 340,374 320,289 214,134 390,68 186,154 259,161 107,435 108,208 148,295 160,421 212,441 303,391 374))"

private let upstreamYMonotoneGrossExpectedWKT = [
    "GEOMETRYCOLLECTION (POLYGON ((134.0 390.0,68.0 186.0,154.0 259.0,134.0 390.0)),",
    "POLYGON ((289.0 214.0,134.0 390.0,154.0 259.0,161.0 107.0,435.0 108.0,208.0 148.0,295.0 160.0,421.0 212.0,289.0 214.0)),",
    "POLYGON ((391.0 374.0,240.0 431.0,252.0 340.0,374.0 320.0,289.0 214.0,421.0 212.0,441.0 303.0,391.0 374.0)))"
].joined()

private let upstreamApproxConvexGrossExpectedWKT = [
    "GEOMETRYCOLLECTION (POLYGON ((391.0 374.0,240.0 431.0,252.0 340.0,374.0 320.0,391.0 374.0)),",
    "POLYGON ((134.0 390.0,68.0 186.0,154.0 259.0,134.0 390.0)),",
    "POLYGON ((289.0 214.0,134.0 390.0,154.0 259.0,289.0 214.0)),",
    "POLYGON ((161.0 107.0,435.0 108.0,208.0 148.0,161.0 107.0)),",
    "POLYGON ((154.0 259.0,161.0 107.0,208.0 148.0,154.0 259.0)),",
    "POLYGON ((289.0 214.0,154.0 259.0,208.0 148.0,295.0 160.0,289.0 214.0)),",
    "POLYGON ((374.0 320.0,289.0 214.0,295.0 160.0,421.0 212.0,374.0 320.0)),",
    "POLYGON ((391.0 374.0,374.0 320.0,421.0 212.0,441.0 303.0,391.0 374.0)))"
].joined()

private let upstreamGreeneGrossExpectedWKT = [
    "GEOMETRYCOLLECTION (POLYGON ((134.0 390.0,68.0 186.0,154.0 259.0,134.0 390.0)),",
    "POLYGON ((161.0 107.0,435.0 108.0,208.0 148.0,161.0 107.0)),",
    "POLYGON ((208.0 148.0,295.0 160.0,421.0 212.0,289.0 214.0,208.0 148.0)),",
    "POLYGON ((154.0 259.0,161.0 107.0,208.0 148.0,154.0 259.0)),",
    "POLYGON ((289.0 214.0,134.0 390.0,154.0 259.0,208.0 148.0,289.0 214.0)),",
    "POLYGON ((374.0 320.0,289.0 214.0,421.0 212.0,374.0 320.0)),",
    "POLYGON ((374.0 320.0,421.0 212.0,441.0 303.0,391.0 374.0,374.0 320.0)),",
    "POLYGON ((391.0 374.0,240.0 431.0,252.0 340.0,374.0 320.0,391.0 374.0)))"
].joined()

private let upstreamOptimalGrossExpectedWKT = [
    "GEOMETRYCOLLECTION (POLYGON ((391.0 374.0,240.0 431.0,252.0 340.0,374.0 320.0,391.0 374.0)),",
    "POLYGON ((134.0 390.0,68.0 186.0,154.0 259.0,134.0 390.0)),",
    "POLYGON ((161.0 107.0,435.0 108.0,208.0 148.0,161.0 107.0)),",
    "POLYGON ((154.0 259.0,161.0 107.0,208.0 148.0,154.0 259.0)),",
    "POLYGON ((289.0 214.0,134.0 390.0,154.0 259.0,208.0 148.0,295.0 160.0,289.0 214.0)),",
    "POLYGON ((374.0 320.0,289.0 214.0,295.0 160.0,421.0 212.0,441.0 303.0,374.0 320.0)),",
    "POLYGON ((391.0 374.0,374.0 320.0,441.0 303.0,391.0 374.0)))"
].joined()

private let upstreamMedialAxisMultiPolygonWKT = [
    "MULTIPOLYGON (((3.000000 0.000000,2.875000 0.484123,2.750000 0.661438,",
    "2.625000 0.780625,2.500000 0.866025,2.375000 0.927025,2.250000 0.968246,",
    "2.125000 0.992157,2.000000 1.000000,1.875000 1.484123,1.750000 1.661438,",
    "1.625000 1.780625,1.500000 1.866025,1.375000 1.927025,1.250000 1.968246,",
    "1.125000 1.992157,1.000000 2.000000,0.750000 2.661438,0.500000 2.866025,",
    "0.250000 2.968246,0.000000 3.000000,-0.250000 2.968246,-0.500000 2.866025,",
    "-0.750000 2.661438,-1.000000 2.000000,-1.125000 1.992157,-1.250000 1.968246,",
    "-1.375000 1.927025,-1.500000 1.866025,-1.625000 1.780625,-1.750000 1.661438,",
    "-1.875000 1.484123,-2.000000 1.000000,-2.125000 0.992157,-2.250000 0.968246,",
    "-2.375000 0.927025,-2.500000 0.866025,-2.625000 0.780625,-2.750000 0.661438,",
    "-2.875000 0.484123,-3.000000 0.000000,-2.875000 -0.484123,-2.750000 -0.661438,",
    "-2.625000 -0.780625,-2.500000 -0.866025,-2.375000 -0.927025,-2.250000 -0.968246,",
    "-2.125000 -0.992157,-2.000000 -1.000000,-1.875000 -1.484123,-1.750000 -1.661438,",
    "-1.625000 -1.780625,-1.500000 -1.866025,-1.375000 -1.927025,-1.250000 -1.968246,",
    "-1.125000 -1.992157,-1.000000 -2.000000,-0.750000 -2.661438,-0.500000 -2.866025,",
    "-0.250000 -2.968246,0.000000 -3.000000,0.250000 -2.968246,0.500000 -2.866025,",
    "0.750000 -2.661438,1.000000 -2.000000,1.125000 -1.992157,1.250000 -1.968246,",
    "1.375000 -1.927025,1.500000 -1.866025,1.625000 -1.780625,1.750000 -1.661438,",
    "1.875000 -1.484123,2.000000 -1.000000,2.125000 -0.992157,2.250000 -0.968246,",
    "2.375000 -0.927025,2.500000 -0.866025,2.625000 -0.780625,2.750000 -0.661438,",
    "2.875000 -0.484123,3.000000 0.000000),",
    "(0.000000 1.000000,0.125000 0.515877,0.250000 0.338562,0.375000 0.219375,",
    "0.500000 0.133975,0.625000 0.072975,0.750000 0.031754,0.875000 0.007843,",
    "1.000000 0.000000,0.875000 -0.007843,0.750000 -0.031754,0.625000 -0.072975,",
    "0.500000 -0.133975,0.375000 -0.219375,0.250000 -0.338562,0.125000 -0.515877,",
    "0.000000 -1.000000,-0.125000 -0.515877,-0.250000 -0.338562,-0.375000 -0.219375,",
    "-0.500000 -0.133975,-0.625000 -0.072975,-0.750000 -0.031754,-0.875000 -0.007843,",
    "-1.000000 0.000000,-0.875000 0.007843,-0.750000 0.031754,-0.625000 0.072975,",
    "-0.500000 0.133975,-0.375000 0.219375,-0.250000 0.338562,-0.125000 0.515877,",
    "0.000000 1.000000)))"
].joined()
