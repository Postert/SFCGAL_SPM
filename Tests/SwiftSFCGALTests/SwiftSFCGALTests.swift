import Testing
@testable import SwiftSFCGAL

@Test func testSfcgalVersion() {
    let version = sfcgalVersion()
    #expect(version == expectedSFCGALVersion,
        "SFCGAL version mismatch: got \(version), expected \(expectedSFCGALVersion)")
}
