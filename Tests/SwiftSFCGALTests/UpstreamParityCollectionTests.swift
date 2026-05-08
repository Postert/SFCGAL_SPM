import Testing
@testable import SwiftSFCGAL

// MARK: - GeometryCollectionTest.cpp

@Test func upstreamGeometryCollectionDefaultAndAccessors() throws {
    // Upstream: GeometryCollectionTest.cpp / defaultConstructor, testAccessors
    TestSupport.initializeSFCGALOnce()
    let collection = try GeometryCollection()
    #expect(collection.geometryType == "GeometryCollection")
    #expect(collection.geometryTypeID == UpstreamParity.geometryCollectionTypeID)
    #expect(collection.numGeometries == 0)

    try collection.addGeometry(Point(x: 2.0, y: 3.0))
    try collection.addGeometry(try UpstreamParity.lineString("LINESTRING (0.0 0.0,1.0 1.0)"))
    try collection.addGeometry(try UpstreamParity.triangle("TRIANGLE ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 0.0))"))

    #expect(collection.numGeometries == 3)
    UpstreamParity.expectWKT(collection.geometryAt(0), decimals: 0,
                             equals: "POINT (2 3)",
                             "GeometryCollectionTest.cpp / testAccessors")
    UpstreamParity.expectWKT(collection.geometryAt(1), decimals: 0,
                             equals: "LINESTRING (0 0,1 1)",
                             "GeometryCollectionTest.cpp / testAccessors")
    UpstreamParity.expectWKT(collection.geometryAt(2), decimals: 0,
                             equals: "TRIANGLE ((0 0,1 0,1 1,0 0))",
                             "GeometryCollectionTest.cpp / testAccessors")
}

@Test func upstreamGeometryCollectionAsText2DAnd3D() throws {
    // Upstream: GeometryCollectionTest.cpp / asText2d, asText3d
    let collection2D = try UpstreamParity.collection(
        "GEOMETRYCOLLECTION (POINT (2.0 3.0),TRIANGLE ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 0.0)))"
    )
    UpstreamParity.expectWKT(collection2D, decimals: 1,
                             equals: "GEOMETRYCOLLECTION (POINT (2.0 3.0),TRIANGLE ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 0.0)))",
                             "GeometryCollectionTest.cpp / asText2d")

    let collection3D = try UpstreamParity.collection(
        "GEOMETRYCOLLECTION Z (POINT Z (2.0 3.0 5.0),TRIANGLE Z ((0.0 0.0 6.0,1.0 0.0 6.0,1.0 1.0 6.0,0.0 0.0 6.0)))"
    )
    UpstreamParity.expectWKT(collection3D, decimals: 1,
                             equals: "GEOMETRYCOLLECTION Z (POINT Z (2.0 3.0 5.0),TRIANGLE Z ((0.0 0.0 6.0,1.0 0.0 6.0,1.0 1.0 6.0,0.0 0.0 6.0)))",
                             "GeometryCollectionTest.cpp / asText3d")
}

@Test func upstreamGeometryCollectionClonePreservesMembers() throws {
    // Upstream: GeometryCollectionTest.cpp / testAccessors, testClone, testGeometryType, testGeometryTypeId
    let collection = try UpstreamParity.collection(
        "GEOMETRYCOLLECTION (POINT (2.0 3.0),LINESTRING (0.0 0.0,1.0 1.0),TRIANGLE ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 0.0)),POLYGON ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 0.0)))"
    )
    let clone = try #require(collection.clone() as? GeometryCollection)

    #expect(clone.geometryType == "GeometryCollection")
    #expect(clone.geometryTypeID == UpstreamParity.geometryCollectionTypeID)
    #expect(clone.numGeometries == 4)
    #expect(clone.geometryAt(0) is Point)
    #expect(clone.geometryAt(1) is LineString)
    #expect(clone.geometryAt(2) is Triangle)
    #expect(clone.geometryAt(3) is Polygon)
    UpstreamParity.expectWKT(clone.geometryAt(0), decimals: 1,
                             equals: "POINT (2.0 3.0)",
                             "GeometryCollectionTest.cpp / testClone")
}

