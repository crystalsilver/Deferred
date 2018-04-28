//
//  TaskIgnore.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/15/16.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
#endif

extension TaskProtocol {
    /// TODO documentation.
    public func every<NewSuccessValue>(per eachUseTransform: @escaping(Value.Right) -> NewSuccessValue) -> Task<NewSuccessValue> {
        let future = every { (result) -> Task<NewSuccessValue>.Result in
            result.withValues(ifLeft: Task<NewSuccessValue>.Result.failure, ifRight: { .success(eachUseTransform($0)) })
        }

        return Task(future)
    }
}

extension TaskProtocol {
    /// Returns a task that ignores the successful completion of this task.
    ///
    /// This is semantically identical to the following:
    ///
    ///     myTask.map { _ in }
    ///
    /// But behaves more efficiently.
    ///
    /// The resulting task is cancellable in the same way the receiving task is.
    ///
    /// - see: map(transform:)
    public func ignored() -> Task<Void> {
        return every { _ in }
    }
}
