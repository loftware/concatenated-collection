import LoftDataStructures_Either

/// A `Sequence` that contains all of the elements contained in one `Sequence`
/// followed by all the elements of a second `Sequence`.
///
/// Like `FlattenSequence`, `ConcatenatedSequence` is always lazy, but does not
/// implicitely confer lazyness on algorithms applied to its result. In other
/// words, for ordinary sequences `s`:
///
/// * `a.joined(with: b)` does not create new storage
/// * `a.joined(with: b).map(f)` maps eagerly and returns a new array
/// * `a.lazy.joined(with: b).map(f)` maps lazily and returns a
///   `LazyMapSequence`.
@frozen
public struct ConcatenatedSequence<
  First: Sequence,
  Second: Sequence
> where First.Element == Second.Element {
  private let first: First
  private let second: Second

  /// Creates a concatenation of the given sequences in the order `first`,
  /// `second`.
  ///
  /// - Complexity: O(1)
  internal init(_ first: First, then second: Second) {
    self.first = first
    self.second = second
  }
}

extension ConcatenatedSequence {
  public struct Iterator {
    private var first: First.Iterator
    private var second: Second.Iterator

    /// Construct an iterator over the elements of the `first`, then
    /// `second`, sequences.

    fileprivate init(
      _ first: First.Iterator,
      then second: Second.Iterator
    ) {
      self.first = first
      self.second = second
    }
  }
}

extension ConcatenatedSequence.Iterator: IteratorProtocol, Sequence {
  public mutating func next() -> First.Element? {
    return first.next() ?? second.next()
  }
}

extension ConcatenatedSequence: Sequence {
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
  /// non-homogenous sequence concatination, see `joined(withNonHomogenous:)`.
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
  public func joined<Other: Sequence>(with other: Other)
    -> ConcatenatedSequence<Self, Other> where Self.Element == Other.Element {
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
  public func joined<Other: Sequence>(withNonHomogeneous other: Other)
    -> ConcatenatedSequence<
  LazyMapSequence<Self, Either<Self.Element, Other.Element>>,
  LazyMapSequence<Other, Either<Self.Element, Other.Element>>
    > {
    let lSeq = self.lazy
      .map { Either<Self.Element, Other.Element>.left($0) }
    let rSeq = other.lazy
      .map { Either<Self.Element, Other.Element>.right($0) }
    return ConcatenatedSequence(lSeq, then: rSeq)
  }
}

public typealias LazyConcatenatedEitherSequence<
  Left: LazySequenceProtocol,
  Right: Sequence
> = LazySequence<ConcatenatedSequence<
LazyMapSequence<Left.Elements, Either<Left.Element, Right.Element>>,
LazyMapSequence<Right, Either<Left.Element, Right.Element>>
                 >>

                 extension LazySequenceProtocol {
  /// Returns a lazy sequence containing the elements of this sequence,
  /// followed by the elements of the `other` sequence.
  ///
  /// Order is guaranteed to be preserved for sequences that produce their
  /// elements in a specific order.
  public func joined<Other: Sequence>(
    with other: Other
  ) -> LazySequence<ConcatenatedSequence<Self, Other>>
    where Self.Element == Other.Element {
    return ConcatenatedSequence(self, then: other).lazy
  }

  /// Returns a lazy sequence of `Either`s containing `.left`s of the elements
  /// of this sequence, followed by `.right`s of the elements of the `other`
  /// sequence.
  ///
  /// Order is guaranteed to be preserved for sequences that produce their
  /// elements in a specific order.
  public func joined<Other: Sequence>(withNonHomogeneous other: Other)
    -> LazyConcatenatedEitherSequence<Self, Other> {
    let lSeq = self.map { Either<Self.Element, Other.Element>.left($0) }
    let rSeq = other.lazy.map {
      Either<Self.Element, Other.Element>.right($0)
    }
    return ConcatenatedSequence(lSeq, then: rSeq).lazy
  }
}

public typealias ConcatenatedCollection<
  First: Collection,
  Second: Collection
> = ConcatenatedSequence<First, Second> where First.Element == Second.Element

extension ConcatenatedCollection: Collection {
  public typealias Index = Either<First.Index, Second.Index>

  public var startIndex: Index {
    normalize(.left(first.startIndex))
  }

  public var endIndex: Index {
    .right(second.endIndex)
  }

  private func normalize(_ i: Index) -> Index {
    if case .left(let l) = i, l == first.endIndex { return .right(second.startIndex) }
    return i
  }

  public func index(after i: Index) -> Index {
    switch i {
    case .left(var l):
      first.formIndex(after: &l)
      return normalize(.left(l))
    case .right(let r):
      return .right(second.index(after: r))
    }
  }

