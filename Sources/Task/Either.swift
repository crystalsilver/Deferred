//
//  Either.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/9/15.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

/// A type that represents values with two possibilities.
public protocol Either: CustomStringConvertible {
    /// One of the two possible results.
    ///
    /// By convention, the left side is used to hold an error value.
    associatedtype Left = Error

    /// One of the two possible results.
    ///
    /// By convention, the right side is used to hold a correct value.
    associatedtype Right

    /// Derive a result from a failable function.
    init(from body: () throws -> Right)

    /// Creates a failed result with `error`.
    init(failure: Left)

    /// Case analysis.
    ///
    /// Returns the value from the `failure` closure if `self` represents a
    /// failure, or from the `success` closure if `self` represents a success.
    func withValues<Return>(ifLeft left: (Left) throws -> Return, ifRight right: (Right) throws -> Return) rethrows -> Return
}

extension Either {
    public var description: String {
        return withValues(ifLeft: { String(describing: $0) }, ifRight: { String(describing: $0) })
    }
}
