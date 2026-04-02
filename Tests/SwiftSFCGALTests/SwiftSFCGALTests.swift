import Testing
@testable import SwiftSFCGAL

@Test func testSfcgalVersion() {
    let version = sfcgalVersion()
    #expect(!version.isEmpty, "SFCGAL version string should not be empty")
}
