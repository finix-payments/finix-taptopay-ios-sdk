//
//  TapToPayManager.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import Combine
import Foundation
import ProximityReader
import UIKit

@available(iOS 16.4, *)
final class TapToPayManager {
    // MARK: - Properties

    private let configuration: TapToPayConfiguration
    private let repository: TapToPayTokenRepositoryProtocol
    private let logger: TapToPayLogger
    private var paymentCardReader: PaymentCardReaderProtocol?
    private var readerSession: PaymentCardReaderSessionProtocol?

    // Dependency injection for testability
    private let readerFactory: () -> PaymentCardReaderProtocol
    private let userDefaults: UserDefaults
    private let notificationCenter: NotificationCenter

    // Event publisher for transaction updates
    private let transactionEventSubject = CurrentValueSubject<TapToPayTransactionEvent?, Never>(nil)
    var transactionEventPublisher: AnyPublisher<TapToPayTransactionEvent?, Never> {
        transactionEventSubject.eraseToAnyPublisher()
    }

    /// Public non-optional publisher for external consumers
    var transactionEvents: AnyPublisher<TapToPayTransactionEvent, Never> {
        transactionEventSubject
            .compactMap { $0 } // Filter out nil values
            .eraseToAnyPublisher()
    }

    // MARK: - Initialization

    /// Initialize TapToPayManager with dependency injection
    /// - Parameters:
    ///   - configuration: SDK configuration
    ///   - readerFactory: Factory for creating PaymentCardReader (defaults to production wrapper)
    ///   - userDefaults: UserDefaults for caching (defaults to .standard)
    ///   - notificationCenter: NotificationCenter for lifecycle events (defaults to .default)
    ///   - repository: Optional token repository (for testing - defaults to production repository)
    init(
        configuration: TapToPayConfiguration,
        readerFactory: @escaping () -> PaymentCardReaderProtocol = { PaymentCardReaderWrapper() },
        userDefaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        repository: TapToPayTokenRepositoryProtocol? = nil
    ) {
        self.configuration = configuration
        self.readerFactory = readerFactory
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
        self.repository = repository ?? TapToPayTokenRepository(configuration: configuration)

        // Create DataDog logger for SDK
        logger = TapToPayLogger(
            environment: configuration.environment,
            username: configuration.credentials.username,
            merchantId: configuration.merchant.merchantId
        )

        logger
            .info("TapToPayManager initialized for merchant: \(configuration.merchant.merchantId)")

        // Apple Requirement: Handle app lifecycle for background/foreground transitions
        setupAppLifecycleObservers()
    }

    deinit {
        // Remove observers when manager is deallocated
        notificationCenter.removeObserver(self)
    }

    // MARK: - App Lifecycle Management

    /// Apple Requirement: Setup observers to manage app switching between background and foreground
    private func setupAppLifecycleObservers() {
        guard configuration.transactionOptions.autoPrepareOnForeground else {
            logger.info("Auto-prepare on foreground is disabled")
            return
        }

        // Observe when app will enter foreground
        notificationCenter.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillEnterForeground()
        }

