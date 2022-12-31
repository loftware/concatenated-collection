import XCTest
import LoftDataStructures_Either
import LoftTest_StandardLibraryProtocolChecks
import LoftDataStructures_ConcatenatedCollection

final class ConcatenatedCollectionTests: XCTestCase {
    func AssertSomeEqual<S1: Sequence, S2: Sequence>(
        _ expected: S1,
        _ actual: S2,
        file: StaticString = #file,
        line: UInt = #line
    ) where
        S1.Element == Optional<S2.Element>,
        S2.Element: Equatable
    {
        var mismatchDepth = 0
        for (maybeX, y) in zip(expected, actual) {
            defer { mismatchDepth += 1 }
            guard let x = maybeX else { continue }
            XCTAssertEqual(x, y, """
                Non-matching element found at position \(mismatchDepth)
                """,
               file: file, line: line)
        }
    }

    let unordered: Set<Int> = [1, 2, 3]
    let array: Array<Int> = [4, 5, 6]
    let stringArray = ["oh", "hi", "there"]
    let dict = [
        "a": 1,
        "b": 2,
        "c": 3,
    ]

    let joinedArrays = [1, 2, 3].joined(with: [4, 5, 6])

    // sequence tests
    func testSameCollectionTypeJoin() {
        XCTAssertEqual(
            Array([1, 2, 3].joined(with: [4, 5, 6])),
            [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(Array([1, 2, 3].joined(with: [])), [1, 2, 3])
        XCTAssertEqual(Array([].joined(with: [1, 2, 3])), [1, 2, 3])
    }

    func testDisperateCollectionTypeJoin() {
        // Test it with disperate collection types.

        let setFirst = unordered.joined(with: array)
        let arrayFirst = array.joined(with: unordered)

        XCTAssertEqual(Set(setFirst), Set([1, 2, 3, 4, 5, 6]))
        XCTAssertEqual(Set(arrayFirst), Set([1, 2, 3, 4, 5, 6]))
        XCTAssertEqual(Set(Set<Int>().joined(with: array)), Set([4, 5, 6]))
        XCTAssertEqual(Set([].joined(with: unordered)), Set([1, 2, 3]))

        // Ensure at least the array half of the joined sequence maintains
        // itteration order.
        AssertSomeEqual([nil, nil, nil, 4, 5, 6], setFirst)
        AssertSomeEqual([4, 5, 6, nil, nil, nil], arrayFirst)
    }

    func testLaziness() {
        var lazinessBroken = false
        let result = unordered.lazy
            .map {
                lazinessBroken = true
                return $0
            }
            .joined(with: array)
            .map { (x: Int) -> Int in
                lazinessBroken = true
                return x
            }
        XCTAssertFalse(lazinessBroken)
        let _ = Array(result)
        XCTAssert(lazinessBroken)
    }

    func testJoinedIndexing() {
        let contents = [
            joinedArrays[.left(0)],
            joinedArrays[.left(1)],
            joinedArrays[.left(2)],
            joinedArrays[.right(0)],
            joinedArrays[.right(1)],
            joinedArrays[.right(2)]
        ]
        XCTAssertEqual(contents, [1, 2, 3, 4, 5, 6])
    }

    func testStartIndex() {
        XCTAssertEqual(joinedArrays.startIndex, .left(0))
    }

    func testEndIndex() {
        XCTAssertEqual(joinedArrays.endIndex, .right(3))
    }

    func testIndexAfter() {
        // stardard left and right indices
        XCTAssertEqual(joinedArrays.index(after: .left(0)), .left(1))
        XCTAssertEqual(joinedArrays.index(after: .right(0)), .right(1))
        // moning between left and right indices
        XCTAssertEqual(joinedArrays.index(after: .left(2)), .right(0))
    }

    func testIndexBefore() {
        // standard left and right indices
        XCTAssertEqual(joinedArrays.index(before: .left(1)), .left(0))
        XCTAssertEqual(joinedArrays.index(before: .right(1)), .right(0))
        // moning between left and right indices
        XCTAssertEqual(joinedArrays.index(before: .right(0)), .left(2))
    }

    func testIndexOffsetBy() {
        // standard left and right indices
        XCTAssertEqual(joinedArrays.index(.left(0), offsetBy: 2), .left(2))
        XCTAssertEqual(joinedArrays.index(.right(0), offsetBy: 2), .right(2))
        XCTAssertEqual(joinedArrays.index(.left(2), offsetBy: -2), .left(0))
        XCTAssertEqual(joinedArrays.index(.right(2), offsetBy: -2), .right(0))

        // moving between left and right indices
        XCTAssertEqual(joinedArrays.index(.left(0), offsetBy: 5), .right(2))
        XCTAssertEqual(joinedArrays.index(.right(2), offsetBy: -5), .left(0))
    }

    func testDistanceFromTo() {
        // distance between same index side
        XCTAssertEqual(joinedArrays.distance(from: .left(0), to: .left(2)), 2)
        XCTAssertEqual(joinedArrays.distance(from: .right(0), to: .right(2)), 2)

        // distance between left and right indices
        XCTAssertEqual(joinedArrays.distance(from: .left(0), to: .right(2)), 5)
        XCTAssertEqual(joinedArrays.distance(
            from: .left(0), to: joinedArrays.endIndex), 6)
        XCTAssertEqual(joinedArrays.distance(from: .right(2), to: .left(0)), -5)
    }

    func testJoinNonHomegeneous() {
        let joined = array.joined(withNonHomogeneous: stringArray)
        let expected: [Either<Int, String>] = [
            .left(4),
            .left(5),
            .left(6),
            .right("oh"),
            .right("hi"),
            .right("there")
        ]
        XCTAssertEqual(Array(joined), expected)
    }

    func testJoinNonHomogeneous() {
        let joined = array.joined(withNonHomogeneous: stringArray)
        let expected: [Either<Int, String>] = [
            .left(4),
            .left(5),
            .left(6),
            .right("oh"),
            .right("hi"),
            .right("there")
        ]
        XCTAssertEqual(Array(joined), expected)
    }

    func testJoinNonHomogeneousLaziness() {
        var lazinessBroken = false
        let joined = array.lazy
            .map { (x: Int) -> Int in
                lazinessBroken = true
                return x
            }
            .joined(withNonHomogeneous: stringArray)
            .map { (x: Either<Int, String>) -> String in
                lazinessBroken = true
                return x.unwrapToRight {
                    String($0)
                }
            }
        XCTAssertFalse(lazinessBroken)
        XCTAssertEqual(Array(joined), ["4", "5", "6", "oh", "hi", "there"])
        XCTAssertTrue(lazinessBroken)
    }

    static let allTests = [
        ("testSameCollectionTypeJoin", testSameCollectionTypeJoin),
        ("testDisperateCollectionTypeJoin", testDisperateCollectionTypeJoin),
        ("testLaziness", testLaziness),
        ("testJoinedIndexing", testJoinedIndexing),
        ("testStartIndex", testStartIndex),
        ("testEndIndex", testEndIndex),
        ("testIndexAfter", testIndexAfter),
        ("testIndexBefore", testIndexBefore),
        ("testIndexOffsetBy", testIndexOffsetBy),
        ("testDistanceFromTo", testDistanceFromTo),
        ("testJoinNonHomogeneous", testJoinNonHomogeneous),
        ("testJoinNonHomogeneousLaziness", testJoinNonHomogeneousLaziness),
    ]
}
