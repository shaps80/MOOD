//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Binary Parsing open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if !$Embedded && canImport(Foundation)
public import Foundation
#endif

/// A type that can be parsed from a `ParserSpan`.
///
/// Types that conform to `ExpressibleByParsing` automatically receive convenience
/// initializers that work with `Data`, arrays of bytes, and other common data
/// sources.
///
///     // Conformance:
///     extension QOI: ExpressibleByParsing {
///         public init(parsing input: inout ParserSpan) throws {
///             // Parsing implementation goes here!
///         }
///     }
///
///     // Usage:
///     let imageData = try Data(contentsOfFile: ...)
///     let qoiImage = try QOI(parsing: imageData)
public protocol ExpressibleByParsing {
    /// Parses a value by consuming bytes from a span.
    /// - Parameter input: Span advanced as bytes are consumed.
    /// - Throws: ``ThrownParsingError`` when bytes cannot form a valid value.
    init(parsing input: inout ParserSpan) throws(ThrownParsingError)
}

extension ExpressibleByParsing {
    /// Parses a value from a source capable of lending a parser span.
    /// - Parameter data: Source whose complete span is parsed.
    /// - Throws: ``ThrownParsingError`` when parsing fails.
    @_alwaysEmitIntoClient
    public init(
        parsing data: some ParserSpanProvider
    ) throws(ThrownParsingError) {
        self = try data.withParserSpan(Self.init(parsing:))
    }
    
    /// Parses a value from a contiguous random-access byte collection.
    /// - Parameter data: Byte collection to parse.
    /// - Throws: ``ThrownParsingError`` when storage is unavailable or parsing fails.
    @_alwaysEmitIntoClient
    @_disfavoredOverload
    public init(parsing data: some RandomAccessCollection<UInt8>)
    throws(ThrownParsingError)
    {
        guard
            let result = try data.withParserSpanIfAvailable({
                (span) throws(ThrownParsingError) in
                try Self.init(parsing: &span)
            })
        else {
            throw ParsingError(statusOnly: .invalidValue)
        }
        self = result
    }
}

extension RandomAccessCollection<UInt8> {
    /// Executes the given closure with a `ParserSpan` over the contents of this
    /// collection, if such a span is available.
    /// - Parameter body: Closure borrowing a mutable parser span.
    /// - Returns: The closure result, or `nil` when contiguous storage is unavailable.
    /// - Throws: ``ThrownParsingError`` propagated from `body`.
    @inlinable
    public func withParserSpanIfAvailable<T>(
        _ body: (inout ParserSpan) throws(ThrownParsingError) -> T
    ) throws(ThrownParsingError) -> T? {
#if !$Embedded && canImport(Foundation)
        if let data = self as? Foundation.Data {
            let result = unsafe data.withUnsafeBytes { buffer in
                var span = unsafe ParserSpan(_unsafeBytes: buffer)
                return Result<T, ThrownParsingError> { try body(&span) }
            }
            switch result {
            case .success(let t): return t
            case .failure(let e): throw e
            }
        }
#endif
        
        let result = self.withContiguousStorageIfAvailable { buffer in
            let rawBuffer = UnsafeRawBufferPointer(buffer)
            var span = unsafe ParserSpan(_unsafeBytes: rawBuffer)
            return Result<T, ThrownParsingError> { () throws(ThrownParsingError) in
                try body(&span)
            }
        }
        switch result {
        case .success(let t): return t
        case .failure(let e): throw e
        case nil: return nil
        }
    }
}

// MARK: ParserSpanProvider

/// A type that provides access to a `ParserSpan`.
public protocol ParserSpanProvider {
    /// Executes the given closure with a `ParserSpan` over the contents of this
    /// type.
    /// - Parameter body: Closure borrowing a mutable parser span.
    /// - Returns: The value returned by `body`.
    /// - Throws: Any error thrown by `body`.
    func withParserSpan<T, E>(
        _ body: (inout ParserSpan) throws(E) -> T
    ) throws(E) -> T
}