  public subscript(position: Index) -> Element {
    switch position {
    case .left(let l): return first[l]
    case .right(let r): return second[r]
    }
  }

  public func distance(from start: Index, to end: Index) -> Int {
    switch (start, end) {
    case let (.left(start), .left(end)):
      return first.distance(from: start, to: end)
    case let (.right(start), .right(end)):
      return second.distance(from: start, to: end)
    case let (.left(start), .right(end)):
      return first.distance(from: start, to: first.endIndex) +
        second.distance(from: second.startIndex, to: end)
    case let (.right(start), .left(end)):
      return -(second.distance(from: second.startIndex, to: start) +
                 first.distance(from: end, to: first.endIndex))
    }
  }

  public func index(_ i: Index, offsetBy distance: Int) -> Index {
    var n = distance
    switch i {
    case .left(var l):
      // If the distance isn't positive, there's no need to check if the
      // resulting index is in the second collection.
      if n <= 0 {
        return .left(first.index(l, offsetBy: n))
      }

      if first is any RandomAccessCollection {
        let m = first.distance(from: l, to: first.endIndex)
        if m > n { return .left(first.index(l, offsetBy: n)) }
        n -= m
      }
      else {
        while n != 0 && l != first.endIndex {
          n -= 1
          first.formIndex(after: &l)
        }
        if l != first.endIndex { return .left(l) }
      }
      return .right(second.index(second.startIndex, offsetBy: n))

    case .right(var r):
      // If the distance isn't negative, there's no need to check if the
      // resulting index is in the first collection.
      if n >= 0 {
        return .right(second.index(r, offsetBy: n))
      }

      if second is any RandomAccessCollection {
        let m = second.distance(from: r, to: second.startIndex)
        if m <= n { return .right(second.index(r, offsetBy: n)) }
        n -= m
      }
      else {
        while n != 0 && r != second.startIndex {
          n += 1
          r = second.index(r, offsetBy: -1)
        }
        if n == 0 { return .right(r) }
      }
      return .left(first.index(first.endIndex, offsetBy: n))
    }
  }

  public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
    var n = distance

    switch i {
    case .left(var l):
      // If the distance isn't positive, there's no need to check if the
      // resulting index is in the second collection.
      if n <= 0 {
        return first.index(l, offsetBy: n, limitedBy: limit.left ?? first.startIndex)
          .map { .left($0) }
      }

      if first is any RandomAccessCollection {
        let m = first.distance(from: l, to: first.endIndex)
        if m > n || limit.left != nil {
          return first.index(l, offsetBy: n, limitedBy: limit.left ?? first.endIndex)
            .map { .left($0) }
        }
        n -= m
      }
      else {
        while n != 0 && l != first.endIndex && .left(l) != limit {
          n -= 1
          first.formIndex(after: &l)
        }
        if l != first.endIndex {
          if n != 0 { return nil }
          return .left(l)
        }
      }
      return second.index(second.startIndex, offsetBy: n, limitedBy: limit.right ?? second.endIndex)
        .map { .right($0) }

    case .right(var r):
      // If the distance isn't negative, there's no need to check if the
      // resulting index is in the first collection.
      if n >= 0 {
        return second.index(r, offsetBy: n, limitedBy: limit.right ?? second.endIndex)
          .map { .right($0) }
      }
      if second is any RandomAccessCollection {
        let m = second.distance(from: r, to: second.startIndex)
        if m <= n || limit.right != nil {
          return second.index(r, offsetBy: n, limitedBy: limit.right ?? second.startIndex)
            .map { .right($0) }
        }
        n -= m
      }
      else {
        while n != 0 && r != second.startIndex && .right(r) != limit {
          n += 1
          r = second.index(r, offsetBy: -1)
        }
        if n == 0 {
          return .right(r)
        }
        if r != second.startIndex {
          return nil
        }
      }
      return first.index(first.endIndex, offsetBy: n, limitedBy: limit.left ?? first.startIndex)
        .map { .left($0) }
    }
  }
}

extension ConcatenatedCollection: BidirectionalCollection
  where First: BidirectionalCollection, Second: BidirectionalCollection {
  public func index(before i: Index) -> Index {
    switch i {
    case .left(let l):
      return .left(first.index(before: l))
    case .right(let r):
      if r == second.startIndex {
        return .left(first.index(before: first.endIndex))
      }
      return .right(second.index(before: r))
    }
  }
}

// If the two wrapped collections provide O(1) index(_:offsetBy:) and
// distance(from:to:) implementations (they conform to
// `RandomAccessCollection`), our implementations are O(1) as well, so we can
// also provide `RandomAccessCollection` conformance.
extension ConcatenatedCollection: RandomAccessCollection
  where First: RandomAccessCollection, Second: RandomAccessCollection {}
