import Either

/// A sequence consisting of all of the elements contained in each of the two
/// underlying sequences.
///
/// Like `FlattenSequence`, `ConcatenatedSequence` is always lazy, but does
/// not implicitely confer lazyness on algorithms applied to its result. In
/// other words, for ordinary sequences `s`:
///
/// * `a.joined(with: b)` does not create new storage
/// * `a.joined(with: b).map(f)` maps eagerly and returns a new array
/// * `a.lazy.joined(with: b).map(f)` maps lazily and returns a
///   `LazyMapSequence`.
@frozen // lazy-performance
public struct ConcatenatedSequence<
    First: Sequence,
    Second: Sequence
> where First.Element == Second.Element {
    @usableFromInline // lazy-performance
    internal let first: First
    @usableFromInline // lazy-performance
    internal let second: Second

    /// Creates a concatenation of the given sequences in the order `first`,
    /// `second`.
    ///
    /// - Complexity: O(1)
    @inlinable // lazy-performance
    internal init(_ first: First, then second: Second) {
        self.first = first
        self.second = second
    }
}

extension ConcatenatedSequence {
    @frozen // lazy-performance
    public struct Iterator {
        // We use a flag here to avoid repeatedly calling next on the first
        // iterator in case its implementation is particularly expensive.
        @usableFromInline
        internal var completedFirst = false
        @usableFromInline // lazy-performance
        internal var first: First.Iterator
        @usableFromInline // lazy-performance
        internal var second: Second.Iterator

        /// Construct an iterator over the elements of the `first`, then
        /// `second`, sequences.
        @inlinable // lazy-performance
        internal init(_ first: First.Iterator, then second: Second.Iterator) {
            self.first = first
            self.second = second
        }
    }
}

extension ConcatenatedSequence.Iterator: IteratorProtocol, Sequence {
    @inlinable // lazy-performance
    public mutating func next() -> First.Element? {
        if !completedFirst {
            if let nextElement = first.next() {
                return nextElement
            }
            completedFirst = true
        }
        return second.next()
    }
}

extension ConcatenatedSequence: Sequence {
    @inlinable // lazy-performance
    public func makeIterator() -> Iterator {
        return Iterator(first.makeIterator(), then: second.makeIterator())
    }
}

extension Sequence {
    /// Returns a sequence containing the elements of this sequence,
    /// followed by the elements of the `other` sequence.
    ///
    /// Order is guaranteed to be preserved for sequences that produce their
    /// elements in a specific order.
    ///
    /// This differs from `Array.append(contentsOf:)` in that it can be applied
    /// to any sequence types, and supports the concatenation of disperate
    /// sequence types (as long as their elements are homogenous, for
    /// non-homogenous sequence concatination, see `joined(withNonHomegenous:)`.
    ///
    /// In this example, an array of numbers is concatenated with a set of
    /// numbers.
    ///
    ///     let first: Set<Int> = [1, 2]
    ///     let second: Set<Int> = [3, 4]
    ///     for number in first.joined(with: second) {
    ///         print(number)
    ///     }
    ///     // Prints "1" then, "2" then, "3", then "4"
    ///
    /// - Returns: A concatenation of the elements of this set, and the given
    ///   `other` set.
    @inlinable // lazy-performance
    public func joined<Other: Sequence>(with other: Other)
    -> some Sequence where Self.Element == Other.Element {
        return ConcatenatedSequence(self, then: other)
    }

    /// Returns a sequence of `Either`s containing `.left`s of the elements of
    /// this sequence, followed by `.right`s of the elements of the `other`
    /// sequence.
    ///
    /// Order is guaranteed to be preserved for sequences that produce their
    /// elements in a specific order.
    ///
    /// In this example, an array of numbers is concatenated with a set of
    /// strings.
    ///
    ///     let first: Array<Int> = [1]
    ///     let second: Set<String> = ["hello"]
    ///     for value in first.joined(withNonHomegenous: second) {
    ///         print(value)
    ///     }
    ///     // Prints "Either<Int,String>(left(1))" then
    ///     // "Either<Int,String>(right("hello"))"
    ///
    /// - Returns: A concatenation of the elements of this set, and the given
    ///   `other` set.
    @inlinable // lazy-performance
    public func joined<Other: Sequence>(withNonHomegeneous other: Other)
    -> some Sequence {
        let lSeq = self.map { Either($0, or: Other.Element.self) }
        let rSeq = other.map { Either(right: $0, orLeft: Self.Element.self) }
        return ConcatenatedSequence(lSeq, then: rSeq)
    }
}

extension LazySequenceProtocol {
    /// Returns a lazy sequence containing the elements of this sequence,
    /// followed by the elements of the `other` sequence.
    ///
    /// Order is guaranteed to be preserved for sequences that produce their
    /// elements in a specific order.
    @inlinable // lazy-performance
    public func joined<Other: Sequence>(with other: Other)
    -> some LazySequenceProtocol where Self.Element == Other.Element {
        return ConcatenatedSequence(self, then: other).lazy
    }

    /// Returns a lazy sequence of `Either`s containing `.left`s of the elements
    /// of this sequence, followed by `.right`s of the elements of the `other`
    /// sequence.
    ///
    /// Order is guaranteed to be preserved for sequences that produce their
    /// elements in a specific order.
    @inlinable // lazy-performance
    public func joined<Other: Sequence>(withNonHomegeneous other: Other)
    -> some LazySequenceProtocol {
        let lSeq = self.lazy.map { Either($0, or: Other.Element.self) }
        let rSeq = other.lazy.map {
            Either(right: $0, orLeft: Self.Element.self)
        }
        return ConcatenatedSequence(lSeq, then: rSeq).lazy
    }
}