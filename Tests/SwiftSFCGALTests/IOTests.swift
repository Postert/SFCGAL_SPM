import Foundation
import Testing

@testable import SwiftSFCGAL

// ══════════════════════════════════════════════════════════════════════════════
// Issue #11 — WKT / WKB / EWKT I/O tests
// ══════════════════════════════════════════════════════════════════════════════

// MARK: - WKB round-trip

@Test func testWKBRoundtripPoint() throws {
    initializeSFCGAL()
    let original = try Point(x: 1.5, y: 2.5)
    let wkb = original.asWKB()
    #expect(!wkb.isEmpty)
    let parsed = try Geometry.fromWKB(wkb)
    let point = try #require(parsed as? Point)
    #expect(point.x == 1.5)
    #expect(point.y == 2.5)
}

@Test func testWKBRoundtripPolygon() throws {
    initializeSFCGAL()
    let original = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let wkb = original.asWKB()
    #expect(!wkb.isEmpty)
    let parsed = try Geometry.fromWKB(wkb)
    #expect(parsed is Polygon)
    // WKT of the round-tripped geometry must contain POLYGON
    #expect(parsed.asWKT().contains("POLYGON"))
}

@Test func testWKBRoundtripLineString() throws {
    initializeSFCGAL()
    let original = try Geometry.fromWKT("LINESTRING(0 0,1 1,2 0)")
    let wkb = original.asWKB()
    let parsed = try Geometry.fromWKB(wkb)
    #expect(parsed is LineString)
    let ls = parsed as! LineString
    #expect(ls.numPoints == 3)
}

@Test func testWKBRoundtripPoint3D() throws {
    initializeSFCGAL()
    let original = try Point(x: 10.0, y: 20.0, z: 30.0)
    let wkb = original.asWKB()
    let parsed = try Geometry.fromWKB(wkb)
    let p = try #require(parsed as? Point)
    #expect(p.x == 10.0)
    #expect(p.y == 20.0)
    #expect(p.z == 30.0)
    #expect(p.is3D)
}

// MARK: - WKB error handling

@Test func testWKBFromEmptyDataThrows() {
    initializeSFCGAL()
    #expect(throws: SFCGALError.self) {
        _ = try Geometry.fromWKB(Data())
    }
}

@Test func testWKBFromInvalidDataThrows() {
    initializeSFCGAL()
    // Random bytes that are not valid WKB
    let garbage = Data([0xFF, 0xFE, 0x00, 0x01, 0x02])
    #expect(throws: SFCGALError.self) {
        _ = try Geometry.fromWKB(garbage)
    }
}

// MARK: - Hex WKB round-trip

@Test func testHexWKBRoundtripPoint() throws {
    initializeSFCGAL()
    let original = try Point(x: 3.0, y: 4.0)
    let hex = original.asHexWKB()
    #expect(!hex.isEmpty)
    // Hex WKB must be an even-length string of hex chars
    #expect(hex.count % 2 == 0)
    let parsed = try Geometry.fromHexWKB(hex)
    let point = try #require(parsed as? Point)
    #expect(point.x == 3.0)
    #expect(point.y == 4.0)
}

@Test func testHexWKBRoundtripPolygon() throws {
    initializeSFCGAL()
    let original = try Geometry.fromWKT("POLYGON((0 0,2 0,2 2,0 2,0 0))")
    let hex = original.asHexWKB()
    #expect(!hex.isEmpty)
    let parsed = try Geometry.fromHexWKB(hex)
    #expect(parsed is Polygon)
}

@Test func testHexWKBIsValidHexString() throws {
    initializeSFCGAL()
    let geom = try Geometry.fromWKT("POINT(7 8)")
    let hex = geom.asHexWKB()
    // Every character must be a valid hex digit
    let validChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
    #expect(hex.unicodeScalars.allSatisfy { validChars.contains($0) })
}

@Test func testFromHexWKBEmptyStringThrows() {
    initializeSFCGAL()
    #expect(throws: SFCGALError.self) {
        _ = try Geometry.fromHexWKB("")
    }
}

@Test func testFromHexWKBOddLengthThrows() {
    initializeSFCGAL()
    #expect(throws: SFCGALError.self) {
        _ = try Geometry.fromHexWKB("ABC")  // odd length — not valid hex pairs
    }
}

@Test func testFromHexWKBInvalidCharsThrows() {
    initializeSFCGAL()
    #expect(throws: SFCGALError.self) {
        _ = try Geometry.fromHexWKB("ZZZZ")  // valid length, invalid hex chars
    }
}

