import XCTest
@testable import ConcatenatedCollection

final class ConcatenatedCollectionTests: XCTestCase {
    func testJoined() {
        XCTAssertEqual(Array([1,2,3].joined(with: [4,5,6]), [1,2,3,4,5,6])
    }

    static let allTests = [
        ("testJoined", testJoined)
    ]
}