// MARK: - MultiPointTest.cpp

@Test func upstreamMultiPointDefaultTypeAddPointAndAsText() throws {
    // Upstream: MultiPointTest.cpp / defaultConstructor, testGeometryTypeId, addPoint, asText2d
    TestSupport.initializeSFCGALOnce()
    let multiPoint = try MultiPoint()
    #expect(multiPoint.geometryType == "MultiPoint")
    #expect(multiPoint.geometryTypeID == UpstreamParity.multiPointTypeID)
    #expect(multiPoint.numGeometries == 0)

    try multiPoint.addGeometry(Point(x: 2.0, y: 3.0))
    try multiPoint.addGeometry(Point(x: 4.0, y: 5.0))
    #expect(multiPoint.numGeometries == 2)
    #expect(multiPoint.pointAt(0).x == 2.0)
    #expect(multiPoint.pointAt(1).y == 5.0)
    UpstreamParity.expectWKT(multiPoint, decimals: 1,
                             equals: "MULTIPOINT ((2.0 3.0),(4.0 5.0))",
                             "MultiPointTest.cpp / asText2d")
}

@Test func upstreamMultiPointEmptyCloneAndTypedAccessors() throws {
    // Upstream: MultiPointTest.cpp / asTextEmpty, addPoint, isGeometryCollection, isMultiPoint
    let empty = try #require(UpstreamParity.geometry("MULTIPOINT EMPTY") as? MultiPoint)
    let baseEmpty: Geometry = empty
    #expect(baseEmpty is GeometryCollection)
    #expect(empty.geometryTypeID == UpstreamParity.multiPointTypeID)
    UpstreamParity.expectEmptyWKT(empty,
                                  equals: "MULTIPOINT EMPTY",
                                  "MultiPointTest.cpp / asTextEmpty")

    let multiPoint = try #require(UpstreamParity.geometry("MULTIPOINT ((2.0 3.0),(3.0 4.0))") as? MultiPoint)
    #expect(multiPoint.numGeometries == 2)
    #expect(multiPoint.pointAt(0).x == 2.0)
    #expect(multiPoint.pointAt(1).y == 4.0)

    let clone = try #require(multiPoint.clone() as? MultiPoint)
    #expect(clone.numGeometries == 2)
    UpstreamParity.expectWKT(clone, decimals: 1,
                             equals: "MULTIPOINT ((2.0 3.0),(3.0 4.0))",
                             "MultiPointTest.cpp / addPoint")
}

// MARK: - MultiLineStringTest.cpp

@Test func upstreamMultiLineStringDefaultAddLineStringAndAsText() throws {
    // Upstream: MultiLineStringTest.cpp / defaultConstructor, addLineString, asText2d
    TestSupport.initializeSFCGALOnce()
    let multiLineString = try MultiLineString()
    #expect(multiLineString.geometryType == "MultiLineString")
    #expect(multiLineString.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    #expect(multiLineString.numGeometries == 0)

    try multiLineString.addGeometry(try UpstreamParity.lineString("LINESTRING (0.0 0.0,1.0 1.0)"))
    try multiLineString.addGeometry(try UpstreamParity.lineString("LINESTRING (1.0 1.0,2.0 2.0)"))
    #expect(multiLineString.numGeometries == 2)
    #expect(multiLineString.lineStringAt(0).numPoints == 2)
    UpstreamParity.expectWKT(multiLineString, decimals: 1,
                             equals: "MULTILINESTRING ((0.0 0.0,1.0 1.0),(1.0 1.0,2.0 2.0))",
                             "MultiLineStringTest.cpp / asText2d")
}

