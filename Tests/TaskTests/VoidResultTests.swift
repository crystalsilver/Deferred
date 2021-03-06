//
//  VoidResultTests.swift
//  DeferredTests
//
//  Created by Zachary Waldowski on 3/27/15.
//  Copyright © 2014-2018 Big Nerd Ranch. Licensed under MIT.
//

import XCTest
#if SWIFT_PACKAGE
import Deferred
import Task
#else
import Deferred
#endif

class VoidResultTests: XCTestCase {
    static let allTests: [(String, (VoidResultTests) -> () throws -> Void)] = [
        ("testDescriptionSuccess", testDescriptionSuccess),
        ("testDescriptionFailure", testDescriptionFailure),
        ("testDebugDescriptionSuccess", testDebugDescriptionSuccess),
        ("testDebugDescriptionFailure", testDebugDescriptionFailure),
        ("testExtract", testExtract)
    ]

    private typealias Result = Task<Void>.Result

    private let aSuccessResult = Result.success(())
    private let aFailureResult = Result.failure(TestError.first)

    func testDescriptionSuccess() {
        XCTAssertEqual(String(describing: aSuccessResult), "()")
    }

    func testDescriptionFailure() {
        XCTAssertEqual(String(describing: aFailureResult), "first")
    }

    func testDebugDescriptionSuccess() {
        XCTAssert(String(reflecting: aSuccessResult) == "success(())")
    }

    func testDebugDescriptionFailure() {
        let debugDescription = String(reflecting: aFailureResult)
        XCTAssert(debugDescription.hasPrefix("failure("))
        XCTAssert(debugDescription.hasSuffix("Error.first)"))
    }

    func testExtract() {
        XCTAssertNoThrow(try aSuccessResult.extract())
        XCTAssertThrowsError(try aFailureResult.extract())
    }
}
