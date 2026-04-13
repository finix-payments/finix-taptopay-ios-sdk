//
//  TapToPayConfiguration.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation

/// Configuration for Finix Tap to Pay SDK
public struct TapToPayConfiguration {
    // MARK: - Properties

    /// Finix API credentials
    public let credentials: APICredentials

    /// Merchant information
    public let merchant: MerchantInfo

    /// API environment
    public let environment: Environment

    /// Transaction options
    public let transactionOptions: TransactionOptions

    /// Device ID for Tap to Pay (must be created before SDK initialization)
    public let deviceId: String

    // MARK: - Initialization

    public init(
        credentials: APICredentials,
        merchant: MerchantInfo,
        environment: Environment,
        deviceId: String,
        transactionOptions: TransactionOptions = TransactionOptions()
    ) {
        self.credentials = credentials
        self.merchant = merchant
        self.environment = environment
        self.deviceId = deviceId
        self.transactionOptions = transactionOptions
    }

    // MARK: - Nested Types

    /// Options for configuring transaction behavior
    public struct TransactionOptions {
        /// Return read result immediately without waiting for system UI to close
        /// Apple recommendation: Set to true for better user experience
        public let returnReadResultImmediately: Bool

        /// Automatically prepare reader when app returns to foreground
        public let autoPrepareOnForeground: Bool

        /// Cache duration for link status in seconds (default: 300 seconds / 5 minutes)
        public let linkStatusCacheDuration: TimeInterval

        public init(
            returnReadResultImmediately: Bool = true,
            autoPrepareOnForeground: Bool = true,
            linkStatusCacheDuration: TimeInterval = 300
        ) {
            self.returnReadResultImmediately = returnReadResultImmediately
            self.autoPrepareOnForeground = autoPrepareOnForeground
            self.linkStatusCacheDuration = linkStatusCacheDuration
        }
    }

    /// API credentials for Finix
    public struct APICredentials {
        public let username: String
        public let password: String

        public init(username: String, password: String) {
            self.username = username
            self.password = password
        }
    }

    /// Merchant information
    public struct MerchantInfo {
        public let merchantId: String
        public let merchantMid: String
        public let merchantName: String

        public init(merchantId: String, merchantMid: String, merchantName: String) {
            self.merchantId = merchantId
            self.merchantMid = merchantMid
            self.merchantName = merchantName
        }
    }

    /// API environment
    public enum Environment {
        case sandbox
        #if INTERNAL_BUILD
            /// QA Environment (Internal builds only)
            case qa
        #endif
        case production

        /// Internal base URL - not exposed to SDK consumers
        var baseURL: String {
            switch self {
                case .sandbox:
                    return "https://cardpresent-orchestrator-http.sandbox.finixops.com"
                #if INTERNAL_BUILD
                    case .qa:
                        return "https://cardpresent-orchestrator-http.qa.finixops.com"
                #endif
                case .production:
                    return "https://cardpresent-orchestrator-http.prod.finixops.com"
            }
        }
    }
}