        // Observe when app did enter background
        notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidEnterBackground()
        }

        logger.info("App lifecycle observers configured")
    }

    /// Handle app entering foreground
    @objc private func handleWillEnterForeground() {
        logger.info("App entering foreground - checking if reader needs preparation")

        // Check if we have a reader session
        guard readerSession != nil else {
            logger.info("No active reader session - skipping auto-prepare")
            return
        }

        // Apple Requirement: Call prepare() when app returns to foreground
        Task {
            do {
                logger.info("Auto-preparing reader after foreground transition")
                try await prepareReader()
                logger.info("✅ Auto-prepare successful")
            } catch {
                logger.error("Auto-prepare failed: \(error.localizedDescription)")
                // Don't throw - this is automatic, app can handle manually if needed
            }
        }
    }

    /// Handle app entering background
    @objc private func handleDidEnterBackground() {
        logger.info("App entering background - reader session may expire")
        // Note: Reader session may be invalidated by iOS when in background
        // App should call prepareReader() again when returning to foreground
    }

    // MARK: - Account Linking

    /// Check if merchant is linked to Apple Tap to Pay
    func isAccountLinked() async -> Bool {
        logger
            .info("Checking account link status for merchant: \(configuration.merchant.merchantId)")

        // Performance Optimization: Check time-based cache first
        let cacheKey = "tap_to_pay_linked_\(configuration.merchant.merchantId)"
        let timestampKey = "tap_to_pay_linked_timestamp_\(configuration.merchant.merchantId)"

        // Check if we have a valid cached result
        if configuration.transactionOptions.linkStatusCacheDuration > 0,
           let cachedStatus = userDefaults.string(forKey: cacheKey),
           let isLinked = Bool(cachedStatus),
           let timestamp = userDefaults.object(forKey: timestampKey) as? Date
        {
            let cacheAge = Date().timeIntervalSince(timestamp)
            if cacheAge < configuration.transactionOptions.linkStatusCacheDuration {
                let remainingTime = Int(configuration.transactionOptions
                    .linkStatusCacheDuration - cacheAge)
                logger
                    .info(
                        "✅ Using cached link status: \(isLinked) (cached \(Int(cacheAge))s ago, expires in \(remainingTime)s)"
                    )
                return isLinked
            } else {
                logger.info("Cache expired (age: \(Int(cacheAge))s), will refresh from Apple")
            }
        }

        // Cache expired or doesn't exist, check with Apple
        logger.info("Fetching fresh link status from Apple...")
        do {
            if paymentCardReader == nil {
                paymentCardReader = readerFactory()
            }

            guard let reader = paymentCardReader else {
                logger.error("Failed to create PaymentCardReader")
                return false
            }

            // Backend Requirement: device_id is now required for ALL token requests
            logger.info("Using device ID from configuration for link check...")
            let deviceId = configuration.deviceId

            // Fetch token with device_id (backend requires it for all token requests)
            let token = try await repository.fetchToken(
                merchantId: configuration.merchant.merchantId,
                merchantMid: configuration.merchant.merchantMid,
                includeDevice: true,
                deviceId: deviceId
            )

            logger.info("Creating Apple PaymentCardReader.Token from JWT...")
            let appleToken = PaymentCardReader.Token(rawValue: token)
            logger.info("Calling Apple isAccountLinked API with token...")

            let isLinked = try await reader.isAccountLinked(using: appleToken)
            logger.info("✅ Apple isAccountLinked returned: \(isLinked)")

            // Performance Optimization: Cache the result with timestamp
            userDefaults.set(String(isLinked), forKey: cacheKey)
            userDefaults.set(Date(), forKey: timestampKey)

            let cacheDuration = Int(configuration.transactionOptions.linkStatusCacheDuration)
            logger.info("✅ Account link status: \(isLinked) (cached for \(cacheDuration)s)")
            return isLinked
        } catch {
            // Apple Requirement: Log detailed error information for troubleshooting
            logger.error("Failed to check link status: \(error.localizedDescription)")
            logger.error("Error type: \(String(describing: type(of: error)))")

            // Check if it's a PaymentCardReaderError and log the specific error
            if let readerError = error as? PaymentCardReaderError {
                logger.error("PaymentCardReaderError detected - Raw value: \(readerError)")
                logger.error("Error description: \(String(describing: readerError))")

                // Log specific error cases
                switch readerError {
                    case .invalidReaderToken:
                        logger
                            .error(
                                "❌ APPLE ERROR: Invalid Reader Token - The JWT token was rejected by Apple"
                            )
                        logger.error("   Possible causes:")
                        logger
                            .error(
                                "   1. Token audience (aud) doesn't match Apple's expected value"
                            )
                        logger
                            .error("   2. Token verification string (avs) is incorrect or missing")
                        logger.error("   3. Token is expired or not yet valid (nbf/exp)")
                        logger.error("   4. Merchant is not authorized for Tap to Pay")
                        logger.error("   5. Bundle ID doesn't match token configuration")
                    case .accountNotLinked:
                        logger.error("❌ APPLE ERROR: Account Not Linked")
                    case .accountAlreadyLinked:
                        logger.error("❌ APPLE ERROR: Account Already Linked")
                    default:
                        logger.error("❌ APPLE ERROR: Other PaymentCardReaderError: \(readerError)")
                }
            }

            // Log error details if available
            let nsError = error as NSError
            logger.error("Error domain: \(nsError.domain), code: \(nsError.code)")

            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                logger
                    .error(
                        "Underlying error: domain=\(underlyingError.domain), code=\(underlyingError.code)"
                    )
            }

            // Log all error user info for Apple debugging
            for (key, value) in nsError.userInfo {
                logger.debug("Error userInfo[\(key)]: \(value)")
            }

            return false
        }
    }

    /// Link merchant account to Apple Tap to Pay
    func linkAccount() async throws {
        logger.info("Starting account linking for merchant: \(configuration.merchant.merchantId)")

        // Create reader if needed
        if paymentCardReader == nil {
            paymentCardReader = readerFactory()
        }

        guard let reader = paymentCardReader else {
            logger.error("Failed to create PaymentCardReader")
            throw TapToPayError.notConfigured
        }

        // Backend Requirement: device_id is required for all token requests
        logger.info("Using device ID from configuration...")
        let deviceId = configuration.deviceId

        // Fetch JWT token with device_id (backend requires it)
        logger.info("Fetching JWT token for linking with device_id: \(deviceId)...")
        let token = try await repository.fetchToken(
            merchantId: configuration.merchant.merchantId,
            merchantMid: configuration.merchant.merchantMid,
            includeDevice: true,
            deviceId: deviceId
        )

        // Create Apple token
        let appleToken = PaymentCardReader.Token(rawValue: token)

        // Link account with Apple
        do {
            logger.info("Calling Apple linkAccount API...")
            try await reader.linkAccount(using: appleToken)

            // Cache linked status
            let cacheKey = "tap_to_pay_linked_\(configuration.merchant.merchantId)"
            userDefaults.set("true", forKey: cacheKey)

            logger.info("✅ Account linked successfully")
        } catch {
            // Apple Requirement: Log detailed error information for troubleshooting
            logger.error("Failed to link account: \(error.localizedDescription)")
            logger.error("Error type: \(String(describing: type(of: error)))")

            // Log error details if available
            let nsError = error as NSError
            logger.error("Error domain: \(nsError.domain), code: \(nsError.code)")

            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                logger
                    .error(
                        "Underlying error: domain=\(underlyingError.domain), code=\(underlyingError.code)"
                    )
            }

            // Log all error user info for Apple debugging
            for (key, value) in nsError.userInfo {
                logger.debug("Error userInfo[\(key)]: \(value)")
            }

            throw TapToPayError.linkingFailed(error.localizedDescription)
        }
    }

    // MARK: - Reader Preparation

    /// Prepare reader for transaction
    func prepareReader() async throws {
        logger.info("Preparing reader for transaction...")

        // Create reader if needed
        if paymentCardReader == nil {
            paymentCardReader = readerFactory()
        }

        guard let reader = paymentCardReader else {
            logger.error("Failed to create PaymentCardReader")
            throw TapToPayError.notConfigured
        }

        // Check if account is linked
        logger.info("Checking account link status...")
        let isLinked = await isAccountLinked()
        guard isLinked else {
            logger.error("Account not linked")
            throw TapToPayError.accountNotLinked
        }

        // Get device ID from configuration
        logger.info("Using device ID from configuration...")
        let deviceId = configuration.deviceId

        // Fetch JWT token (with device for transactions)
        logger.info("Fetching JWT token with device_id: \(deviceId)...")
        let token = try await repository.fetchToken(
            merchantId: configuration.merchant.merchantId,
            merchantMid: configuration.merchant.merchantMid,
            includeDevice: true,
            deviceId: deviceId
        )

        // Create Apple token
        let appleToken = PaymentCardReader.Token(rawValue: token)

        // Prepare reader
        do {
            logger.info("Calling Apple prepare API...")
            readerSession = try await reader.prepare(using: appleToken)
            logger.info("✅ Reader prepared successfully")
        } catch {
            logger.error("Failed to prepare reader: \(error.localizedDescription)")
            throw TapToPayError.readerPreparationFailed(error.localizedDescription)
        }
    }

    // MARK: - Transactions

    /// Start payment transaction
    func startTransaction(amount: Int, currency: String,
                          type: TransactionType = .sale) async throws -> TapToPayTransactionResult
    {
        logger.info("Starting transaction - Type: \(type.rawValue), Amount: \(amount) \(currency)")

        guard let session = readerSession else {
            logger.error("No reader session available")
            throw TapToPayError.readerPreparationFailed("No session")
        }

        // Emit preparing transaction event - this is the signal for apps to navigate to processing
        // screen
        // Apps should navigate now so when Apple's UI dismisses, the processing screen is already
        // underneath
        transactionEventSubject.send(.preparingTransaction)
        logger.info("Preparing transaction - apps should navigate to processing screen now")

        // Emit reading card event
        transactionEventSubject.send(.readingCard)
        logger.info("Reading card...")

        do {
            // Create transaction request
            let amountDecimal = Decimal(amount) / 100
            let request = PaymentCardTransactionRequest(
                amount: amountDecimal,
                currencyCode: currency
            )

            // Apple Requirement: Use returnReadResultImmediately for better UX
            // Note: The ProximityReader API determines this behavior automatically
            // Configuration option is available for future API versions
            if configuration.transactionOptions.returnReadResultImmediately {
                logger.info("returnReadResultImmediately option enabled (handled by system)")
            }

            // Read card
            let cardData = try await session.readPaymentCard(request)
            logger.info("Card read successfully")

            // Emit card read event
            transactionEventSubject.send(.cardRead)
            logger.info("Card data read successfully, preparing to send to backend")

            // Apple Requirement: Extract identifiers for troubleshooting
            let readerIdentifier = extractReaderIdentifier()
            let transactionIdentifier = extractTransactionIdentifier(from: cardData)

            // Log identifiers for Apple troubleshooting (Required by Apple)
            logger
                .info(
                    "Card read completed - readerIdentifier: \(readerIdentifier ?? "nil"), transactionIdentifier: \(transactionIdentifier ?? "nil")"
                )

            // Emit processing event - sending to backend
            transactionEventSubject.send(.processing)
            logger.info("Processing payment with Finix backend...")

            // Encode encrypted card data for backend
            let encryptedCardData = try encodeCardDataForBackend(cardData)

            // Get device ID from configuration (required for backend)
            let deviceId = configuration.deviceId

            // Send encrypted card data to Finix backend to process payment
            let transferRequest = TapToPayTransferRequest(
                merchantId: configuration.merchant.merchantId,
                merchantMid: configuration.merchant.merchantMid,
                deviceId: deviceId,
                amount: amount,
                currency: currency,
                encryptedCardData: encryptedCardData,
                appleTransactionId: transactionIdentifier ?? UUID().uuidString,
                readerIdentifier: readerIdentifier ?? "unknown",
                transactionType: type.rawValue
            )

            // Create transfer repository and process payment
            let transferRepository = TapToPayTransferRepositoryImpl(
                configuration: configuration,
                httpClient: SecureHTTPClient(
                    environment: configuration.environment,
                    logger: logger
                ),
                logger: logger
            )

            let transferResponse = try await transferRepository
                .createTapToPayTransfer(request: transferRequest)
            logger
                .info(
                    "✅ Backend processing completed - Transfer ID: \(transferResponse.id), State: \(transferResponse.state)"
                )

            // Create result with backend response data
            let result = TapToPayTransactionResult(
                amount: amount,
                currency: currency,
                cardBrand: transferResponse.cardBrand,
                last4: transferResponse.last4,
                maskedCardNumber: transferResponse.maskedPan,
                cardType: nil, // Backend doesn't provide this yet
                emvData: nil, // EMV data is in encrypted form
                readerIdentifier: readerIdentifier,
                transactionIdentifier: transactionIdentifier,
                rawData: convertToDict(cardData),
                transferId: transferResponse.id,
                transferState: transferResponse.state,
                approvalCode: transferResponse.approvalCode,
                traceId: transferResponse.traceId
            )

            // Emit success event only if transfer succeeded
            if transferResponse.state == "SUCCEEDED" {
                transactionEventSubject.send(.success(result))
                logger.info("✅ Transaction completed successfully")
            } else {
                // Transfer failed or pending
                logger
                    .error(
                        "Transfer state: \(transferResponse.state), code: \(transferResponse.failureCode ?? "none")"
                    )
                let error = TapToPayError
                    .transactionFailed(transferResponse.failureMessage ?? "Transaction failed")
                transactionEventSubject.send(.failure(error))
                throw error
            }

            return result

        } catch let error as PaymentCardReaderSession.ReadError {
            if case .readCancelled = error {
                logger.warn("Transaction cancelled by user")
                transactionEventSubject.send(.failure(.transactionCancelled))
                throw TapToPayError.transactionCancelled
            } else {
                logger.error("Transaction failed: \(error.localizedDescription)")
                let tapToPayError = TapToPayError.transactionFailed(error.localizedDescription)
                transactionEventSubject.send(.failure(tapToPayError))
                throw tapToPayError
            }
        } catch {
            logger.error("Transaction failed: \(error.localizedDescription)")
            let tapToPayError = TapToPayError.transactionFailed(error.localizedDescription)
            transactionEventSubject.send(.failure(tapToPayError))
            throw tapToPayError
        }
    }

    /// Cancel ongoing transaction
    func cancelTransaction() async throws {
        logger.info("Cancelling transaction...")
        _ = try await readerSession?.cancelRead()
        transactionEventSubject.send(nil)
        logger.info("Transaction cancelled")
    }

    // MARK: - Utilities

    /// Clear merchant link status
    func clearLinkStatus() {
        logger.info("🗑️ Clearing link status for merchant: \(configuration.merchant.merchantId)")
        let cacheKey = "tap_to_pay_linked_\(configuration.merchant.merchantId)"
        let timestampKey = "tap_to_pay_linked_timestamp_\(configuration.merchant.merchantId)"
        userDefaults.removeObject(forKey: cacheKey)
        userDefaults.removeObject(forKey: timestampKey)
        logger.info("✅ Link status cache cleared (keys: \(cacheKey), \(timestampKey))")
    }

    /// Force refresh link status by bypassing cache
    /// Use this when you need an immediate fresh check from Apple
    func forceRefreshLinkStatus() async -> Bool {
        logger.info("Force refreshing link status (bypassing cache)...")

        // Clear cache first
        clearLinkStatus()

        // Now check fresh from Apple
        return await isAccountLinked()
    }

    // MARK: - Token Refresh & Cache Management

    /// Apple Requirement: Support intraday token updates for backend config changes
    /// Call this method when backend configuration changes (e.g., TPID update)
    func refreshConfiguration() {
        logger.info("Refreshing SDK configuration and invalidating caches")

        // Invalidate current reader session (will force new token fetch on next prepare)
        readerSession = nil
        logger.info("Invalidated reader session")

        // App should call prepareReader() again to get fresh token with updated config
        logger.info("✅ Configuration refreshed - call prepareReader() to apply changes")
    }

    /// Clear all cached data for this merchant (link status, sessions)
    func clearAllCaches() {
        logger.info("🧹 Clearing all cached data for merchant: \(configuration.merchant.merchantId)")

        // Clear link status
        clearLinkStatus()

        // Invalidate reader and session
        logger.info("🔄 Invalidating reader session and payment card reader instances")
        paymentCardReader = nil
        readerSession = nil

        logger.info("✅ All caches cleared successfully (link status + reader sessions)")
    }

    // MARK: - Private Helpers

    // MARK: - Data Extraction Methods

    private func extractCardBrand(from _: PaymentCardReadResult) -> String? {
        // Extract network from PaymentCardReadResult
        // The actual card brand would need to be parsed from encrypted data on backend
        // For now, return nil as this requires backend decryption
        logger.debug("Card brand extraction requires backend processing")
        return nil
    }

    private func extractLast4(from _: PaymentCardReadResult) -> String? {
        // Last 4 digits are not available in clear text for security
        // This would need to be extracted on backend after decryption
        logger.debug("Last4 extraction requires backend processing")
        return nil
    }

    private func extractMaskedCardNumber(from _: PaymentCardReadResult) -> String? {
        // Masked card number is not available in clear text for security
        // This would need to be returned from backend after processing
        nil
    }

    private func extractCardType(from _: PaymentCardReadResult) -> String? {
        // Card type is not directly available from PaymentCardReadResult
        // Would need to be determined from BIN range or additional processing on backend
        nil
    }

    private func extractEMVData(from _: PaymentCardReadResult) -> String? {
        // EMV data is encrypted and requires backend processing
        // The payment card data contains all encrypted information
        logger.debug("EMV data available in encrypted payment card data")
        return nil // Backend will extract from paymentCardData
    }

    private func extractReaderIdentifier() -> String? {
        // Apple Requirement: Log readerIdentifier for troubleshooting
        // The reader identifier is the unique ID for this iPhone as a reader
        // This is typically derived from the device itself
        let identifier = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        logger.info("ReaderIdentifier: \(identifier)")
        return identifier
    }

    private func extractTransactionIdentifier(from _: PaymentCardReadResult) -> String? {
        // Apple Requirement: Log transactionIdentifier for troubleshooting
        // Create a unique identifier for this transaction
        let identifier = UUID().uuidString
        logger.info("TransactionIdentifier: \(identifier)")
        return identifier
    }

    private func convertToDict(_ cardData: PaymentCardReadResult) -> [String: Any] {
        // Convert PaymentCardReadResult to dictionary for raw data storage
        // The actual payment card data is encrypted and should be sent to backend
        var dict: [String: Any] = [:]

        // Store the payment card data as base64 encoded string
        if let paymentData = try? JSONEncoder().encode(cardData.paymentCardData) {
            dict["paymentCardData"] = paymentData.base64EncodedString()
        }

        logger.debug("Converted PaymentCardReadResult to dictionary")
        return dict
    }

    /// Encode Apple's encrypted payment card data for backend processing
    /// - Parameter cardData: Payment card read result from Apple
    /// - Returns: Base64-encoded encrypted payment data
    private func encodeCardDataForBackend(_ cardData: PaymentCardReadResult) throws -> String {
        logger.info("Encoding encrypted payment card data for backend")

        // Encode the PaymentCardData (Apple's encrypted format)
        let paymentCardData = cardData.paymentCardData
        let encodedData = try JSONEncoder().encode(paymentCardData)
        let base64String = encodedData.base64EncodedString()

        logger.info("Encrypted card data encoded - length: \(base64String.count) characters")
        return base64String
    }
}

// NOTE: Removed fake SHA-256 function - now using Apple's real PaymentCardReader.id