@Test func upstreamMultiLineStringEmptyCloneAndTypedAccessors() throws {
    // Upstream: MultiLineStringTest.cpp / asTextEmpty, addLineString, isMultiLineString
    let empty = try #require(UpstreamParity.geometry("MULTILINESTRING EMPTY") as? MultiLineString)
    let baseEmpty: Geometry = empty
    #expect(baseEmpty is GeometryCollection)
    #expect(empty.geometryTypeID == UpstreamParity.multiLineStringTypeID)
    UpstreamParity.expectEmptyWKT(empty,
                                  equals: "MULTILINESTRING EMPTY",
                                  "MultiLineStringTest.cpp / asTextEmpty")

    let multiLineString = try #require(UpstreamParity.geometry(
        "MULTILINESTRING ((0.0 0.0,1.0 1.0),(1.0 1.0,2.0 2.0))"
    ) as? MultiLineString)
    #expect(multiLineString.numGeometries == 2)
    #expect(multiLineString.lineStringAt(0).numPoints == 2)
    #expect(multiLineString.lineStringAt(1).pointAt(1).x == 2.0)

    let clone = try #require(multiLineString.clone() as? MultiLineString)
    #expect(clone.numGeometries == 2)
    UpstreamParity.expectWKT(clone, decimals: 1,
                             equals: "MULTILINESTRING ((0.0 0.0,1.0 1.0),(1.0 1.0,2.0 2.0))",
                             "MultiLineStringTest.cpp / addLineString")
}

// MARK: - MultiPolygonTest.cpp

@Test func upstreamMultiPolygonDefaultTypeAddPolygonAndAsText() throws {
    // Upstream: MultiPolygonTest.cpp / defaultConstructor, testGeometryTypeId, addPolygon, asText2d
    TestSupport.initializeSFCGALOnce()
    let multiPolygon = try MultiPolygon()
    #expect(multiPolygon.geometryType == "MultiPolygon")
    #expect(multiPolygon.geometryTypeID == UpstreamParity.multiPolygonTypeID)
    #expect(multiPolygon.numGeometries == 0)

    try multiPolygon.addGeometry(try UpstreamParity.polygon("POLYGON ((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0))"))
    try multiPolygon.addGeometry(try UpstreamParity.polygon("POLYGON ((2.0 0.0,3.0 0.0,3.0 1.0,2.0 1.0,2.0 0.0))"))
    #expect(multiPolygon.numGeometries == 2)
    #expect(multiPolygon.polygonAt(0).exteriorRing.numPoints == 5)
    UpstreamParity.expectWKT(multiPolygon, decimals: 1,
                             equals: "MULTIPOLYGON (((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0)),((2.0 0.0,3.0 0.0,3.0 1.0,2.0 1.0,2.0 0.0)))",
                             "MultiPolygonTest.cpp / asText2d")
}

@Test func upstreamMultiPolygonEmptyCloneAndTypedAccessors() throws {
    // Upstream: MultiPolygonTest.cpp / asTextEmpty, addPolygon, isMultiPolygon
    let empty = try #require(UpstreamParity.geometry("MULTIPOLYGON EMPTY") as? MultiPolygon)
    let baseEmpty: Geometry = empty
    #expect(baseEmpty is GeometryCollection)
    #expect(empty.geometryTypeID == UpstreamParity.multiPolygonTypeID)
    UpstreamParity.expectEmptyWKT(empty,
                                  equals: "MULTIPOLYGON EMPTY",
                                  "MultiPolygonTest.cpp / asTextEmpty")

    let multiPolygon = try #require(UpstreamParity.geometry(
        "MULTIPOLYGON (((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0)),((2.0 0.0,3.0 0.0,3.0 1.0,2.0 1.0,2.0 0.0)))"
    ) as? MultiPolygon)
    #expect(multiPolygon.numGeometries == 2)
    #expect(multiPolygon.polygonAt(0).exteriorRing.numPoints == 5)
    #expect(multiPolygon.polygonAt(1).exteriorRing.pointAt(0).x == 2.0)

    let clone = try #require(multiPolygon.clone() as? MultiPolygon)
    #expect(clone.numGeometries == 2)
    UpstreamParity.expectWKT(clone, decimals: 1,
                             equals: "MULTIPOLYGON (((0.0 0.0,1.0 0.0,1.0 1.0,0.0 1.0,0.0 0.0)),((2.0 0.0,3.0 0.0,3.0 1.0,2.0 1.0,2.0 0.0)))",
                             "MultiPolygonTest.cpp / addPolygon")
}

// MARK: - MultiSolidTest.cpp

