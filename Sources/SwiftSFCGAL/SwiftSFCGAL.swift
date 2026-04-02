#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif

import CSFCGAL_Shim

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
