//
//  TapToPayTransferRepository.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation

/// Internal protocol for creating transfers with Tap to Pay
protocol TapToPayTransferRepository {
    /// Create a transfer using encrypted Tap to Pay card data
    /// - Parameters:
    ///   - request: Transfer request with encrypted card data
    /// - Returns: Transfer response from Finix backend
    func createTapToPayTransfer(request: TapToPayTransferRequest) async throws
        -> TapToPayTransferResponse
}

// MARK: - Transfer Request Model (Internal)

/// Internal request for creating a Tap to Pay transfer
struct TapToPayTransferRequest {
    /// Merchant ID
    let merchantId: String

    /// Merchant MID
    let merchantMid: String

    /// Device ID (from device creation)
    let deviceId: String

    /// Transaction amount in cents
    let amount: Int

    /// Currency code (e.g., "USD")
    let currency: String

    /// Encrypted payment card data from Apple ProximityReader
    /// This is the base64-encoded encrypted data from PaymentCardReadResult
    let encryptedCardData: String

    /// Apple transaction identifier (for tracking)
    let appleTransactionId: String

    /// Reader identifier (for tracking)
    let readerIdentifier: String

    /// Transaction type (SALE, AUTHORIZATION)
    let transactionType: String

    /// Idempotency ID to prevent duplicate transactions
    let idempotencyId: String

    init(
        merchantId: String,
        merchantMid: String,
        deviceId: String,
        amount: Int,
        currency: String,
        encryptedCardData: String,
        appleTransactionId: String,
        readerIdentifier: String,
        transactionType: String = "SALE",
        idempotencyId: String? = nil
    ) {
        self.merchantId = merchantId
        self.merchantMid = merchantMid
        self.deviceId = deviceId
        self.amount = amount
        self.currency = currency
        self.encryptedCardData = encryptedCardData
        self.appleTransactionId = appleTransactionId
        self.readerIdentifier = readerIdentifier
        self.transactionType = transactionType
        self.idempotencyId = idempotencyId ?? "TTP_\(appleTransactionId)"
    }
}

// MARK: - Transfer Response Model (Internal)

/// Internal response from creating a Tap to Pay transfer
struct TapToPayTransferResponse {
    /// Transfer ID
    let id: String

    /// Transfer state (SUCCEEDED, FAILED, PENDING)
    let state: String

    /// Amount in cents
    let amount: Int

    /// Currency code
    let currency: String

    /// Card brand (VISA, MASTERCARD, etc.)
    let cardBrand: String?

    /// Last 4 digits of card
    let last4: String?

    /// Masked card number
    let maskedPan: String?

    /// Approval code from processor
    let approvalCode: String?

    /// Trace ID for tracking
    let traceId: String?

    /// Failure code if transaction failed
    let failureCode: String?

    /// Failure message if transaction failed
    let failureMessage: String?

    init(
        id: String,
        state: String,
        amount: Int,
        currency: String,
        cardBrand: String? = nil,
        last4: String? = nil,
        maskedPan: String? = nil,
        approvalCode: String? = nil,
        traceId: String? = nil,
        failureCode: String? = nil,
        failureMessage: String? = nil
    ) {
        self.id = id
        self.state = state
        self.amount = amount
        self.currency = currency
        self.cardBrand = cardBrand
        self.last4 = last4
        self.maskedPan = maskedPan
        self.approvalCode = approvalCode
        self.traceId = traceId
        self.failureCode = failureCode
        self.failureMessage = failureMessage
    }
}
