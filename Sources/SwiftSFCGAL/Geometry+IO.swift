#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim
import Foundation

// MARK: - WKB I/O

extension Geometry {

    // ── Reading ───────────────────────────────────────────────────────────────

    /// Parses a raw binary WKB buffer and returns the most-specific geometry subclass.
    ///
    /// - Parameter data: Raw WKB bytes (not hex-encoded). Must be non-empty.
    /// - Throws: `SFCGALError.parseError` if the data is empty or malformed.
    public static func fromWKB(_ data: Data) throws -> Geometry {
        guard !data.isEmpty else {
            throw SFCGALError.parseError("WKB data is empty")
        }
        let ptr = try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) throws -> UnsafeMutableRawPointer? in
            guard let base = raw.baseAddress else {
                throw SFCGALError.parseError("Invalid WKB buffer")
            }
            return try sfcgalCall {
                sfcgal_io_read_wkb(base.assumingMemoryBound(to: CChar.self), data.count)
            }
        }
        guard let p = ptr else {
            throw SFCGALError.parseError("Failed to parse WKB data")
        }
        return makeGeometry(handle: p, ownsHandle: true)
    }

    /// Parses a hex-encoded WKB string and returns the most-specific geometry subclass.
    ///
    /// Hex WKB is the format PostGIS returns for text-mode geometry queries.
    /// Each byte is two hex characters, e.g. `"0101000000..."`.
    ///
    /// - Parameter hex: Even-length string of hex characters (case-insensitive).
    /// - Throws: `SFCGALError.parseError` if the string is empty, odd-length, or invalid hex.
    public static func fromHexWKB(_ hex: String) throws -> Geometry {
        guard !hex.isEmpty else {
            throw SFCGALError.parseError("Hex WKB string is empty")
        }
        guard hex.count % 2 == 0 else {
            throw SFCGALError.parseError("Hex WKB string has odd length — not valid hex")
        }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< next], radix: 16) else {
                throw SFCGALError.parseError("Invalid hex characters in WKB string")
            }
            bytes.append(byte)
            index = next
        }
        return try fromWKB(Data(bytes))
    }

    // ── Writing ───────────────────────────────────────────────────────────────

    /// Serialises this geometry to raw binary WKB.
    ///
    /// - Returns: Binary WKB bytes, or empty `Data` if serialisation fails.
    public func asWKB() -> Data {
        var buf: UnsafeMutablePointer<CChar>? = nil
        var len: Int = 0
        sfcgal_geometry_as_wkb(handle, &buf, &len)
        guard let b = buf else { return Data() }
        defer { sfcgal_swift_free_buffer(b) }
        return Data(bytes: b, count: len)
    }

    /// Serialises this geometry to a hex-encoded WKB string.
    ///
    /// Each byte is represented as two uppercase hex characters.
    /// This is the format PostGIS uses internally for geometry storage.
    ///
    /// - Returns: Hex WKB string, or empty string if serialisation fails.
    public func asHexWKB() -> String {
        var buf: UnsafeMutablePointer<CChar>? = nil
        var len: Int = 0
        sfcgal_geometry_as_hexwkb(handle, &buf, &len)
        guard let b = buf else { return "" }
        defer { sfcgal_swift_free_buffer(b) }
        return String(cString: b)
    }
}

// MARK: - EWKT I/O

extension Geometry {

    // ── Reading ───────────────────────────────────────────────────────────────

    /// Parses an EWKT string and returns the geometry, discarding the SRID.
    ///
    /// Use `parseEWKT(_:)` when you also need the SRID value.
    ///
    /// - Parameter ewkt: A valid EWKT string, e.g. `"SRID=4326;POINT(1 2)"`.
    /// - Throws: `SFCGALError.parseError` if the string cannot be parsed.
    public static func fromEWKT(_ ewkt: String) throws -> Geometry {
        try parseEWKT(ewkt).geometry
    }

    /// Parses an EWKT string and returns both the geometry and the SRID.
    ///
    /// EWKT (Extended Well-Known Text) prefixes standard WKT with a spatial
    /// reference system ID: `"SRID=4326;POINT(1 2)"`. The SRID (e.g. 4326 for
    /// WGS84) identifies the coordinate reference system.
    ///
    /// - Parameter ewkt: A valid EWKT string.
    /// - Throws: `SFCGALError.parseError` if the string cannot be parsed.
    /// - Returns: A named tuple `(geometry:, srid:)`.
    public static func parseEWKT(_ ewkt: String) throws -> (geometry: Geometry, srid: UInt32) {
        guard let prepared = try sfcgalCall({ sfcgal_io_read_ewkt(ewkt, ewkt.utf8.count) }) else {
            throw SFCGALError.parseError("Failed to parse EWKT: \(ewkt)")
        }
        defer { sfcgal_prepared_geometry_delete(prepared) }

        let srid = UInt32(sfcgal_prepared_geometry_srid(prepared))

        // sfcgal_prepared_geometry_geometry returns const sfcgal_geometry_t* →
        // UnsafeRawPointer? in Swift. The prepared geometry owns it; clone before
        // the defer releases prepared.
        guard let constPtr = sfcgal_prepared_geometry_geometry(prepared) else {
            throw SFCGALError.operationFailed("Failed to extract geometry from EWKT prepared geometry")
        }
        guard let cloned = sfcgal_geometry_clone(UnsafeMutableRawPointer(mutating: constPtr)) else {
            throw SFCGALError.operationFailed("Failed to clone geometry extracted from EWKT")
        }
        return (makeGeometry(handle: cloned, ownsHandle: true), srid)
    }

    // ── Writing ───────────────────────────────────────────────────────────────

    /// Returns the EWKT representation of this geometry with the given SRID.
    ///
    /// Example output: `"SRID=4326;POINT(1 2)"`
    ///
    /// The geometry is cloned internally before being handed to SFCGAL's
    /// PreparedGeometry (which takes ownership), so this instance is unaffected.
    ///
    /// - Parameters:
    ///   - srid: The spatial reference system ID (e.g. `4326` for WGS84).
    ///   - decimals: Decimal places in coordinate output. Pass `-1` (default) for full precision.
    /// - Returns: EWKT string, or empty string if serialisation fails.
    public func asEWKT(srid: UInt32, decimals: Int32 = -1) -> String {
        guard let cloned = sfcgal_geometry_clone(handle) else { return "" }
        guard let prepared = sfcgal_prepared_geometry_create_from_geometry(cloned, srid_t(srid)) else {
            sfcgal_geometry_delete(cloned)
            return ""
        }
        defer { sfcgal_prepared_geometry_delete(prepared) }

        var buf: UnsafeMutablePointer<CChar>? = nil
        var len: Int = 0
        sfcgal_prepared_geometry_as_ewkt(prepared, decimals, &buf, &len)
        guard let b = buf else { return "" }
        defer { sfcgal_swift_free_buffer(b) }
        return String(cString: b)
    }
}

// MARK: - WKT precision convenience

extension Geometry {

    /// Returns the WKT representation rounded to `decimalPlaces` digits.
    ///
    /// Swift-friendly wrapper around `asWKT(decimals:)` so callers don't need
    /// to cast to `Int32`.
    ///
    /// - Parameter decimalPlaces: Number of decimal places (0 or more).
    public func asWKT(decimalPlaces: Int) -> String {
        asWKT(decimals: Int32(clamping: decimalPlaces))
    }
}
