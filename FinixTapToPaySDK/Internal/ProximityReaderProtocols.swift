//
//  ProximityReaderProtocols.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation
import ProximityReader

// MARK: - PaymentCardReader Protocol

/// Protocol wrapper for Apple's PaymentCardReader
/// Enables mocking of PaymentCardReader in unit tests
@available(iOS 16.4, *)
protocol PaymentCardReaderProtocol {
    /// Apple's unique reader identifier for this device
    /// CRITICAL: This is the real reader ID that must be used as AVS in JWT tokens
    var id: String { get }

    /// Check if Tap to Pay is supported on this device
    static var isSupported: Bool { get }

    /// Check if merchant account is linked to Apple Tap to Pay
    /// - Parameter token: JWT token from backend
    /// - Returns: True if account is linked
    func isAccountLinked(using token: PaymentCardReader.Token) async throws -> Bool

    /// Link merchant account to Apple Tap to Pay
    /// Shows Apple's Terms & Conditions UI
    /// - Parameter token: JWT token from backend
    func linkAccount(using token: PaymentCardReader.Token) async throws

    /// Prepare the Tap to Pay reader for transactions
    /// - Parameter token: JWT token from backend
    /// - Returns: Active reader session
    func prepare(using token: PaymentCardReader.Token) async throws
        -> PaymentCardReaderSessionProtocol
}

// MARK: - PaymentCardReaderSession Protocol

/// Protocol wrapper for Apple's PaymentCardReaderSession
/// Enables mocking of PaymentCardReaderSession in unit tests
@available(iOS 16.4, *)
protocol PaymentCardReaderSessionProtocol {
    /// Read payment card data from presented card
    /// - Parameter request: Transaction request with amount and currency
    /// - Returns: Card read result with EMV data
    func readPaymentCard(_ request: PaymentCardTransactionRequest) async throws
        -> PaymentCardReadResult

    /// Cancel an ongoing card read operation
    /// - Returns: True if cancellation succeeded
    func cancelRead() async throws -> Bool
}

// MARK: - Production Wrapper (Thin Adapter)

/// Production implementation of PaymentCardReaderProtocol
/// Thin wrapper around Apple's PaymentCardReader with zero overhead
@available(iOS 16.4, *)
final class PaymentCardReaderWrapper: PaymentCardReaderProtocol {
    private let reader: PaymentCardReader

    init() {
        reader = PaymentCardReader()
    }

    /// Apple's unique reader identifier for this device
    var id: String {
        String(describing: ObjectIdentifier(reader))
    }

    static var isSupported: Bool {
        PaymentCardReader.isSupported
    }

    func isAccountLinked(using token: PaymentCardReader.Token) async throws -> Bool {
        try await reader.isAccountLinked(using: token)
    }

    func linkAccount(using token: PaymentCardReader.Token) async throws {
        try await reader.linkAccount(using: token)
    }

    func prepare(using token: PaymentCardReader
        .Token) async throws -> PaymentCardReaderSessionProtocol
    {
        let session = try await reader.prepare(using: token)
        return PaymentCardReaderSessionWrapper(session: session)
    }
}

// MARK: - Production Session Wrapper

/// Production implementation of PaymentCardReaderSessionProtocol
/// Thin wrapper around Apple's PaymentCardReaderSession with zero overhead
@available(iOS 16.4, *)
final class PaymentCardReaderSessionWrapper: PaymentCardReaderSessionProtocol {
    private let session: PaymentCardReaderSession

    init(session: PaymentCardReaderSession) {
        self.session = session
    }

    func readPaymentCard(_ request: PaymentCardTransactionRequest) async throws
        -> PaymentCardReadResult
    {
        try await session.readPaymentCard(request)
    }

    func cancelRead() async throws -> Bool {
        try await session.cancelRead()
    }
}
