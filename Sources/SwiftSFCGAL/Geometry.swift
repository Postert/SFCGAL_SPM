#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif
import CSFCGAL_Shim

/// Base class wrapping an SFCGAL geometry pointer with automatic memory management.
///
/// Swift's ARC calls `deinit` the moment the last reference is dropped, which
/// immediately frees the underlying C geometry — no manual cleanup needed.
///
/// All concrete geometry types (`Point`, `LineString`, `Polygon`, …) inherit
/// from this class. You can use `Geometry` directly when the specific type
/// does not matter (e.g. when parsing unknown WKT input).
///
/// ## Ownership
/// By default every `Geometry` instance **owns** its handle and frees it in
/// `deinit`. Child geometries borrowed from a parent collection (e.g. a ring
/// inside a polygon) must be created with `ownsHandle: false` so they don't
/// double-free memory that is still owned by the parent.
public class Geometry {

    // MARK: - Storage

    /// The raw SFCGAL C pointer. Do not free this manually.
    internal let handle: UnsafeMutableRawPointer

    /// When `true` (the default), `deinit` calls `sfcgal_geometry_delete`.
    /// Set to `false` for borrowed child references whose lifetime is managed
    /// by a parent geometry.
    private let ownsHandle: Bool

    // MARK: - Lifecycle

    internal init(handle: UnsafeMutableRawPointer, ownsHandle: Bool = true) {
        self.handle = handle
        self.ownsHandle = ownsHandle
    }

    deinit {
        if ownsHandle {
            sfcgal_geometry_delete(handle)
        }
    }

    // MARK: - Factory

    /// Parse a WKT (Well-Known Text) string and return the corresponding geometry.
    ///
    /// - Parameter wkt: A valid WKT string, e.g. `"POINT(1 2 3)"`.
    /// - Throws: `SFCGALError.parseError` if the string cannot be parsed.
    public convenience init(wkt: String) throws {
        // sfcgalCall clears the error buffer, runs the C call, and throws
        // SFCGALError.operationFailed if SFCGAL reports an error.
        guard let ptr = try sfcgalCall({ sfcgal_io_read_wkt(wkt, wkt.utf8.count) }) else {
            // Safety net: sfcgalCall would normally have thrown already, but
            // guard against the rare case where the pointer is nil without an error.
            throw SFCGALError.parseError("Failed to parse WKT: \(wkt)")
        }
        self.init(handle: ptr)
    }

    // MARK: - Type information

    /// The OGC geometry type name (e.g. `"Point"`, `"Polygon"`, `"Solid"`).
    ///
    /// The string is allocated by SFCGAL and freed immediately after copying
    /// into Swift — callers receive an ordinary `String` with no ownership concerns.
    public var geometryType: String {
        var typePtr: UnsafeMutablePointer<CChar>? = nil
        var typeLen: Int = 0
        sfcgal_geometry_type(handle, &typePtr, &typeLen)
        guard let ptr = typePtr else { return "Unknown" }
        defer { sfcgal_swift_free_buffer(ptr) }
        return String(cString: ptr)
    }

    /// The numeric SFCGAL type identifier (e.g. `1` for Point, `3` for Polygon).
    ///
    /// Useful for `switch` dispatch in code that receives a `Geometry` and needs
    /// to downcast to a concrete subclass. The raw values match the
    /// `SFCGAL_TYPE_*` constants in `sfcgal_c.h`.
    public var geometryTypeID: Int32 {
        sfcgal_geometry_type_id(handle).rawValue
    }

    // MARK: - Validity

    /// Whether the geometry is valid according to SFCGAL's validation rules.
    ///
    /// An invalid geometry (e.g. a self-intersecting polygon) may still be
    /// representable but will produce incorrect results in spatial operations.
    public var isValid: Bool {
        sfcgal_geometry_is_valid(handle) != 0
    }

    // MARK: - WKT output

    /// Returns the WKT representation of this geometry.
    ///
    /// The buffer is allocated by SFCGAL and freed before this method returns —
    /// only the resulting Swift `String` is kept.
    ///
    /// - Returns: WKT string, or an empty string if serialisation fails.
    public func asWKT() -> String {
        var buf: UnsafeMutablePointer<CChar>? = nil
        var len: Int = 0
        sfcgal_geometry_as_text(handle, &buf, &len)
        guard let b = buf else { return "" }
        defer { sfcgal_swift_free_buffer(b) }
        return String(cString: b)
    }

    /// Returns the WKT representation with the specified decimal precision.
    ///
    /// - Parameter decimals: Number of decimal places. Pass `-1` for full precision
    ///   (equivalent to `asWKT()`).
    public func asWKT(decimals: Int32) -> String {
        var buf: UnsafeMutablePointer<CChar>? = nil
        var len: Int = 0
        sfcgal_geometry_as_text_decim(handle, decimals, &buf, &len)
        guard let b = buf else { return "" }
        defer { sfcgal_swift_free_buffer(b) }
        return String(cString: b)
    }

    // MARK: - Clone

    /// Returns a deep copy of this geometry.
    ///
    /// The clone is fully independent — modifying or releasing the original has
    /// no effect on the clone.
    ///
    /// - Throws: `SFCGALError.operationFailed` if cloning fails.
    public func clone() throws -> Geometry {
        guard let ptr = try sfcgalCall({ sfcgal_geometry_clone(handle) }) else {
            throw SFCGALError.operationFailed("Failed to clone geometry")
        }
        return Geometry(handle: ptr)
    }
}
