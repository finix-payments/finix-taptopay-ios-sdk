//
//  SecureHTTPClient.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation

/// Apple Tap to Pay Requirement: Secure HTTP Client with SSL Pinning
/// Provides secure HTTP communication with certificate pinning for Tap to Pay security
final class SecureHTTPClient: NSObject {
    private let logger: TapToPayLogger
    private let sslPinningManager: SSLPinningManager
    private let environment: TapToPayConfiguration.Environment
    private lazy var session: URLSession = {
        // Create custom URLSession configuration with SSL pinning delegate
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0

        return URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
    }()

    init(environment: TapToPayConfiguration.Environment, logger: TapToPayLogger) {
        self.environment = environment
        self.logger = logger
        sslPinningManager = SSLPinningManager(logger: logger)

        super.init()
    }

    // MARK: - HTTP Methods

    /// Make GET request with SSL pinning
    /// - Parameters:
    ///   - url: Request URL
    ///   - headers: Optional HTTP headers
    /// - Returns: Response data
    func get(from url: URL, headers: [String: String]? = nil) async throws -> Data {
        logger.info("SecureHTTPClient: Making GET request to: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        return try await performRequest(request)
    }

    /// Make POST request with SSL pinning
    /// - Parameters:
    ///   - url: Request URL
    ///   - body: Request body data
    ///   - headers: Optional HTTP headers
    /// - Returns: Response data
    func post(to url: URL, body: Data, headers: [String: String]? = nil) async throws -> Data {
        logger.info("SecureHTTPClient: Making POST request to: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body

        // Add headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        return try await performRequest(request)
    }

    /// Make POST request with JSON body
    /// - Parameters:
    ///   - url: Request URL
    ///   - body: Request body as dictionary (will be converted to JSON)
    ///   - headers: Optional HTTP headers
    /// - Returns: Response data
    func post(to url: URL, body: [String: Any],
              headers: [String: String]? = nil) async throws -> Data
    {
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        return try await post(to: url, body: jsonData, headers: headers)
    }

    /// Make PUT request with SSL pinning
    /// - Parameters:
    ///   - url: Request URL
    ///   - body: Request body data
    ///   - headers: Optional HTTP headers
    /// - Returns: Response data
    func put(to url: URL, body: Data, headers: [String: String]? = nil) async throws -> Data {
        logger.info("SecureHTTPClient: Making PUT request to: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = body

        // Add headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        return try await performRequest(request)
    }

    // MARK: - Private Methods

    /// Parse backend error response (Finix API format)
    /// - Parameter data: Response data
    /// - Returns: Parsed backend error or nil
    private func parseBackendError(from data: Data) -> BackendError? {
        do {
            let errorResponse = try JSONDecoder().decode(BackendErrorResponse.self, from: data)
            return errorResponse._embedded.errors.first
        } catch {
            logger.debug("Could not parse backend error response: \(error)")
            return nil
        }
    }

    /// Perform HTTP request with error handling
    /// - Parameter request: URLRequest to perform
    /// - Returns: Response data
    private func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("SecureHTTPClient: Invalid response type")
                throw TapToPayError.unknown("Invalid response")
            }

            logger.info("SecureHTTPClient: Response status: \(httpResponse.statusCode)")

            // Check for HTTP errors
            guard (200 ... 299).contains(httpResponse.statusCode) else {
                // Apple Requirement: Log full error details for troubleshooting
                let errorMessage = "HTTP \(httpResponse.statusCode)"

                // Log response body for debugging (critical for Apple support)
                if let responseBody = String(data: data, encoding: .utf8) {
                    logger.error("SecureHTTPClient: HTTP error: \(errorMessage)")
                    logger.error("SecureHTTPClient: Response body: \(responseBody)")

                    // Parse backend error response to extract detailed message
                    if let backendError = parseBackendError(from: data) {
                        let detailedError = "\(backendError.code): \(backendError.message)"
                        throw TapToPayError.unknown(detailedError)
                    }
                } else {
                    logger.error("SecureHTTPClient: HTTP error: \(errorMessage) (no response body)")
                }

                throw TapToPayError.unknown(errorMessage)
            }

            return data

        } catch let error as TapToPayError {
            throw error
        } catch {
            logger.error("SecureHTTPClient: Request failed: \(error.localizedDescription)")
            throw TapToPayError.unknown(error.localizedDescription)
        }
    }
}

// MARK: - URLSessionDelegate for SSL Pinning

extension SecureHTTPClient: URLSessionDelegate {
    /// Handle SSL certificate validation with pinning
    func urlSession(
        _: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        logger
            .info(
                "SecureHTTPClient: Handling authentication challenge for host: \(challenge.protectionSpace.host)"
            )

        // Use SSL pinning manager to validate the certificate
        let (disposition, credential) = sslPinningManager.handleAuthenticationChallenge(
            challenge,
            for: environment
        )

        // Log the result for Apple troubleshooting
        logSSLEvent(
            disposition == .useCredential ? "SSL_PINNING_SUCCESS" : "SSL_PINNING_FAILURE",
            host: challenge.protectionSpace.host,
            disposition: disposition
        )

        completionHandler(disposition, credential)
    }

