//
//  TapToPayLogger.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//
internal import DatadogCore
internal import DatadogCrashReporting
internal import DatadogLogs
import Foundation

/// DataDog logger for FinixTapToPaySDK
/// This logs to Finix's DataDog for debugging customer issues
final class TapToPayLogger {
    private let logger: LoggerProtocol
    private let environment: TapToPayConfiguration.Environment
    private let username: String
    private let merchantId: String
    private let serviceName: String
    private let bundleId: String
    private let sdkVersion: String

    init(
        environment: TapToPayConfiguration.Environment,
        username: String,
        merchantId: String
    ) {
        self.environment = environment
        self.username = username
        self.merchantId = merchantId
        self.sdkVersion = TapToPaySDKMetadata.version

        // Use bundle identifier of the integrating app + SDK suffix as service name
        // This allows differentiating between TTP SDK, PAX SDK, and Checkout app
        // Examples: "com.finix.checkout-TTP", "com.finix.checkout-PAXSDK", "com.finix.checkout"
        bundleId = Bundle.main.bundleIdentifier ?? Constants.defaultServiceName
        serviceName = "\(bundleId)-TTP"

        // Check if DataDog is already initialized (by host app like FinixCheckout or PaxSDK)
        if !Datadog.isInitialized() {
            // Initialize DataDog for the SDK
            Datadog.initialize(
                with: Datadog.Configuration(
                    clientToken: Constants.datadogClientToken,
                    env: environment.datadogEnv,
                    service: serviceName
                ),
                trackingConsent: .granted
            )

            // Set user info for better traceability
            Datadog.setUserInfo(id: username, extraInfo: [
                "merchant_id": merchantId,
                "sdk": "FinixTapToPaySDK",
                "sdk_version": sdkVersion,
                "app_bundle_id": bundleId,
            ])

            Logs.enable()
            CrashReporting.enable()
            Datadog.verbosityLevel = .debug
        } else {
            // DataDog already initialized by host app, just update user info
            Datadog.setUserInfo(id: username, extraInfo: [
                "merchant_id": merchantId,
                "sdk": "FinixTapToPaySDK",
                "sdk_version": sdkVersion,
                "app_bundle_id": bundleId,
            ])
        }

        // Create logger instance with the integrating app's bundle ID as service
        logger = Logger.create(
            with: Logger.Configuration(
                service: serviceName,
                name: "TapToPay",
                networkInfoEnabled: true,
                remoteLogThreshold: .debug,
                consoleLogFormat: .shortWith(prefix: "[TTP]") // Add prefix for easy filtering
            )
        )
    }

    // MARK: - Logging Methods

    func error(_ message: String, attributes: [String: String]? = nil) {
        logger.error(message, attributes: convertAttributes(attributes))
    }

    func warn(_ message: String, attributes: [String: String]? = nil) {
        logger.warn(message, attributes: convertAttributes(attributes))
    }

    func info(_ message: String, attributes: [String: String]? = nil) {
        logger.info(message, attributes: convertAttributes(attributes))
    }

    func debug(_ message: String, attributes: [String: String]? = nil) {
        logger.debug(message, attributes: convertAttributes(attributes))
    }

    // MARK: - HTTP Logging

    func httpRequest(_ request: URLRequest) {
        let url = request.url?.absoluteString ?? ""
        let method = request.httpMethod ?? ""
        info("[HTTP] REQUEST: \(method) \(url)")

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            var headerString = "HEADERS:\n"
            for (key, value) in headers {
                // Redact sensitive headers
                if key.lowercased() == "authorization" {
                    headerString += "\(key): [REDACTED]\n"
                } else {
                    headerString += "\(key): \(value)\n"
                }
            }
            debug("[HTTP] \(headerString)")
        }
    }

    func httpResponse(_ response: HTTPURLResponse, attributes: [String: String]? = nil) {
        let url = response.url?.absoluteString ?? ""
        let status = response.statusCode
        info("[HTTP] RESPONSE: \(status) \(url)", attributes: attributes)
    }

    func httpError(_ error: Error, attributes: [String: String]? = nil) {
        self.error("[HTTP] Error: \(error.localizedDescription)", attributes: attributes)
    }

    // MARK: - Private Helpers

    private func convertAttributes(_ attributes: [String: String]?) -> [String: Encodable]? {
        // Always include SDK version and merchant ID in all logs
        var allAttributes: [String: Encodable] = [
            "sdk_version": sdkVersion,
            "merchant_id": merchantId,
        ]

        // Add any additional attributes passed in
        if let attributes = attributes {
            for (key, value) in attributes {
                allAttributes[key] = value as Encodable
            }
        }

        return allAttributes
    }
}

// MARK: - Environment Extension

extension TapToPayConfiguration.Environment {
    var datadogEnv: String {
        switch self {
            case .production:
                return "prod"
            case .sandbox:
                return "sandbox"
            #if INTERNAL_BUILD
                case .qa:
                    return "qa"
            #endif
        }
    }
}

// MARK: - Constants

private enum Constants {
    static let datadogClientToken = "pub2c8e7e57ec29577b7e38b8e3ab08e87d"
    static let defaultServiceName = "finix-taptopay-sdk"
}
