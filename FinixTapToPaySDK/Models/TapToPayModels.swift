//
//  TapToPayModels.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation

// MARK: - Transaction Result

/// Result of a Tap to Pay transaction
public struct TapToPayTransactionResult {
    /// Transaction amount in cents
    public let amount: Int

    /// Currency code (e.g., "USD")
    public let currency: String

    /// Card brand (e.g., "VISA", "MASTERCARD")
    public let cardBrand: String?

    /// Last 4 digits of card number
    public let last4: String?

    /// Masked card number (e.g., "**** **** **** 1234")
    public let maskedCardNumber: String?

    /// Card type (e.g., "CREDIT", "DEBIT")
    public let cardType: String?

    /// EMV response data
    public let emvData: String?

    /// Timestamp of the transaction
    public let timestamp: Date

    /// Apple-provided reader identifier (required for troubleshooting)
    public let readerIdentifier: String?

    /// Apple-provided transaction identifier (required for troubleshooting)
    public let transactionIdentifier: String?

    /// Raw payment data from Apple
    public let rawData: [String: Any]

    /// Finix transfer ID (from backend processing)
    public let transferId: String?

    /// Finix transfer state (SUCCEEDED, FAILED, PENDING)
    public let transferState: String?

    /// Approval code from payment processor
    public let approvalCode: String?

    /// Trace ID for tracking
    public let traceId: String?

    init(
        amount: Int,
        currency: String,
        cardBrand: String? = nil,
        last4: String? = nil,
        maskedCardNumber: String? = nil,
        cardType: String? = nil,
        emvData: String? = nil,
        timestamp: Date = Date(),
        readerIdentifier: String? = nil,
        transactionIdentifier: String? = nil,
        rawData: [String: Any] = [:],
        transferId: String? = nil,
        transferState: String? = nil,
        approvalCode: String? = nil,
        traceId: String? = nil
    ) {
        self.amount = amount
        self.currency = currency
        self.cardBrand = cardBrand
        self.last4 = last4
        self.maskedCardNumber = maskedCardNumber
        self.cardType = cardType
        self.emvData = emvData
        self.timestamp = timestamp
        self.readerIdentifier = readerIdentifier
        self.transactionIdentifier = transactionIdentifier
        self.rawData = rawData
        self.transferId = transferId
        self.transferState = transferState
        self.approvalCode = approvalCode
        self.traceId = traceId
    }
}

// MARK: - Error Types

/// Errors that can occur when using Tap to Pay
public enum TapToPayError: Error, LocalizedError {
    case notSupported
    case notConfigured
    case accountNotLinked
    case linkingFailed(String)
    case readerPreparationFailed(String)
    case transactionCancelled
    case transactionFailed(String)
    case tokenFetchFailed(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
            case .notSupported:
                "Tap to Pay is not supported on this device"
            case .notConfigured:
                "Tap to Pay SDK is not properly configured"
            case .accountNotLinked:
                "Merchant account is not linked to Tap to Pay"
            case let .linkingFailed(message):
                "Account linking failed: \(message)"
            case let .readerPreparationFailed(message):
                "Reader preparation failed: \(message)"
            case .transactionCancelled:
                "Transaction was cancelled"
            case let .transactionFailed(message):
                "Transaction failed: \(message)"
            case let .tokenFetchFailed(message):
                "Failed to fetch JWT token: \(message)"
            case let .unknown(message):
                "Unknown error: \(message)"
        }
    }
}

// MARK: - Transaction Events

/// Events that occur during a transaction
public enum TapToPayTransactionEvent {
    case preparingTransaction // Reader is prepared, ready to start transaction (navigate to
    // processing screen now)
    case readingCard // Waiting for card to be presented
    case cardDetected // Card/device detected, reading data
    case cardRead // Card data successfully read
    case processing // Processing payment with backend
    case success(TapToPayTransactionResult)
    case failure(TapToPayError)
}
