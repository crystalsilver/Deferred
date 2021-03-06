//
//  TaskProgress.swift
//  Deferred
//
//  Created by Zachary Waldowski on 8/19/16.
//  Copyright © 2016-2018 Big Nerd Ranch. Licensed under MIT.
//

import Foundation
#if SWIFT_PACKAGE
import Atomics
import Deferred
#elseif COCOAPODS
import Atomics
#elseif XCODE && !FORCE_PLAYGROUND_COMPATIBILITY
import Deferred.Atomics
#endif

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
/// A progress object whose attributes reflect that of an external progress
/// tree.
private final class ProxyProgress: Progress {

    @objc dynamic private let observee: Progress
    private var token: Observation?

    init(attachingTo observee: Progress) {
        self.observee = observee
        super.init(parent: .current(), userInfo: nil)
        token = Observation(observing: observee, observer: self)
    }

    deinit {
        token?.invalidate(observing: observee)
    }

    private func inheritCancelled() {
        if observee.isCancelled {
            super.cancel()
        }
    }

    private func inheritPaused() {
        if observee.isPaused {
            super.pause()
        } else if #available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *) {
            super.resume()
        }
    }

    private func inheritValue(forKeyPath keyPath: String?) {
        guard let keyPath = keyPath else { return }
        setValue(observee.value(forKeyPath: keyPath), forKeyPath: keyPath)
    }

    // MARK: - Derived values

    override func cancel() {
        observee.cancel()
    }

    override func pause() {
        observee.pause()
    }

    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    override func resume() {
        observee.resume()
    }

    @objc static var keyPathsForValuesAffectingUserInfo: Set<String> {
        return [ #keyPath(observee.userInfo) ]
    }

    override var userInfo: [ProgressUserInfoKey: Any] {
        return observee.userInfo
    }

    override func setUserInfoObject(_ objectOrNil: Any?, forKey key: ProgressUserInfoKey) {
        observee.setUserInfoObject(objectOrNil, forKey: key)
    }

    // MARK: - KVO babysitting

    /// A side-table object to weakify the progress observer and prevent
    /// delivery of notifications after deinit.
    private final class Observation: NSObject {
        private static var cancelledContext = false
        private static var pausedContext = false
        private static var attributesContext = false
        private static let attributes = [
            #keyPath(Progress.completedUnitCount),
            #keyPath(Progress.totalUnitCount),
            #keyPath(Progress.localizedDescription),
            #keyPath(Progress.localizedAdditionalDescription),
            #keyPath(Progress.cancellable),
            #keyPath(Progress.pausable),
            #keyPath(Progress.kind)
        ]

        private struct State: OptionSet {
            let rawValue: UInt8
            static let ready = State(rawValue: 1 << 0)
            static let observing = State(rawValue: 1 << 1)
            static let cancellable: State = [.ready, .observing]
            static let cancelled = State(rawValue: 1 << 2)
        }

        private var state = UInt8() // see State
        private weak var observer: ProxyProgress?

        init(observing observee: Progress, observer: ProxyProgress) {
            self.observer = observer
            bnr_atomic_init(&state, State.ready.rawValue)
            super.init()
            activate(observing: observee)
        }

        func activate(observing observee: Progress) {
            for key in Observation.attributes {
                observee.addObserver(self, forKeyPath: key, options: .initial, context: &Observation.attributesContext)
            }
            observee.addObserver(self, forKeyPath: #keyPath(Progress.cancelled), options: .initial, context: &Observation.cancelledContext)
            observee.addObserver(self, forKeyPath: #keyPath(Progress.paused), options: .initial, context: &Observation.pausedContext)

            bnr_atomic_fetch_or(&state, State.observing.rawValue, .release)
        }

        func invalidate(observing observee: Progress) {
            let oldState = State(rawValue: bnr_atomic_fetch_and(&state, ~State.ready.rawValue, .relaxed))
            guard !oldState.isStrictSuperset(of: .cancellable) else { return }
            bnr_atomic_fetch_or(&state, State.cancelled.rawValue, .relaxed)

            for key in Observation.attributes {
                observee.removeObserver(self, forKeyPath: key, context: &Observation.attributesContext)
            }
            observee.removeObserver(self, forKeyPath: #keyPath(Progress.cancelled), context: &Observation.cancelledContext)
            observee.removeObserver(self, forKeyPath: #keyPath(Progress.paused), context: &Observation.pausedContext)
        }

        override func observeValue(forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            let state = State(rawValue: bnr_atomic_load(&self.state, .relaxed))
            guard state.contains(.ready), let observer = observer else { return }
            // This would be prettier as a switch.
            // https://bugs.swift.org/browse/SR-7877
            if context == &Observation.cancelledContext {
                observer.inheritCancelled()
            } else if context == &Observation.pausedContext {
                observer.inheritPaused()
            } else if context == &Observation.attributesContext {
                observer.inheritValue(forKeyPath: keyPath)
            }
        }
    }
}

extension Progress {
    /// Attempt a backwards-compatible implementation of iOS 9's explicit
    /// progress handling. It's not perfect; this is a best effort of proxying
    /// an external progress tree.
    ///
    /// If `progress` may possibly already have a parent,
    /// send `orphaned: false`, using similar behavior to the backwards-
    /// compatible path.
    @discardableResult
    func adoptChild(_ progress: Progress, orphaned canAdopt: Bool, pendingUnitCount: Int64) -> Progress {
        if #available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *), canAdopt {
            addChild(progress, withPendingUnitCount: pendingUnitCount)
            return progress
        } else {
            let changedPendingUnitCount = Progress.current() === self
            if changedPendingUnitCount {
                resignCurrent()
            }

            becomeCurrent(withPendingUnitCount: pendingUnitCount)

            let progress = ProxyProgress(attachingTo: progress)

            if !changedPendingUnitCount {
                resignCurrent()
            }

            return progress
        }
    }
}

// MARK: - Convenience initializers

extension Progress {
    /// Indeterminate progress which will likely not change.
    static func indefinite() -> Progress {
        let progress = Progress(totalUnitCount: -1)
        progress.isCancellable = false
        return progress
    }

    /// Progress for which no work actually needs to be done.
    static func noWork() -> Progress {
        let progress = Progress(totalUnitCount: 0)
        progress.completedUnitCount = 1
        progress.isCancellable = false
        progress.isPausable = false
        return progress
    }

    /// A simple indeterminate progress with a cancellation function.
    static func wrappingCompletion<OtherFuture: FutureProtocol>(of base: OtherFuture, cancellation: (() -> Void)?) -> Progress {
        let totalUnitCount: Int64 = base.wait(until: .now()) != nil ? 0 : -1
        let progress = Progress(totalUnitCount: totalUnitCount)

        if let cancellation = cancellation {
            progress.cancellationHandler = cancellation
        } else {
            progress.isCancellable = false
        }

        base.upon(.global(qos: .utility)) { _ in
            progress.totalUnitCount = 1
            progress.completedUnitCount = 1
        }

        return progress
    }

    /// A simple indeterminate progress with a cancellation function.
    static func wrappingSuccess<OtherTask: FutureProtocol>(of base: OtherTask, cancellation: (() -> Void)?) -> Progress
        where OtherTask.Value: Either {
        switch (base as? Task<OtherTask.Value.Right>, cancellation) {
        case (let task?, nil):
            return task.progress
        case (let task?, let cancellation?):
            let progress = Progress(totalUnitCount: 1)
            progress.cancellationHandler = cancellation
            progress.adoptChild(task.progress, orphaned: false, pendingUnitCount: 1)
            return progress
        default:
            return .wrappingCompletion(of: base, cancellation: cancellation)
        }
    }
}

// MARK: - Task chaining

/**
 Both Task<Value> and NSProgress operate compose over implicit trees, but their
 ordering is reversed. You call map or flatMap on a Task to schedule follow-up
 work, which looks a lot like chaining; a progress tree has a parent-child
 approach. These are compatible: Task adopts progress instances given to it,
 creating a root node implicitly used by chaining calls.
 **/

private extension ProgressUserInfoKey {
    static let taskRootLock = ProgressUserInfoKey(rawValue: "com_bignerdranch_Deferred_taskRootLock")
}

private extension Progress {
    /// `true` if the progress is a wrapper progress created by `Task<Value>`
    var isTaskRoot: Bool {
        return userInfo[.taskRootLock] != nil
    }

    /// Create a progress for the root of an implicit chain of tasks.
    convenience init(taskRootFor progress: Progress, orphaned: Bool) {
        self.init(totalUnitCount: 1)
        setUserInfoObject(NSLock(), forKey: .taskRootLock)
        adoptChild(progress, orphaned: orphaned, pendingUnitCount: 1)
    }
}

extension Progress {
    /// Wrap or re-wrap `progress` if necessary, suitable for becoming the
    /// progress of a Task node.
    static func taskRoot(for progress: Progress) -> Progress {
        if progress.isTaskRoot || progress === Progress.current() {
            // Task<Value> has already taken care of this at a deeper level.
            return progress
        } else if let root = Progress.current(), root.isTaskRoot {
            return root
        } else {
            // Otherwise, wrap it up as a Task<Value>-marked progress.
            return Progress(taskRootFor: progress, orphaned: true)
        }
    }
}

extension Task {
    /// Extend the progress of `self` to reflect an added operation of `cost`.
    ///
    /// Incrementing the total unit count is not atomic; we take a lock so as
    /// to not interfere with simultaneous mapping operations.
    func extendedProgress(byUnitCount cost: Int64) -> Progress {
        if let lock = progress.userInfo[.taskRootLock] as? NSLock {
            lock.lock()
            defer { lock.unlock() }

            progress.totalUnitCount += cost
            return progress
        } else {
            let progress = Progress(taskRootFor: self.progress, orphaned: false)

            progress.totalUnitCount += cost
            return progress
        }
    }
}

#endif