// MARK: - EWKT reading

@Test func testFromEWKTExtractsGeometry() throws {
    initializeSFCGAL()
    let geom = try Geometry.fromEWKT("SRID=4326;POINT(1 2)")
    let p = try #require(geom as? Point)
    #expect(p.x == 1.0)
    #expect(p.y == 2.0)
}

@Test func testParseEWKTPreservesSRID() throws {
    initializeSFCGAL()
    let result = try Geometry.parseEWKT("SRID=4326;POINT(1 2)")
    #expect(result.srid == 4326)
    let p = try #require(result.geometry as? Point)
    #expect(p.x == 1.0)
}

@Test func testParseEWKTPolygon() throws {
    initializeSFCGAL()
    let result = try Geometry.parseEWKT("SRID=32632;POLYGON((0 0,1 0,1 1,0 1,0 0))")
    #expect(result.srid == 32632)
    #expect(result.geometry is Polygon)
}

@Test func testParseEWKTNoSRIDDefaultsToZero() throws {
    initializeSFCGAL()
    // Plain WKT without SRID prefix — SFCGAL should parse it via EWKT parser
    // and return SRID 0 (the "no SRID" sentinel).
    let result = try Geometry.parseEWKT("POINT(5 6)")
    #expect(result.geometry is Point)
    // SRID 0 means no SRID was set
    #expect(result.srid == 0)
}

@Test func testFromEWKTInvalidThrows() {
    initializeSFCGAL()
    #expect(throws: SFCGALError.self) {
        _ = try Geometry.fromEWKT("NOT_VALID_EWKT")
    }
}

// MARK: - EWKT writing

@Test func testAsEWKTContainsSRID() throws {
    initializeSFCGAL()
    let p = try Point(x: 1.0, y: 2.0)
    let ewkt = p.asEWKT(srid: 4326)
    #expect(ewkt.contains("SRID=4326"))
    #expect(ewkt.contains("POINT"))
}

@Test func testAsEWKTRoundtrip() throws {
    initializeSFCGAL()
    let original = try Point(x: 10.0, y: 20.0)
    let ewkt = original.asEWKT(srid: 4326)
    let result = try Geometry.parseEWKT(ewkt)
    #expect(result.srid == 4326)
    let p = try #require(result.geometry as? Point)
    #expect(p.x == 10.0)
    #expect(p.y == 20.0)
}

@Test func testAsEWKTPolygonRoundtrip() throws {
    initializeSFCGAL()
    let original = try Geometry.fromWKT("POLYGON((0 0,1 0,1 1,0 1,0 0))")
    let ewkt = original.asEWKT(srid: 32632)
    #expect(ewkt.contains("SRID=32632"))
    let result = try Geometry.parseEWKT(ewkt)
    #expect(result.srid == 32632)
    #expect(result.geometry is Polygon)
}

@Test func testAsEWKTDecimalPrecision() throws {
    initializeSFCGAL()
    let p = try Point(x: 1.123456789, y: 2.987654321)
    let full = p.asEWKT(srid: 4326)
    let two = p.asEWKT(srid: 4326, decimals: 2)
    // Rounded output must be shorter than full-precision output
    #expect(two.count < full.count)
    #expect(two.contains("SRID=4326"))
}

// MARK: - WKT precision (asWKT overloads)

@Test func testAsWKTDecimalPlacesInt() throws {
    initializeSFCGAL()
    let p = try Point(x: 1.123456789, y: 2.987654321)
    let full = p.asWKT()
    let two = p.asWKT(decimalPlaces: 2)
    #expect(two.count < full.count)
    #expect(two.contains("POINT"))
}

@Test func testAsWKTZeroDecimals() throws {
    initializeSFCGAL()
    let p = try Point(x: 1.9, y: 2.1)
    let wkt = p.asWKT(decimalPlaces: 0)
    // With 0 decimals all coordinates should be integers — no decimal point
    #expect(!wkt.contains("."))
}

// MARK: - WKB / EWKT independence

@Test func testWKBAndEWKTAreIndependent() throws {
    initializeSFCGAL()
    // Both formats encode the same point — verify coordinates match
    let original = try Point(x: 42.0, y: 7.0)
    let fromWKB = try Geometry.fromWKB(original.asWKB())
    let fromEWKT = try Geometry.fromEWKT(original.asEWKT(srid: 4326))
    let p1 = try #require(fromWKB as? Point)
    let p2 = try #require(fromEWKT as? Point)
    #expect(p1.x == p2.x)
    #expect(p1.y == p2.y)
}
