import Foundation
import Testing
@testable import SwiftSFCGAL

@Test func upstreamWKTReaderPrimitiveCases() throws {
    // Upstream: io/WktReaderTest.cpp / pointXY, pointXYZ_implicit, pointXYZ_explicit,
    // lineString_twoPoints, lineString_twoPoints3D, polygonWithFourPoints
    let pointXY = try UpstreamParity.point("POINT (4.0 6.0)")
    #expect(pointXY.x == 4.0)
    #expect(pointXY.y == 6.0)

    let pointXYZImplicit = try UpstreamParity.point("POINT (4.0 5.0 6.0)")
    #expect(pointXYZImplicit.is3D)
    #expect(pointXYZImplicit.z == 6.0)

    let pointXYZExplicit = try UpstreamParity.point("POINT Z (4.0 5.0 6.0)")
    #expect(pointXYZExplicit.is3D)
    #expect(pointXYZExplicit.z == 6.0)

    let line2D = try UpstreamParity.lineString("LINESTRING (0.0 0.0,1.0 1.0)")
    #expect(line2D.numPoints == 2)

    let line3D = try UpstreamParity.lineString("LINESTRING (0.0 0.0 0.0,1.0 1.0 1.0)")
    #expect(line3D.numPoints == 2)
    #expect(line3D.pointAt(0).is3D)
    #expect(line3D.pointAt(1).is3D)

    let polygon = try UpstreamParity.polygon("POLYGON ((0 0,1 0,1 1,0 0))")
    #expect(polygon.exteriorRing.numPoints == 4)
}

@Test func upstreamWKTReaderEmptyPrimitiveCases() throws {
    // Upstream: io/WktReaderTest.cpp / pointEmpty, lineStringEmpty, polygonEmpty
    let point = try UpstreamParity.point("POINT EMPTY")
    #expect(point.geometryTypeID == UpstreamParity.pointTypeID)
    UpstreamParity.expectEmptyWKT(point,
                                  equals: "POINT EMPTY",
                                  "WktReaderTest.cpp / pointEmpty")

    let lineString = try UpstreamParity.lineString("LINESTRING EMPTY")
    #expect(lineString.geometryTypeID == UpstreamParity.lineStringTypeID)
    UpstreamParity.expectEmptyWKT(lineString,
                                  equals: "LINESTRING EMPTY",
                                  "WktReaderTest.cpp / lineStringEmpty")

    let polygon = try UpstreamParity.polygon("POLYGON EMPTY")
    #expect(polygon.geometryTypeID == UpstreamParity.polygonTypeID)
    UpstreamParity.expectEmptyWKT(polygon,
                                  equals: "POLYGON EMPTY",
                                  "WktReaderTest.cpp / polygonEmpty")
}

@Test func upstreamWKTReaderCollectionCases() throws {
    // Upstream: io/WktReaderTest.cpp / multiPointEmpty2, triangulatedSurface_fourTriangles, charArrayRead
    let multiPoint = try #require(UpstreamParity.geometry("MULTIPOINT (0 0,1 1,EMPTY)") as? MultiPoint)
    #expect(multiPoint.numGeometries == 2)
    UpstreamParity.expectWKT(multiPoint, decimals: 0,
                             equals: "MULTIPOINT ((0 0),(1 1))",
                             "WktReaderTest.cpp / multiPointEmpty2")

    let tin = try #require(UpstreamParity.geometry(
        "TIN (((0 0 0,0 0 1,0 1 0,0 0 0)),((0 0 0,0 1 0,1 0 0,0 0 0)),((0 0 0,1 0 0,0 0 1,0 0 0)),((1 0 0,0 1 0,0 0 1,1 0 0)))"
    ) as? TriangulatedSurface)
    #expect(tin.numPatches == 4)

    let charArrayEquivalent = try UpstreamParity.lineString("LINESTRING (0.0 0.0,1.0 1.0)")
    #expect(charArrayEquivalent.numPoints == 2)
}

