//
//  TaskFallback.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2018 Big Nerd Ranch. Licensed under MIT.
//
#if SWIFT_PACKAGE
import Deferred
#endif
import Foundation

extension TaskProtocol {
    /// TODO documentation
    public func fallback<Next: FutureProtocol>(upon queue: PreferredExecutor, to restartTask: @escaping(Error) -> Next) -> Task<Value.Right> where Next.Value == Value.Right {
        return fallback(upon: queue as Executor, to: restartTask)
    }

    /// TODO documentation
    public func fallback<Next: FutureProtocol>(upon executor: Executor, to restartTask: @escaping(Error) -> Next) -> Task<Value.Right> where Next.Value == Value.Right {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = incrementedProgress()
        #endif

        typealias Result = Task<Value.Right>.Result

        let future = andThen(upon: executor) { (result) -> Future<Value.Right> in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            progress.becomeCurrent(withPendingUnitCount: 1)
            defer { progress.resignCurrent() }
            #endif

            do {
                let value = try result.extract()
                return Future(value: value)
            } catch {
                return Future(restartTask(error))
            }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task(success: future, progress: progress)
        #else
        return Task(success: future, cancellation: cancel)
        #endif
    }

    /// Begins another task in the case of the failure of `self` by calling
    /// `restartTask` with the error.
    ///
    /// Chaining a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// Cancelling the resulting task will attempt to cancel both the receiving
    /// task and the created task.
    public func fallback<Next: TaskProtocol>(upon executor: PreferredExecutor, to restartTask: @escaping(Error) -> Next) -> Task<Value.Right> where Next.Value.Right == Value.Right {
        return fallback(upon: executor as Executor, to: restartTask)
    }

    /// Begins another task in the case of the failure of `self` by calling
    /// `restartTask` with the error.
    ///
    /// Chaining a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// Cancelling the resulting task will attempt to cancel both the receiving
    /// task and the created task.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `restartTask` closure. `fallback` submits `restartTask` to `executor`
    /// once the task fails.
    /// - see: FutureProtocol.andThen(upon:start:)
    public func fallback<Next: TaskProtocol>(upon executor: Executor, to restartTask: @escaping(Error) -> Next) -> Task<Value.Right> where Next.Value.Right == Value.Right {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = incrementedProgress()
        #endif

        typealias Result = Task<Next.Value.Right>.Result

        let future = andThen(upon: executor) { (result) -> Future<Result> in
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            progress.becomeCurrent(withPendingUnitCount: 1)
            defer { progress.resignCurrent() }
            #endif

            do {
                let value = try result.extract()
                return Future(success: value)
            } catch {
                return Future(task: restartTask(error))
            }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task(future: future, progress: progress)
        #else
        return Task(future: future, cancellation: cancel)
        #endif
    }
}
