//
//  MockPaymentCardReaderSession.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import Foundation
import ProximityReader

@available(iOS 16.4, *)
final class MockPaymentCardReaderSession: PaymentCardReaderSessionProtocol {
    // MARK: - Configurable Behavior

    /// Whether readPaymentCard() should succeed
    var shouldReadSucceed: Bool = true

    /// Whether cancelRead() should succeed
    var shouldCancelSucceed: Bool = true

    /// Error to throw when readPaymentCard() fails
    var readError: Error?

    /// Simulated delay for readPaymentCard() (in seconds)
    var readDelay: TimeInterval = 0

    /// Simulated delay for cancelRead() (in seconds)
    var cancelDelay: TimeInterval = 0

    // MARK: - Mock Card Data

    /// Mock card data to return from successful read
    var mockCardData: PaymentCardReadResult?

    // MARK: - Call Tracking

    /// Number of times readPaymentCard() was called
    private(set) var readPaymentCardCallCount = 0

    /// Requests passed to readPaymentCard()
    private(set) var readPaymentCardRequests: [PaymentCardTransactionRequest] = []

    /// Number of times cancelRead() was called
    private(set) var cancelReadCallCount = 0

    // MARK: - PaymentCardReaderSessionProtocol Implementation

    func readPaymentCard(_ request: PaymentCardTransactionRequest) async throws
        -> PaymentCardReadResult
    {
        readPaymentCardCallCount += 1
        readPaymentCardRequests.append(request)

        // Simulate delay if configured
        if readDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(readDelay * 1_000_000_000))
        }

        // Throw error if configured
        if !shouldReadSucceed {
            if let error = readError {
                throw error
            }
            // Default to transaction failed error
            throw MockReadError.readFailed
        }

        // Return mock card data if provided
        if let mockData = mockCardData {
            return mockData
        }

        // Create a default mock card result
        // Note: PaymentCardReadResult is from Apple's framework and can't be easily mocked
        // In real tests, we'd need to provide actual PaymentCardReadResult instances
        // For now, we'll throw an error if no mock data is provided
        throw MockReadError.noMockDataConfigured
    }

    func cancelRead() async throws -> Bool {
        cancelReadCallCount += 1

        // Simulate delay if configured
        if cancelDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(cancelDelay * 1_000_000_000))
        }

        // Return success status
        return shouldCancelSucceed
    }

    // MARK: - Test Helpers

    /// Reset all tracked calls and behavior to defaults
    func reset() {
        // Reset call counts
        readPaymentCardCallCount = 0
        readPaymentCardRequests.removeAll()
        cancelReadCallCount = 0

        // Reset behavior to defaults
        shouldReadSucceed = true
        shouldCancelSucceed = true
        readError = nil
        readDelay = 0
        cancelDelay = 0
        mockCardData = nil
    }

    /// Verify that readPaymentCard was called exactly once
    func verifyReadPaymentCardCalledOnce() -> Bool {
        readPaymentCardCallCount == 1
    }

    /// Verify that cancelRead was called exactly once
    func verifyCancelReadCalledOnce() -> Bool {
        cancelReadCallCount == 1
    }

    /// Get the last transaction request
    func getLastRequest() -> PaymentCardTransactionRequest? {
        readPaymentCardRequests.last
    }
}

// MARK: - Mock Read Errors

/// Mock errors for testing read failures
enum MockReadError: Error {
    case readFailed
    case readCancelled
    case noMockDataConfigured
    case timeout
    case invalidCard
}
