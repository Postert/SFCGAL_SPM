#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif

import CSFCGAL_Shim

// ── Version ───────────────────────────────────────────────────────────────────

/// The exact SFCGAL version this package is built against.
/// Sourced from CSFCGAL_Shim — single source of truth shared with the compile-time check.
public let expectedSFCGALVersion: String = SWIFTSFCGAL_REQUIRED_VERSION

public func sfcgalVersion() -> String {
    return String(cString: sfcgal_version())
}

/// Verifies the linked SFCGAL library matches the expected version.
/// Call this at app startup to catch version mismatches early.
public func validateSFCGALVersion() {
    let actual = sfcgalVersion()
    precondition(
        actual == expectedSFCGALVersion,
        "SFCGAL version mismatch: SwiftSFCGAL requires exactly SFCGAL \(expectedSFCGALVersion), but found \(actual) installed on this system"
    )
}

// ── Initialization ────────────────────────────────────────────────────────────

/// Initialize SFCGAL with safe error handling.
///
/// Installs custom warning/error handlers so SFCGAL never calls `abort()`.
/// Must be called once on the main thread before any SFCGAL operations or
/// before spawning threads that use SFCGAL.
public func initializeSFCGAL() {
    sfcgal_swift_init()
}

// ── Error type ────────────────────────────────────────────────────────────────

/// An error reported by the SFCGAL library.
public enum SFCGALError: Error, CustomStringConvertible {
    /// WKT / EWKT input could not be parsed.
    case parseError(String)
    /// A geometry operation (tesselation, Boolean op, etc.) failed.
    case operationFailed(String)
    /// A geometry that was expected to be valid is not.
    case invalidGeometry(String)

    public var description: String {
        switch self {
        case .parseError(let msg):      return "SFCGAL parse error: \(msg)"
        case .operationFailed(let msg): return "SFCGAL operation failed: \(msg)"
        case .invalidGeometry(let msg): return "SFCGAL invalid geometry: \(msg)"
        }
    }
}

// ── Warning access ────────────────────────────────────────────────────────────

/// Returns the last warning message captured from SFCGAL on the current thread,
/// or `nil` if no warning has been issued since the last `initializeSFCGAL()`
/// or since the warning was last cleared internally.
///
/// Warnings are informational — they do not cause `sfcgalCall` to throw.
/// Check this after an operation if you want to surface non-fatal diagnostics.
public func sfcgalLastWarning() -> String? {
    guard let ptr = sfcgal_swift_get_last_warning() else { return nil }
    return String(cString: ptr)
}

// ── Internal helper ───────────────────────────────────────────────────────────

/// Clears the thread-local error buffer, runs `operation`, then throws
/// `SFCGALError` if SFCGAL reported an error during the call.
///
/// All geometry operations in the Swift API use this wrapper so that SFCGAL
/// errors surface as Swift `throws` rather than silent failures or crashes.
@discardableResult
internal func sfcgalCall<T>(_ operation: () -> T) throws -> T {
    sfcgal_swift_clear_errors()
    let result = operation()
    if sfcgal_swift_has_error() != 0,
       let ptr = sfcgal_swift_get_last_error() {
        throw SFCGALError.operationFailed(String(cString: ptr))
    }
    return result
}