@Test func upstreamMultiSolidDefaultTypeAddSolidAndAsText() throws {
    // Upstream: MultiSolidTest.cpp / defaultConstructor, testGeometryTypeId, addSolid, asText2d
    TestSupport.initializeSFCGALOnce()
    let multiSolid = try MultiSolid()
    #expect(multiSolid.geometryType == "MultiSolid")
    #expect(multiSolid.geometryTypeID == UpstreamParity.multiSolidTypeID)
    #expect(multiSolid.numGeometries == 0)

    let solid = try UpstreamParity.geometry(UpstreamParity.squareShellWKT())
    try multiSolid.addGeometry(solid)
    #expect(multiSolid.numGeometries == 1)
    #expect(multiSolid.geometryAt(0) is Solid)
    #expect(multiSolid.asWKT(decimals: 1).contains("MULTISOLID"))
}

@Test func upstreamMultiSolidEmptyMultipleSolidsAndClone() throws {
    // Upstream: MultiSolidTest.cpp / asTextEmpty, addSolid, isMultiSolid
    let empty = try #require(UpstreamParity.geometry("MULTISOLID EMPTY") as? MultiSolid)
    let baseEmpty: Geometry = empty
    #expect(baseEmpty is GeometryCollection)
    #expect(empty.geometryTypeID == UpstreamParity.multiSolidTypeID)
    UpstreamParity.expectEmptyWKT(empty,
                                  equals: "MULTISOLID EMPTY",
                                  "MultiSolidTest.cpp / asTextEmpty")

    let multiSolid = try MultiSolid()
    try multiSolid.addGeometry(try UpstreamParity.geometry(UpstreamParity.squareShellWKT(min: 0.0, max: 1.0)))
    try multiSolid.addGeometry(try UpstreamParity.geometry(UpstreamParity.squareShellWKT(min: 2.0, max: 3.0)))
    #expect(multiSolid.numGeometries == 2)
    #expect(multiSolid.geometryAt(0) is Solid)
    #expect(multiSolid.geometryAt(1) is Solid)

    let clone = try #require(multiSolid.clone() as? MultiSolid)
    #expect(clone.numGeometries == 2)
    #expect(clone.asWKT(decimals: 1).contains("MULTISOLID Z"))
}

// MARK: - PolyhedralSurfaceTest.cpp / TriangulatedSurfaceTest.cpp / SolidTest.cpp

@Test func upstreamPolyhedralSurfacePatchAccessAndAddition() throws {
    // Upstream: PolyhedralSurfaceTest.cpp / patch access/addition subset
    TestSupport.initializeSFCGALOnce()
    let surface = try PolyhedralSurface()
    #expect(surface.geometryType == "PolyhedralSurface")
    #expect(surface.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID)
    #expect(surface.numPatches == 0)

    let patch = try UpstreamParity.polygon("POLYGON Z ((0 0 0,1 0 0,1 1 0,0 1 0,0 0 0))")
    try surface.addPatch(patch)
    #expect(surface.numPatches == 1)
    #expect(surface.patchAt(0).exteriorRing.numPoints == 5)
}

