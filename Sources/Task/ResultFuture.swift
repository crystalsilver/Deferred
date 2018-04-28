//
//  ResultFuture.swift
//  Deferred
//
//  Created by Zachary Waldowski on 12/26/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif
import Dispatch

extension FutureProtocol where Value: Either, Value.Left == Error {
    /// Call some `body` closure if the future successfully resolves a value.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A closure that uses the determined success value.
    /// - see: upon(_:execute:)
    public func uponSuccess(on executor: Executor, execute body: @escaping(Value.Right) -> Void) {
        upon(executor) { (result) in
            result.withValues(ifLeft: { _ in }, ifRight: body)
        }
    }

    /// Call some `body` closure if the future successfully resolves a value.
    ///
    /// - see: uponSuccess(on:execute:)
    /// - see: upon(_:execute:)
    public func uponSuccess(on executor: PreferredExecutor = Self.defaultUponExecutor, execute body: @escaping(Value.Right) -> Void) {
        upon(executor) { (result) in
            result.withValues(ifLeft: { _ in }, ifRight: body)
        }
    }

    /// Call some `body` closure if the future produces an error.
    ///
    /// - parameter executor: A context for handling the `body` on fill.
    /// - parameter body: A closure that uses the determined failure value.
    /// - see: upon(_:execute:)
    public func uponFailure(on executor: Executor, execute body: @escaping(Value.Left) -> Void) {
        upon(executor) { result in
            result.withValues(ifLeft: body, ifRight: { _ in })
        }
    }

    /// Call some `body` closure if the future produces an error.
    ///
    /// - see: uponFailure(on:execute:)
    /// - see: upon(_:body:)
    public func uponFailure(on executor: PreferredExecutor = Self.defaultUponExecutor, execute body: @escaping(Value.Left) -> Void) {
        upon(executor) { result in
            result.withValues(ifLeft: body, ifRight: { _ in })
        }
    }
}

extension Future where Value: Either, Value.Left == Error {
    /// Create a future having the same underlying task as `other`.
    public init<Other: FutureProtocol>(task other: Other)
        where Other.Value: Either, Other.Value.Left == Value.Left, Other.Value.Right == Value.Right {
        if let asSelf = other as? Future<Value> {
            self.init(asSelf)
        } else {
            self.init(other.every {
                Value(from: $0.extract)
            })
        }
    }

    /// Create a future having the same underlying task as `other`.
    public init<Other: FutureProtocol>(success other: Other)
        where Other.Value == Value.Right {
        self.init(other.every {
            Value(success: $0)
        })
    }

    /// TODO documentation
    public init(success getValue: @autoclosure() throws -> Value.Right) {
        self.init(value: Value(from: getValue))
    }

    /// TODO documentation
    public init(failure error: Error) {
        self.init(value: Value(failure: error))
    }
}
