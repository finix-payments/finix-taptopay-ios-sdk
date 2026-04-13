//
//  TapToPayTransferRepositoryImpl.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation

final class TapToPayTransferRepositoryImpl: TapToPayTransferRepository {
    private let configuration: TapToPayConfiguration
    private let httpClient: SecureHTTPClient
    private let logger: TapToPayLogger

    init(
        configuration: TapToPayConfiguration,
        httpClient: SecureHTTPClient,
        logger: TapToPayLogger
    ) {
        self.configuration = configuration
        self.httpClient = httpClient
        self.logger = logger
    }

    /// Create a transfer using encrypted Tap to Pay card data
    func createTapToPayTransfer(request: TapToPayTransferRequest) async throws
        -> TapToPayTransferResponse
    {
        logger.info("Creating Tap to Pay transfer - Amount: \(request.amount) \(request.currency)")
        logger.info("Using device_id: \(request.deviceId)")
        logger.info("Apple transaction ID: \(request.appleTransactionId)")

        // Build URL
        let url = "\(configuration.environment.baseURL)/card_reader/transfers"

        // Build request body
        let requestBody: [String: Any] = [
            "transaction_type": request.transactionType,
            "amount": request.amount,
            "currency": request.currency,
            "input": "CARD_CONTACTLESS", // Apple Tap to Pay is contactless
            "tap_to_pay_card_data": request.encryptedCardData, // Base64 encrypted Apple data
            "device_id": request.deviceId,
            "gateway": "FINIX_V1",
            "merchant_id": request.merchantId,
            "mid": request.merchantMid,
            "idempotency_id": request.idempotencyId,
            "tags": [
                "source": "tap_to_pay",
                "transaction_id": request.appleTransactionId,
                "reader_id": request.readerIdentifier,
            ],
        ]

        // Log request (without sensitive data)
        logger.info("Transfer request URL: \(url)")
        logger.info("Transfer request: amount=\(request.amount), device_id=\(request.deviceId)")

        // Make secure request with SSL pinning using centralized method
        do {
            let apiResponse: TransferAPIResponse = try await httpClient.finixRequest(
                path: url,
                body: requestBody,
                credentials: configuration.credentials
            )

            logger
                .info(
                    "✅ Transfer created successfully - ID: \(apiResponse.id), State: \(apiResponse.state)"
                )

            // Map to SDK response model
            return TapToPayTransferResponse(
                id: apiResponse.id,
                state: apiResponse.state,
                amount: request.amount,
                currency: request.currency,
                cardBrand: apiResponse.brand,
                last4: apiResponse.maskedAccountNumber.map { String($0.suffix(4)) },
                maskedPan: apiResponse.maskedAccountNumber,
                approvalCode: apiResponse.approvalCode,
                traceId: apiResponse.traceId,
                failureCode: apiResponse.failureCode,
                failureMessage: apiResponse.failureMessage
            )

        } catch let error as TapToPayError {
            logger.error("❌ Transfer creation failed: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("❌ Transfer creation failed: \(error.localizedDescription)")
            throw TapToPayError.transactionFailed(error.localizedDescription)
        }
    }
}

// MARK: - API Response Model

private struct TransferAPIResponse: Codable {
    let id: String
    let state: String
    let brand: String?
    let maskedAccountNumber: String?
    let approvalCode: String?
    let traceId: String?
    let failureCode: String?
    let failureMessage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case state
        case brand
        case maskedAccountNumber = "masked_account_number"
        case approvalCode = "approval_code"
        case traceId = "trace_id"
        case failureCode = "failure_code"
        case failureMessage = "failure_message"
    }
}