@Test func upstreamWKTReaderEmptyCollectionCases() throws {
    // Upstream: io/WktReaderTest.cpp / multiPointEmpty, multiPointEmpty2, multiPointEmpty3,
    // multiLineStringEmpty, multiPolygonEmpty, geometryCollectionEmpty, triangulatedSurface_Empty
    let emptyMultiPoint = try #require(UpstreamParity.geometry("MULTIPOINT EMPTY") as? MultiPoint)
    #expect(emptyMultiPoint.numGeometries == 0)
    UpstreamParity.expectEmptyWKT(emptyMultiPoint,
                                  equals: "MULTIPOINT EMPTY",
                                  "WktReaderTest.cpp / multiPointEmpty")

    let emptyMultiPointMembers = try #require(UpstreamParity.geometry("MULTIPOINT (EMPTY,EMPTY)") as? MultiPoint)
    #expect(emptyMultiPointMembers.numGeometries == 0)
    UpstreamParity.expectEmptyWKT(emptyMultiPointMembers,
                                  equals: "MULTIPOINT EMPTY",
                                  "WktReaderTest.cpp / multiPointEmpty3")

    let emptyMultiLineString = try #require(UpstreamParity.geometry("MULTILINESTRING EMPTY") as? MultiLineString)
    #expect(emptyMultiLineString.numGeometries == 0)
    UpstreamParity.expectEmptyWKT(emptyMultiLineString,
                                  equals: "MULTILINESTRING EMPTY",
                                  "WktReaderTest.cpp / multiLineStringEmpty")

    let emptyMultiPolygon = try #require(UpstreamParity.geometry("MULTIPOLYGON EMPTY") as? MultiPolygon)
    #expect(emptyMultiPolygon.numGeometries == 0)
    UpstreamParity.expectEmptyWKT(emptyMultiPolygon,
                                  equals: "MULTIPOLYGON EMPTY",
                                  "WktReaderTest.cpp / multiPolygonEmpty")

    let emptyCollection = try UpstreamParity.collection("GEOMETRYCOLLECTION EMPTY")
    #expect(emptyCollection.numGeometries == 0)
    UpstreamParity.expectEmptyWKT(emptyCollection,
                                  equals: "GEOMETRYCOLLECTION EMPTY",
                                  "WktReaderTest.cpp / geometryCollectionEmpty")

    let emptyTIN = try #require(UpstreamParity.geometry("TIN EMPTY") as? TriangulatedSurface)
    #expect(emptyTIN.numPatches == 0)
    UpstreamParity.expectEmptyWKT(emptyTIN,
                                  equals: "TIN EMPTY",
                                  "WktReaderTest.cpp / triangulatedSurface_Empty")
}

@Test func upstreamWKTReaderExactRationalCoordinates() throws {
    // Upstream: io/WktReaderTest.cpp / wkt_exactTest, adapted through Double accessors
    let lineString = try UpstreamParity.lineString("LINESTRING (2/3 3/2,5/4 2/3)")
    #expect(lineString.numPoints == 2)
    UpstreamParity.expectAlmostEqual(lineString.pointAt(0).x, 2.0 / 3.0)
    UpstreamParity.expectAlmostEqual(lineString.pointAt(0).y, 3.0 / 2.0)
    UpstreamParity.expectAlmostEqual(lineString.pointAt(1).x, 5.0 / 4.0)
    UpstreamParity.expectAlmostEqual(lineString.pointAt(1).y, 2.0 / 3.0)
}

@Test func upstreamWKTReaderRejectsExtraCharacters() {
    // Upstream: io/WktReaderTest.cpp / wktExtraCharacters
    TestSupport.initializeSFCGALOnce()
    #expect(throws: SFCGALError.self) {
        _ = try Geometry.fromWKT("POINT (0 0)POINT (1 0)")
    }
}

@Test func upstreamWKBRoundTripsKnownCases() throws {
    // Upstream: io/WkbWriterTest.cpp / writeWkb, readWkb, capi/sfcgal_cTest.cpp / testAsWkb
    let cases = [
        "POINT (1 2)",
        "POINT Z (1 2 3)",
        "LINESTRING (0 0,1 1,2 2)",
        "POLYGON ((0 0,0 4,4 4,4 0,0 0))",
        "MULTIPOINT ((1 1),(2 2))",
        "MULTILINESTRING ((0 0,1 1),(2 2,3 3))",
        "MULTIPOLYGON (((0 0,1 0,1 1,0 1,0 0)))",
        "GEOMETRYCOLLECTION (POINT (1 2),LINESTRING (0 0,1 1))"
    ]

    for wkt in cases {
        let geometry = try UpstreamParity.geometry(wkt)
        try UpstreamParity.expectRoundTripsWKB(geometry, decimals: 6, "WkbWriterTest.cpp / readWkb")
        try UpstreamParity.expectRoundTripsHexWKB(geometry, decimals: 6, "WkbWriterTest.cpp / writeWkb")
        #expect(!geometry.asWKB().isEmpty)
        #expect(!geometry.asHexWKB().isEmpty)
    }
}

@Test func upstreamWKBRejectsInvalidInputs() {
    // Upstream: io/WkbWriterTest.cpp / readWkb failure coverage, adapted to public throwing API
    TestSupport.initializeSFCGALOnce()
    #expect(throws: SFCGALError.self) {
        _ = try Geometry.fromWKB(Data())
    }
    #expect(throws: SFCGALError.self) {
        _ = try Geometry.fromHexWKB("0")
    }
}

@Test func upstreamEWKTPreservesSRIDAndGeometry() throws {
    // Upstream: io/WkbWriterTest.cpp / PostgisEWkb, adapted through current EWKT API
    let parsed = try Geometry.parseEWKT("SRID=3946;POINT (1 2)")
    #expect(parsed.srid == 3946)
    let point = try #require(parsed.geometry as? Point)
    #expect(point.x == 1.0)
    #expect(point.y == 2.0)
    let ewkt = parsed.geometry.asEWKT(srid: parsed.srid, decimals: 0)
    #expect(ewkt.contains("SRID=3946"))
    #expect(ewkt.contains("POINT"))
}
