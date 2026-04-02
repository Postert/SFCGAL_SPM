#if canImport(CSFCGAL_System)
import CSFCGAL_System
#elseif canImport(CSFCGAL_Binary)
import CSFCGAL_Binary
#endif

import CSFCGAL_Shim

/// The exact SFCGAL version this package is built against.
/// Must match the version used to build the iOS xcframeworks.
public let expectedSFCGALVersion = "2.2.0"

public func sfcgalVersion() -> String {
    return String(cString: sfcgal_version())
}

/// Verifies the linked SFCGAL library matches the expected version.
/// Call this at app startup to catch version mismatches early.
public func validateSFCGALVersion() {
    let actual = sfcgalVersion()
    precondition(
        actual == expectedSFCGALVersion,
        "SFCGAL version mismatch: found \(actual) but this package requires exactly \(expectedSFCGALVersion)"
    )
}
