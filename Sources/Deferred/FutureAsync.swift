//
//  FutureAsync.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/11/18.
//  Copyright © 2018 Big Nerd Ranch. All rights reserved.
//

#if SWIFT_PACKAGE
import Deferred
#endif
import Dispatch

extension Future {
    /// TODO documentation.
    public static func async(upon queue: DispatchQueue = .any(), flags: DispatchWorkItemFlags = [], execute body: @escaping() -> Value) -> Future {
        let deferred = Deferred<Value>()

        queue.async(flags: flags) {
            deferred.fill(with: body())
        }

        return Future(deferred)
    }

    /// TODO documentation.
    public static func async(upon queue: DispatchQueue = .any(), flags: DispatchWorkItemFlags = [], execute body: @escaping(_: (Value) -> Void) -> Void) -> Future {
        let deferred = Deferred<Value>()

        queue.async(flags: flags) {
            body { (result) in
                deferred.fill(with: result)
            }
        }

        return Future(deferred)
    }
}
