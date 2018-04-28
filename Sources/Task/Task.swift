//
//  Task.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/9/18.
//  Copyright © 2018 Big Nerd Ranch. All rights reserved.
//

/// TODO documentation
public protocol TaskProtocol: FutureProtocol where Value: Either, Value.Left == Error {
    /// TODO documentation
    func cancel()

    /// TODO documentation
    var isCancelled: Bool { get }

    /// Returns a `Task` containing the result of mapping `transform` over the
    /// successful task's value.
    ///
    /// Mapping a task appends a unit of progress to the root task. A root task
    /// is the earliest, or parent-most, task in a tree of tasks.
    ///
    /// The resulting task is cancellable in the same way the receiving task is.
    func map<NewSuccessValue>(upon queue: Executor, transform: @escaping(Value.Right) throws -> NewSuccessValue) -> Task<NewSuccessValue>

    /// TODO documentation
    func andThen<Next: FutureProtocol>(upon executor: Executor, start startNextTask: @escaping(Value.Right) throws -> Next) -> Task<Next.Value>

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
    func andThen<Next: TaskProtocol>(upon executor: Executor, start startNextTask: @escaping(Value.Right) throws -> Next) -> Task<Next.Value.Right>

    /// TODO documentation
    func recover(upon executor: Executor, substituting substitution: @escaping(Error) throws -> Value.Right) -> Task<Value.Right>

    /// TODO documentation
    func fallback<Next: FutureProtocol>(upon executor: Executor, to restartTask: @escaping(Error) -> Next) -> Task<Value.Right> where Next.Value == Value.Right

    /// TODO documentation
    func fallback<Next: TaskProtocol>(upon executor: PreferredExecutor, to restartTask: @escaping(Error) -> Next) -> Task<Value.Right> where Next.Value.Right == Value.Right
}