extension ParserSpanProvider {
#if !$Embedded
    /// Executes the given closure with a `ParserSpan` over the contents of this
    /// type, consuming the given parser range instead of the full span.
    /// - Parameters:
    ///   - range: Source-relative range consumed and updated to the resulting subspan range.
    ///   - body: Closure parsing within the selected range.
    /// - Returns: The value returned by `body`.
    /// - Throws: Any error from range validation or `body`.
    @_alwaysEmitIntoClient
    @inlinable
    public func withParserSpan<T>(
        usingRange range: inout ParserRange,
        _ body: (inout ParserSpan) throws -> T
    ) throws -> T {
        try withParserSpan { span in
            var subspan = try span.seeking(toRange: range)
            defer { range = subspan.parserRange }
            return try body(&subspan)
        }
    }
#endif
    
    /// Executes the given closure with a `ParserSpan` over the contents of this
    /// type, consuming the given parser range instead of the full span.
    /// - Parameters:
    ///   - range: Source-relative range consumed and updated to the resulting subspan range.
    ///   - body: Closure parsing within the selected range.
    /// - Returns: The value returned by `body`.
    /// - Throws: ``ParsingError`` from range validation or `body`.
    @_alwaysEmitIntoClient
    @inlinable
    public func withParserSpan<T>(
        usingRange range: inout ParserRange,
        _ body: (inout ParserSpan) throws(ParsingError) -> T
    ) throws(ParsingError) -> T {
        try withParserSpan { (span) throws(ParsingError) in
            var subspan = try span.seeking(toRange: range)
            defer { range = subspan.parserRange }
            return try body(&subspan)
        }
    }
}

#if !$Embedded && canImport(Foundation)
extension Data: ParserSpanProvider {
    /// Lends a parser span over this data's bytes for the closure's duration.
    /// - Parameter body: Closure borrowing the span.
    /// - Returns: The value returned by `body`.
    /// - Throws: Any error thrown by `body`.
    @inlinable
    public func withParserSpan<T, E>(
        _ body: (inout ParserSpan) throws(E) -> T
    ) throws(E) -> T {
        let result = unsafe withUnsafeBytes { buffer in
            var span = unsafe ParserSpan(_unsafeBytes: buffer)
            return Result<T, E> { () throws(E) in try body(&span) }
        }
        switch result {
        case .success(let t): return t
        case .failure(let e): throw e
        }
    }
}
#endif

extension [UInt8]: ParserSpanProvider {
    /// Lends a parser span over this array's bytes for the closure's duration.
    /// - Parameter body: Closure borrowing the span.
    /// - Returns: The value returned by `body`.
    /// - Throws: Any error thrown by `body`.
    public func withParserSpan<T, E>(
        _ body: (inout ParserSpan) throws(E) -> T
    ) throws(E) -> T {
        let result = self.withUnsafeBytes { rawBuffer in
            var span = unsafe ParserSpan(_unsafeBytes: rawBuffer)
            return Result<T, E> { () throws(E) in try body(&span) }
        }
        switch result {
        case .success(let t): return t
        case .failure(let e): throw e
        }
    }
}

extension ArraySlice<UInt8>: ParserSpanProvider {
    /// Lends a parser span over this slice's bytes for the closure's duration.
    /// - Parameter body: Closure borrowing the span.
    /// - Returns: The value returned by `body`.
    /// - Throws: Any error thrown by `body`.
    public func withParserSpan<T, E>(
        _ body: (inout ParserSpan) throws(E) -> T
    ) throws(E) -> T {
        let result = self.withUnsafeBytes { rawBuffer in
            var span = unsafe ParserSpan(_unsafeBytes: rawBuffer)
            return Result<T, E> { () throws(E) in try body(&span) }
        }
        switch result {
        case .success(let t): return t
        case .failure(let e): throw e
        }
    }
}