    /// Log SSL-related events for Apple requirements
    private func logSSLEvent(
        _ event: String,
        host: String,
        disposition: URLSession.AuthChallengeDisposition
    ) {
        logger
            .info(
                "APPLE_TTP_SSL_EVENT: \(event) - host: \(host), disposition: \(disposition), environment: \(environment)"
            )
    }
}

// MARK: - Tap to Pay Specific Validation

extension SecureHTTPClient {
    /// Validate that SSL pinning is properly configured for Tap to Pay
    /// Apple requirement: SSL pinning must be implemented for production security
    func validateSecurityConfiguration() -> Bool {
        logger.info("SecureHTTPClient: Validating SSL pinning configuration")

        let isConfigured = sslPinningManager.validatePinningConfiguration(for: environment)

        if isConfigured {
            logger.info("SecureHTTPClient: SSL pinning properly configured")
        } else {
            logger
                .warn("SecureHTTPClient: SSL pinning not configured - security risk in production")
        }

        return isConfigured
    }

    /// Test SSL pinning with a known endpoint
    /// Development utility to verify pinning is working
    func testSSLPinning(url: URL) async throws {
        #if DEBUG
            logger.info("SecureHTTPClient: Testing SSL pinning with URL: \(url.absoluteString)")

            let request = URLRequest(url: url)

            do {
                let (_, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    logger
                        .info(
                            "SecureHTTPClient: SSL pinning test successful - status: \(httpResponse.statusCode)"
                        )
                }
            } catch {
                logger.error("SecureHTTPClient: SSL pinning test failed: \(error)")
                throw error
            }
        #endif
    }
}

// MARK: - Centralized Finix API Request Methods

extension SecureHTTPClient {
    /// Make a generic GET request to Finix API with automatic decoding
    /// - Parameters:
    ///   - path: API path to append to base URL
    ///   - credentials: API credentials for auth header
    ///   - additionalHeaders: Optional additional headers
    /// - Returns: Decoded response object
    func finixRequest<ResponseType: Decodable>(
        path: String,
        credentials: TapToPayConfiguration.APICredentials,
        additionalHeaders: [String: String] = [:]
    ) async throws -> ResponseType {
        guard let url = URL(string: path) else {
            logger.error("Failed to construct URL from path: \(path)")
            throw TapToPayError.unknown("Invalid URL")
        }

        let headers = buildAuthHeaders(
            credentials: credentials,
            additionalHeaders: additionalHeaders
        )
        logger.info("Making GET request to: \(url.absoluteString)")

        let data = try await get(from: url, headers: headers)
        return try decodeResponse(from: data)
    }

    /// Make a generic POST request to Finix API with automatic encoding/decoding
    /// - Parameters:
    ///   - path: API path (full URL)
    ///   - body: Request body dictionary
    ///   - credentials: API credentials for auth header
    ///   - additionalHeaders: Optional additional headers
    /// - Returns: Decoded response object
    func finixRequest<ResponseType: Decodable>(
        path: String,
        body: [String: Any],
        credentials: TapToPayConfiguration.APICredentials,
        additionalHeaders: [String: String] = [:]
    ) async throws -> ResponseType {
        guard let url = URL(string: path) else {
            logger.error("Failed to construct URL from path: \(path)")
            throw TapToPayError.unknown("Invalid URL")
        }

        var headers = buildAuthHeaders(
            credentials: credentials,
            additionalHeaders: additionalHeaders
        )
        headers["Content-Type"] = "application/json"

        logger.info("Making POST request to: \(url.absoluteString)")

        let data = try await post(to: url, body: body, headers: headers)
        return try decodeResponse(from: data)
    }

    /// Build auth headers with Basic authentication
    /// - Parameters:
    ///   - credentials: API credentials
    ///   - additionalHeaders: Optional additional headers to merge
    /// - Returns: Complete headers dictionary
    private func buildAuthHeaders(
        credentials: TapToPayConfiguration.APICredentials,
        additionalHeaders: [String: String] = [:]
    ) -> [String: String] {
        let authString = "\(credentials.username):\(credentials.password)"
        let authData = authString.data(using: .utf8)!
        let base64Auth = authData.base64EncodedString()

        var headers = [
            "Authorization": "Basic \(base64Auth)",
            "Finix-Version": "2022-02-01",
        ]

        // Merge additional headers
        additionalHeaders.forEach { headers[$0.key] = $0.value }

        return headers
    }

    /// Decode response with centralized error handling
    /// - Parameter data: Response data
    /// - Returns: Decoded object
    private func decodeResponse<ResponseType: Decodable>(from data: Data) throws -> ResponseType {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(ResponseType.self, from: data)
        } catch {
            logger.error("Failed to decode response: \(error)")

            // Log response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Response body: \(responseString)")
            }

            throw TapToPayError.unknown("Failed to decode response: \(error.localizedDescription)")
        }
    }
}

// MARK: - Backend Error Response Models

/// Finix API error response format
private struct BackendErrorResponse: Codable {
    let _embedded: EmbeddedErrors
}

private struct EmbeddedErrors: Codable {
    let errors: [BackendError]
}

/// Individual backend error
private struct BackendError: Codable {
    let code: String
    let message: String
}