@Test func upstreamPolyhedralSurfaceEmptyParseMultiplePatchesAndClone() throws {
    // Upstream: PolyhedralSurfaceTest.cpp / setPatchNTest subset before replacement mutators
    let empty = try #require(UpstreamParity.geometry("POLYHEDRALSURFACE EMPTY") as? PolyhedralSurface)
    #expect(empty.geometryType == "PolyhedralSurface")
    #expect(empty.geometryTypeID == UpstreamParity.polyhedralSurfaceTypeID)
    #expect(empty.numPatches == 0)
    UpstreamParity.expectEmptyWKT(empty,
                                  equals: "POLYHEDRALSURFACE EMPTY",
                                  "PolyhedralSurfaceTest.cpp / setPatchNTest empty")

    let surface = try #require(UpstreamParity.geometry(
        "POLYHEDRALSURFACE Z (((0 0 0,10 0 0,10 10 0,0 10 0,0 0 0)),((0 0 0,10 0 0,5 0 5,0 0 0)),((0 0 0,0 10 0,5 5 5,0 0 0)))"
    ) as? PolyhedralSurface)
    #expect(surface.numPatches == 3)
    UpstreamParity.expectWKT(surface.patchAt(0), decimals: 0,
                             equals: "POLYGON Z ((0 0 0,10 0 0,10 10 0,0 10 0,0 0 0))",
                             "PolyhedralSurfaceTest.cpp / patchN(0)")
    UpstreamParity.expectWKT(surface.patchAt(1), decimals: 0,
                             equals: "POLYGON Z ((0 0 0,10 0 0,5 0 5,0 0 0))",
                             "PolyhedralSurfaceTest.cpp / patchN(1)")
    UpstreamParity.expectWKT(surface.patchAt(2), decimals: 0,
                             equals: "POLYGON Z ((0 0 0,0 10 0,5 5 5,0 0 0))",
                             "PolyhedralSurfaceTest.cpp / patchN(2)")

    let clone = try #require(surface.clone() as? PolyhedralSurface)
    #expect(clone.numPatches == 3)
    UpstreamParity.expectWKT(clone.patchAt(0), decimals: 0,
                             equals: "POLYGON Z ((0 0 0,10 0 0,10 10 0,0 10 0,0 0 0))",
                             "PolyhedralSurfaceTest.cpp / clone")
}

@Test func upstreamTriangulatedSurfaceConstructorWithTrianglesAndClone() throws {
    // Upstream: TriangulatedSurfaceTest.cpp / defaultConstructor, constructorWithTriangles, testClone
    TestSupport.initializeSFCGALOnce()
    let surface = try TriangulatedSurface()
    #expect(surface.geometryType == "TriangulatedSurface")
    #expect(surface.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
    #expect(surface.numPatches == 0)

    try surface.addPatch(Triangle(a: Point(x: 0.0, y: 0.0),
                                  b: Point(x: 1.0, y: 0.0),
                                  c: Point(x: 1.0, y: 1.0)))
    try surface.addPatch(Triangle(a: Point(x: 0.0, y: 0.0),
                                  b: Point(x: 1.0, y: 1.0),
                                  c: Point(x: 0.0, y: 1.0)))
    #expect(surface.numPatches == 2)
    let clone = try #require(surface.clone() as? TriangulatedSurface)
    #expect(clone.numPatches == 2)
}

@Test func upstreamTriangulatedSurfaceEmptyParsePatchAccessAndWKT() throws {
    // Upstream: TriangulatedSurfaceTest.cpp / setPatchNTest subset before replacement mutators
    let empty = try #require(UpstreamParity.geometry("TIN EMPTY") as? TriangulatedSurface)
    #expect(empty.geometryType == "TriangulatedSurface")
    #expect(empty.geometryTypeID == UpstreamParity.triangulatedSurfaceTypeID)
    #expect(empty.numPatches == 0)
    UpstreamParity.expectEmptyWKT(empty,
                                  equals: "TIN EMPTY",
                                  "TriangulatedSurfaceTest.cpp / setPatchNTest empty")

    let surface = try #require(UpstreamParity.geometry(
        "TIN Z (((0 0 0,2 0 2,1 2 4,0 0 0)),((2 0 2,3 2 3,1 2 4,2 0 2)),((1 2 4,3 2 3,2 4 6,1 2 4)))"
    ) as? TriangulatedSurface)
    #expect(surface.numPatches == 3)
    UpstreamParity.expectWKT(surface.patchAt(0), decimals: 0,
                             equals: "TRIANGLE Z ((0 0 0,2 0 2,1 2 4,0 0 0))",
                             "TriangulatedSurfaceTest.cpp / patchN(0)")
    UpstreamParity.expectWKT(surface.patchAt(1), decimals: 0,
                             equals: "TRIANGLE Z ((2 0 2,3 2 3,1 2 4,2 0 2))",
                             "TriangulatedSurfaceTest.cpp / patchN(1)")
    UpstreamParity.expectWKT(surface.patchAt(2), decimals: 0,
                             equals: "TRIANGLE Z ((1 2 4,3 2 3,2 4 6,1 2 4))",
                             "TriangulatedSurfaceTest.cpp / patchN(2)")
}

