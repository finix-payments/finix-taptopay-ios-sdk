//
//  MockPaymentCardReader.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import Foundation
import ProximityReader

@available(iOS 16.4, *)
final class MockPaymentCardReader: PaymentCardReaderProtocol {
    var id: String = ""

    // MARK: - Configurable Behavior

    /// Whether the device should be reported as supported
    var shouldSupportTapToPay: Bool = true

    /// Whether account should be reported as linked
    var shouldAccountBeLinked: Bool = false

    /// Whether linkAccount() should succeed
    var shouldLinkAccountSucceed: Bool = true

    /// Whether prepare() should succeed
    var shouldPrepareSucceed: Bool = true

    /// Error to throw when linkAccount() fails
    var linkAccountError: Error?

    /// Error to throw when prepare() fails
    var prepareError: Error?

    /// Simulated delay for isAccountLinked() calls (in seconds)
    var accountLinkDelay: TimeInterval = 0

    /// Simulated delay for linkAccount() calls (in seconds)
    var linkAccountDelay: TimeInterval = 0

    /// Simulated delay for prepare() calls (in seconds)
    var prepareDelay: TimeInterval = 0

    // MARK: - Call Tracking

    /// Number of times isAccountLinked() was called
    private(set) var isAccountLinkedCallCount = 0

    /// Tokens passed to isAccountLinked()
    private(set) var isAccountLinkedTokens: [PaymentCardReader.Token] = []

    /// Number of times linkAccount() was called
    private(set) var linkAccountCallCount = 0

    /// Tokens passed to linkAccount()
    private(set) var linkAccountTokens: [PaymentCardReader.Token] = []

    /// Number of times prepare() was called
    private(set) var prepareCallCount = 0

    /// Tokens passed to prepare()
    private(set) var prepareTokens: [PaymentCardReader.Token] = []

    // MARK: - Mock Session

    /// Mock session to return from prepare()
    var mockSession: MockPaymentCardReaderSession = .init()

    // MARK: - PaymentCardReaderProtocol Implementation

    static var isSupported: Bool {
        // Static property - return true by default for testing
        // Can be overridden in specific test cases if needed
        true
    }

    func isAccountLinked(using token: PaymentCardReader.Token) async throws -> Bool {
        isAccountLinkedCallCount += 1
        isAccountLinkedTokens.append(token)

        // Simulate network delay if configured
        if accountLinkDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(accountLinkDelay * 1_000_000_000))
        }

        return shouldAccountBeLinked
    }

    func linkAccount(using token: PaymentCardReader.Token) async throws {
        linkAccountCallCount += 1
        linkAccountTokens.append(token)

        // Simulate delay if configured
        if linkAccountDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(linkAccountDelay * 1_000_000_000))
        }

        // Throw error if configured
        if !shouldLinkAccountSucceed {
            throw linkAccountError ?? TapToPayError.linkingFailed("Mock link account failed")
        }

        // After successful link, update linked status
        shouldAccountBeLinked = true
    }

    func prepare(using token: PaymentCardReader
        .Token) async throws -> PaymentCardReaderSessionProtocol
    {
        prepareCallCount += 1
        prepareTokens.append(token)

        // Simulate delay if configured
        if prepareDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(prepareDelay * 1_000_000_000))
        }

        // Throw error if configured
        if !shouldPrepareSucceed {
            throw prepareError ?? TapToPayError.readerPreparationFailed("Mock prepare failed")
        }

        return mockSession
    }

    // MARK: - Test Helpers

    /// Reset all tracked calls and behavior to defaults
    func reset() {
        // Reset call counts
        isAccountLinkedCallCount = 0
        isAccountLinkedTokens.removeAll()
        linkAccountCallCount = 0
        linkAccountTokens.removeAll()
        prepareCallCount = 0
        prepareTokens.removeAll()

        // Reset behavior to defaults
        shouldSupportTapToPay = true
        shouldAccountBeLinked = false
        shouldLinkAccountSucceed = true
        shouldPrepareSucceed = true
        linkAccountError = nil
        prepareError = nil
        accountLinkDelay = 0
        linkAccountDelay = 0
        prepareDelay = 0

        // Reset mock session
        mockSession.reset()
    }

    /// Verify that isAccountLinked was called exactly once
    func verifyIsAccountLinkedCalledOnce() -> Bool {
        isAccountLinkedCallCount == 1
    }

    /// Verify that linkAccount was called exactly once
    func verifyLinkAccountCalledOnce() -> Bool {
        linkAccountCallCount == 1
    }

    /// Verify that prepare was called exactly once
    func verifyPrepareCalledOnce() -> Bool {
        prepareCallCount == 1
    }
}
