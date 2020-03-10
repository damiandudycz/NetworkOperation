import XCTest
@testable import NetworkOperation

final class NetworkOperationTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(NetworkOperation().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
