//
//  XCTestCase+Async.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

import XCTest

extension XCTestCase {
    /// Assert that an async operation throws an error of a specific type
    /// - Parameters:
    ///   - expression: The async throwing expression to evaluate
    ///   - errorType: The expected error type
    ///   - file: Source file (auto-populated)
    ///   - line: Source line (auto-populated)
    func assertThrowsError<E: Error>(
        _ expression: @autoclosure () async throws -> some Any,
        errorType: E.Type,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail(
                "Expected error of type \(errorType) but no error was thrown",
                file: file,
                line: line
            )
        } catch {
            XCTAssertTrue(
                error is E,
                "Expected error of type \(errorType) but got \(type(of: error))",
                file: file,
                line: line
            )
        }
    }

    /// Assert that an async operation throws a specific TapToPayError
    /// - Parameters:
    ///   - expression: The async throwing expression to evaluate
    ///   - expectedError: The expected TapToPayError case
    ///   - file: Source file (auto-populated)
    ///   - line: Source line (auto-populated)
    func assertThrowsTapToPayError(
        _ expression: @autoclosure () async throws -> some Any,
        _ expectedError: TapToPayError,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected TapToPayError but no error was thrown", file: file, line: line)
        } catch let error as TapToPayError {
            // Compare error types (not values since associated values may differ)
            XCTAssertEqual(
                String(describing: error),
                String(describing: expectedError),
                "Expected \(expectedError) but got \(error)",
                file: file,
                line: line
            )
        } catch {
            XCTFail("Expected TapToPayError but got \(type(of: error))", file: file, line: line)
        }
    }

    /// Wait for an async expectation with a timeout
    /// - Parameters:
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    ///   - description: Description of what we're waiting for
    func waitForAsync(
        timeout: TimeInterval = 5.0,
        description: String = "Async operation"
    ) async throws {
        let expectation = XCTestExpectation(description: description)
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: timeout)
    }

    /// Measure async performance
    /// - Parameters:
    ///   - metrics: Metrics to measure (default: wall clock time)
    ///   - block: Async block to measure
    func measureAsync(
        metrics: [XCTMetric] = [XCTClockMetric()],
        block: @escaping () async throws -> Void
    ) {
        measure(metrics: metrics) {
            let expectation = XCTestExpectation(description: "Async measurement")
            Task {
                try? await block()
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10.0)
        }
    }
}

// MARK: - TapToPayError Extension for Testing

@testable import FinixTapToPaySDK

extension TapToPayError: Equatable {
    public static func == (lhs: TapToPayError, rhs: TapToPayError) -> Bool {
        switch (lhs, rhs) {
            case (.notSupported, .notSupported):
                true
            case (.notConfigured, .notConfigured):
                true
            case (.accountNotLinked, .accountNotLinked):
                true
            case let (.linkingFailed(lMsg), .linkingFailed(rMsg)):
                lMsg == rMsg
            case let (.readerPreparationFailed(lMsg), .readerPreparationFailed(rMsg)):
                lMsg == rMsg
            case (.transactionCancelled, .transactionCancelled):
                true
            case let (.transactionFailed(lMsg), .transactionFailed(rMsg)):
                lMsg == rMsg
            case let (.tokenFetchFailed(lMsg), .tokenFetchFailed(rMsg)):
                lMsg == rMsg
            case let (.unknown(lMsg), .unknown(rMsg)):
                lMsg == rMsg
            default:
                false
        }
    }
}