@Test func upstreamTriangulatedSurfaceFromWKT() throws {
    // Upstream: WktReaderTest.cpp / triangulatedSurface_fourTriangles
    let tin = try #require(UpstreamParity.geometry(
        "TIN (((0 0 0,0 0 1,0 1 0,0 0 0)),((0 0 0,0 1 0,1 0 0,0 0 0)),((0 0 0,1 0 0,0 0 1,0 0 0)),((1 0 0,0 1 0,0 0 1,1 0 0)))"
    ) as? TriangulatedSurface)
    #expect(tin.numPatches == 4)
    #expect(tin.patchAt(0).geometryType == "Triangle")
}

@Test func upstreamSolidReadTest() throws {
    // Upstream: SolidTest.cpp / solidReadTest
    let solid = try #require(UpstreamParity.geometry(UpstreamParity.squareShellWKT()) as? Solid)
    #expect(solid.geometryType == "Solid")
    #expect(solid.geometryTypeID == UpstreamParity.solidTypeID)
    #expect(solid.numShells == 1)
    #expect(solid.exteriorShell.numPatches == 6)
}

@Test func upstreamSolidReadWithInteriorShell() throws {
    // Upstream: SolidTest.cpp / solidReadTest
    let wkt = """
    SOLID (
      (
        ((0 0 0,0 1 0,1 1 0,1 0 0,0 0 0)),
        ((1 0 0,1 1 0,1 1 1,1 0 1,1 0 0)),
        ((0 1 0,0 1 1,1 1 1,1 1 0,0 1 0)),
        ((0 0 1,0 1 1,0 1 0,0 0 0,0 0 1)),
        ((1 0 1,1 1 1,0 1 1,0 0 1,1 0 1)),
        ((1 0 0,1 0 1,0 0 1,0 0 0,1 0 0))
      ),
      (
        ((0 0 0,0 0.5 0,0.5 0.5 0,0.5 0 0,0 0 0)),
        ((0.5 0 0,0.5 0.5 0,0.5 0.5 0.5,0.5 0 0.5,0.5 0 0)),
        ((0 0.5 0,0 0.5 0.5,0.5 0.5 0.5,0.5 0.5 0,0 0.5 0)),
        ((0 0 0.5,0 0.5 0.5,0 0.5 0,0 0 0,0 0 0.5)),
        ((0.5 0 0.5,0.5 0.5 0.5,0 0.5 0.5,0 0 0.5,0.5 0 0.5)),
        ((0.5 0 0,0.5 0 0.5,0 0 0.5,0 0 0,0.5 0 0))
      )
    )
    """
    let solid = try #require(UpstreamParity.geometry(wkt) as? Solid)
    #expect(solid.geometryType == "Solid")
    #expect(solid.geometryTypeID == UpstreamParity.solidTypeID)
    #expect(solid.numShells == 2)
    #expect(solid.exteriorShell.numPatches == 6)
    #expect(solid.shellAt(1).numPatches == 6)
}

@Test func upstreamSolidExteriorShellConstructorAndInteriorShellAddition() throws {
    // Upstream: SolidTest.cpp / solidSetExteriorRingTest and addInteriorShell subset
    let exterior = try #require(UpstreamParity.geometry(
        UpstreamParity.cubePolyhedralSurfaceWKT(min: 0.0, max: 1.0)
    ) as? PolyhedralSurface)
    let interior = try #require(UpstreamParity.geometry(
        UpstreamParity.cubePolyhedralSurfaceWKT(min: 0.2, max: 0.8)
    ) as? PolyhedralSurface)

    let solid = try Solid(exteriorShell: exterior)
    #expect(solid.numShells == 1)
    #expect(solid.exteriorShell.numPatches == 6)

    try solid.addInteriorShell(interior)
    #expect(solid.numShells == 2)
    #expect(solid.shellAt(1).numPatches == 6)

    let clone = try #require(solid.clone() as? Solid)
    #expect(clone.numShells == 2)
    #expect(clone.exteriorShell.numPatches == 6)
}
