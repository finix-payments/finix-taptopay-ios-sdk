//
//  TapToPayTokenRepository.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation

final class TapToPayTokenRepository: TapToPayTokenRepositoryProtocol {
    private let configuration: TapToPayConfiguration
    private let httpClient: SecureHTTPClient
    private let logger: TapToPayLogger

    init(configuration: TapToPayConfiguration) {
        self.configuration = configuration

        // Create DataDog logger for SDK
        let logger = TapToPayLogger(
            environment: configuration.environment,
            username: configuration.credentials.username,
            merchantId: configuration.merchant.merchantId
        )

        self.logger = logger
        httpClient = SecureHTTPClient(
            environment: configuration.environment,
            logger: logger
        )
    }

    /// Fetch JWT token from backend using secure HTTP client with SSL pinning
    /// - Parameters:
    ///   - merchantId: Merchant ID (for logging only)
    ///   - merchantMid: Merchant MID (for logging only)
    ///   - includeDevice: Deprecated - device_id is now always required
    ///   - deviceId: Device ID (REQUIRED by backend API)
    /// - Returns: JWT token string
    func fetchToken(
        merchantId _: String,
        merchantMid _: String,
        includeDevice _: Bool,
        deviceId: String? = nil
    ) async throws -> String {
        logger.info("Fetching JWT token for device: \(deviceId ?? "nil")")

        // CRITICAL: Backend API changed to require device_id instead of merchant_id
        guard let deviceId else {
            logger.error("device_id is required for token fetch (backend API change)")
            throw TapToPayError.tokenFetchFailed("device_id is required")
        }

        // Build URL with parameters
        var components =
            URLComponents(string: "\(configuration.environment.baseURL)/tap_to_pay_token")!

        // Backend API now expects only device_id as query parameter
        components.queryItems = [
            URLQueryItem(name: "device_id", value: deviceId),
        ]

        guard let url = components.url else {
            logger.error("Failed to construct token URL")
            throw TapToPayError.tokenFetchFailed("Invalid URL")
        }

        // Apple Requirement: Log all token requests for troubleshooting
        logger.info("Token request URL: \(url.absoluteString)")
        logger.info("Token request parameters: device_id=\(deviceId)")

        // Make secure request with SSL pinning using centralized method
        do {
            let apiResponse: TokenAPIResponse = try await httpClient.finixRequest(
                path: url.absoluteString,
                credentials: configuration.credentials
            )

            logger.info("✅ JWT token fetched successfully for device: \(deviceId)")

            // Apple Requirement: Log token details (but not full token for security)
            logger.debug("Token length: \(apiResponse.tapToPayToken.count) characters")

            // Decode JWT parts for debugging (header.payload.signature)
            logJWTDetails(apiResponse.tapToPayToken)

            return apiResponse.tapToPayToken

        } catch let error as TapToPayError {
            // Apple Requirement: Log errors with context for troubleshooting
            logger
                .error("❌ Token fetch failed for device \(deviceId): \(error.localizedDescription)")
            logger.error("Token request details - URL: \(url.absoluteString)")
            throw error
        } catch {
            logger
                .error("❌ Token fetch failed for device \(deviceId): \(error.localizedDescription)")
            logger.error("Token request details - URL: \(url.absoluteString)")
            throw TapToPayError.tokenFetchFailed(error.localizedDescription)
        }
    }

    /// Log JWT token details for Apple troubleshooting requirements
    /// SECURITY: Only logs metadata, not sensitive token data
    private func logJWTDetails(_ token: String) {
        let parts = token.split(separator: ".")
        if parts.count == 3 {
            logger.debug("JWT Token has 3 parts (header.payload.signature)")
            logger.debug("JWT Header part length: \(parts[0].count)")
            logger.debug("JWT Payload part length: \(parts[1].count)")
            logger.debug("JWT Signature part length: \(parts[2].count)")

            // Parse payload for metadata only (no sensitive values)
            if let payloadData = Data(base64Encoded: String(parts[1]).padding(
                toLength: ((parts[1].count + 3) / 4) * 4,
                withPad: "=",
                startingAt: 0
            )),
                let payloadJson = try? JSONSerialization
                .jsonObject(with: payloadData) as? [String: Any]
            {
                // Only log lengths and existence, not actual values
                if let avs = payloadJson["avs"] as? [String] {
                    logger.debug("🔑 JWT has AVS field with \(avs.count) entries")
                    logger.debug("📏 AVS[0] length: \(avs.first?.count ?? 0) characters")
                }
                if let tpid = payloadJson["tpid"] as? String {
                    logger.debug("🔑 JWT has TPID field")
                    logger.debug("📏 TPID length: \(tpid.count) characters")
                }
                if let aud = payloadJson["aud"] as? String {
                    logger.debug("🔑 JWT Audience present: \(aud.count) characters")
                }
                if let exp = payloadJson["exp"] as? Int {
                    let expDate = Date(timeIntervalSince1970: TimeInterval(exp))
                    logger.info("🔑 JWT Expiration: \(expDate)")
                }
            }
        } else {
            logger.error("❌ Invalid JWT format - expected 3 parts, got \(parts.count)")
        }
    }
}

// MARK: - API Response Model

private struct TokenAPIResponse: Codable {
    let tapToPayToken: String

    enum CodingKeys: String, CodingKey {
        case tapToPayToken = "tap_to_pay_token"
    }
}
