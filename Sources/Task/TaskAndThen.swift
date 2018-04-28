//
//  TaskAndThen.swift
//  Deferred
//
//  Created by Zachary Waldowski on 10/27/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif

import Dispatch

extension TaskProtocol {
    /// TODO documentation
    public func andThen<Next: FutureProtocol>(upon queue: PreferredExecutor, start startNextTask: @escaping(Value.Right) throws -> Next) -> Task<Next.Value> {
        return andThen(upon: queue as Executor, start: startNextTask)
    }

    /// TODO documentation
    public func andThen<Next: FutureProtocol>(upon executor: Executor, start startNextTask: @escaping(Value.Right) throws -> Next) -> Task<Next.Value> {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = incrementedProgress()
        #else
        let cancellationToken = Deferred<Void>()
        #endif

        typealias Result = Task<Next.Value>.Result

        let future = andThen(upon: executor) { (result) -> Future<Result> in
            do {
                let value = try result.extract()

                #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
                // We want to become the thread-local progress, but we don't
                // want to consume units; we may not attach newTask.progress to
                // the root progress until after the scope ends.
                progress.becomeCurrent(withPendingUnitCount: 0)
                defer { progress.resignCurrent() }
                #endif

                // Attempt to create and wrap the next task. Task's own progress
                // wrapper logic takes over at this point.
                let newTask = try startNextTask(value)
                #if !os(macOS) && !os(iOS) && !os(tvOS) && !os(watchOS)
                cancellationToken.upon(DispatchQueue.any(), execute: newTask.cancel)
                #endif
                return Future(success: newTask)
            } catch {
                #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
                // Failure case behaves just like map: just error passthrough.
                progress.becomeCurrent(withPendingUnitCount: 1)
                defer { progress.resignCurrent() }
                #endif

                return Future(failure: error)
            }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task(future: future, progress: progress)
        #else
        return Task(future: future) {
            cancellationToken.fill(with: ())
        }
        #endif
    }

    /// Begins another task by passing the result of the task to `startNextTask`
    /// once it completes successfully.
    ///
    /// Chaining a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// Cancelling the resulting task will attempt to cancel both the receiving
    /// task and the created task.
    public func andThen<Next: TaskProtocol>(upon executor: PreferredExecutor, start startNextTask: @escaping(Value.Right) throws -> Next) -> Task<Next.Value.Right> {
        return andThen(upon: executor as Executor, start: startNextTask)
    }

    /// Begins another task by passing the result of the task to `startNextTask`
    /// once it completes successfully.
    ///
    /// Chaining a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// Cancelling the resulting task will attempt to cancel both the receiving
    /// task and the created task.
    ///
    /// - note: It is important to keep in mind the thread safety of the
    /// `startNextTask` closure. `andThen` submits `startNextTask` to `executor`
    /// once the task completes successfully.
    /// - see: FutureProtocol.andThen(upon:start:)
    public func andThen<Next: TaskProtocol>(upon executor: Executor, start startNextTask: @escaping(Value.Right) throws -> Next) -> Task<Next.Value.Right> {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let progress = incrementedProgress()
        #else
        let cancellationToken = Deferred<Void>()
        #endif

        typealias Result = Task<Next.Value.Right>.Result

        let future = andThen(upon: executor) { (result) -> Future<Result> in
            do {
                let value = try result.extract()

                #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
                // We want to become the thread-local progress, but we don't
                // want to consume units; we may not attach newTask.progress to
                // the root progress until after the scope ends.
                progress.becomeCurrent(withPendingUnitCount: 0)
                defer { progress.resignCurrent() }
                #endif

                // Attempt to create and wrap the next task. Task's own progress
                // wrapper logic takes over at this point.
                let newTask = try startNextTask(value)
                #if !os(macOS) && !os(iOS) && !os(tvOS) && !os(watchOS)
                cancellationToken.upon(DispatchQueue.any(), execute: newTask.cancel)
                #endif
                return Future(task: newTask)
            } catch {
                #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
                // Failure case behaves just like map: just error passthrough.
                progress.becomeCurrent(withPendingUnitCount: 1)
                defer { progress.resignCurrent() }
                #endif

                return Future(value: .failure(error))
            }
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Task(future: future, progress: progress)
        #else
        return Task(future: future) {
            cancellationToken.fill(with: ())
        }
        #endif
    }
}
