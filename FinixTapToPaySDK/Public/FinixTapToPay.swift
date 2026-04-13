//
//  FinixTapToPay.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import Combine
import Foundation
import ProximityReader

/// Main entry point for Finix Tap to Pay SDK
/// This SDK enables iOS Tap to Pay functionality for merchants
@available(iOS 16.4, *)
public final class FinixTapToPay {
    // MARK: - Properties

    private let configuration: TapToPayConfiguration
    private let manager: TapToPayManager

    /// Publisher for transaction events
    /// Subscribe to this to receive real-time updates during transactions
    public var transactionEvents: AnyPublisher<TapToPayTransactionEvent, Never> {
        manager.transactionEvents
    }

    // MARK: - Initialization

    /// Initialize the Finix Tap to Pay SDK
    /// - Parameter configuration: Configuration with merchant credentials and settings
    public init(configuration: TapToPayConfiguration) {
        self.configuration = configuration
        manager = TapToPayManager(configuration: configuration)
    }

    /// Internal initializer for testing with dependency injection
    /// - Parameters:
    ///   - configuration: Configuration with merchant credentials and settings
    ///   - readerFactory: Factory for creating payment card reader (for testing)
    ///   - userDefaults: UserDefaults instance (for testing)
    ///   - notificationCenter: NotificationCenter instance (for testing)
    ///   - repository: Token repository instance (for testing)
    init(
        configuration: TapToPayConfiguration,
        readerFactory: @escaping () -> PaymentCardReaderProtocol,
        userDefaults: UserDefaults,
        notificationCenter: NotificationCenter,
        repository: TapToPayTokenRepositoryProtocol? = nil
    ) {
        self.configuration = configuration
        manager = TapToPayManager(
            configuration: configuration,
            readerFactory: readerFactory,
            userDefaults: userDefaults,
            notificationCenter: notificationCenter,
            repository: repository
        )
    }

    // MARK: - Account Linking

    /// Check if the merchant account is linked to Apple Tap to Pay
    /// - Returns: True if linked, false otherwise
    public func isAccountLinked() async -> Bool {
        await manager.isAccountLinked()
    }

    /// Link the merchant account to Apple Tap to Pay
    /// This shows Apple's Terms & Conditions and links the merchant's Apple ID
    ///
    /// **Important:** Once an Apple ID is linked to Tap to Pay for a merchant, it stays linked
    /// at the iOS system level. Calling this again will return an "accountAlreadyLinked" error,
    /// which is normal and means the account is already ready to use.
    ///
    /// To "unlink", you must delete and reinstall the app. Simply clearing caches won't unlink.
    ///
    /// - Throws: TapToPayError if linking fails (note: accountAlreadyLinked is not a failure)
    public func linkAccount() async throws {
        try await manager.linkAccount()
    }

    // MARK: - Reader Preparation

    /// Prepare the Tap to Pay reader for transactions
    /// Must be called before starting a transaction
    /// - Throws: TapToPayError if preparation fails
    public func prepareReader() async throws {
        try await manager.prepareReader()
    }

    // MARK: - Transactions

    /// Start a Tap to Pay transaction
    /// - Parameters:
    ///   - amount: Transaction amount in cents (e.g., 1000 = $10.00)
    ///   - currency: Currency code (e.g., "USD")
    ///   - type: Type of transaction - .sale, .authorization, or .refund (default: .sale)
    /// - Returns: Transaction result with card data
    /// - Throws: TapToPayError if transaction fails
    public func startTransaction(
        amount: Int,
        currency: String,
        type: TransactionType = .sale
    ) async throws -> TapToPayTransactionResult {
        try await manager.startTransaction(amount: amount, currency: currency, type: type)
    }

    /// Cancel an ongoing transaction
    public func cancelTransaction() async throws {
        try await manager.cancelTransaction()
    }

    // MARK: - Utilities

    /// Check if Tap to Pay is supported on this device
    /// - Returns: True if device supports Tap to Pay
    public static func isSupported() -> Bool {
        PaymentCardReader.isSupported
    }

    /// Clear cached merchant link status (for testing)
    public func clearLinkStatus() {
        manager.clearLinkStatus()
    }

    /// Force refresh link status by bypassing cache
    /// Use this when you need an immediate fresh check from Apple
    /// - Returns: Current link status from Apple
    @available(iOS 16.4, *)
    public func forceRefreshLinkStatus() async -> Bool {
        await manager.forceRefreshLinkStatus()
    }

    // MARK: - Configuration Management

    /// Refresh SDK configuration and invalidate cached tokens/devices
    /// Call this when backend configuration changes (e.g., TPID update, terminal profile change)
    /// After calling this, you must call prepareReader() again before processing transactions
    ///
    /// Apple Requirement: Support intraday Payment Card Reader Token updates
    public func refreshConfiguration() {
        manager.refreshConfiguration()
    }

    /// Clear all cached data for this merchant
    /// This includes link status cache and reader sessions
    ///
    /// **Note:** This does NOT unlink the Apple ID from Tap to Pay. Once an Apple ID is
    /// linked to Tap to Pay for a merchant, it remains linked at the iOS system level.
    /// To fully unlink, you must delete and reinstall the app.
    ///
    /// Use this for troubleshooting or when switching merchants
    public func clearAllCaches() {
        manager.clearAllCaches()
    }
}
