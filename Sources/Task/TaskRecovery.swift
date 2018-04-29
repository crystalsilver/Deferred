//
//  TaskRecovery.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif
import Foundation

extension TaskProtocol {
    /// Returns a `Task` containing the result of mapping `substitution` over
    /// the failed task's error.
    ///
    /// Recovering from a failed task appends a unit of progress to the root
    /// task. A root task is the earliest, or parent-most, task in a tree.
    ///
    /// The resulting task is cancellable in the same way the receiving task is.
    public func recover(upon executor: PreferredExecutor, substituting substitution: @escaping(Error) throws -> Value.Right) -> Task<Value.Right> {
        return recover(upon: executor as Executor, substituting: substitution)
    }

    /// Returns a `Task` containing the result of mapping `substitution` over
    /// the failed task's error.
    ///
    /// `recover` submits the `substitution` to the `executor` once the task
    /// fails.
    ///
    /// Recovering from a failed task appends a unit of progress to the root
    /// task. A root task is the earliest, or parent-most, task in a tree.
    ///
    /// The resulting task is cancellable in the same way the receiving task is.
    ///
    /// - see: FutureProtocol.map(upon:transform:)
    public func recover(upon executor: Executor, substituting substitution: @escaping(Error) throws -> Value.Right) -> Task<Value.Right> {
        typealias Result = Task<Value.Right>.Result

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = incrementedProgress()
        #endif

        let future: Future<Task<Value.Right>.Result> = map(upon: executor) { (result) in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            progress.becomeCurrent(withPendingUnitCount: 1)
            defer { progress.resignCurrent() }
            #endif

            return Result {
                try result.withValues(ifLeft: { try substitution($0) }, ifRight: { $0 })
            }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task<Value.Right>(future: future, progress: progress)
        #else
        return Task<Value.Right>(future: future, cancellation: cancel)
        #endif
    }
}
