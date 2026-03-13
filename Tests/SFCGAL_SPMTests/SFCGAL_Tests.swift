import Testing
@testable import SFCGAL

@Test func helloWorldTest() {
    let result = helloWorld()
    #expect(result == "Hello, World from SFCGAL!")
}
