//
//  SSLPinningManager.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import CryptoKit
import Foundation
import Security

/// Apple Tap to Pay Requirement: SSL/Certificate Pinning for secure server communications
/// Implements certificate pinning to validate Finix server certificates and prevent MITM attacks
final class SSLPinningManager {
    private let logger: TapToPayLogger

    // MARK: - Certificate Hashes

    /// Production Finix server certificate SHA-256 hashes
    /// These should be updated when certificates rotate
    private let finixProductionCertHashes: [String] = [
        // Add actual Finix production certificate SHA-256 hashes here
        // Example: "sha256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        // NOTE: For now, using default handling until certificate hashes are configured
    ]

    /// Sandbox/QA Finix server certificate SHA-256 hashes
    private let finixSandboxCertHashes: [String] = [
        // Add actual Finix sandbox certificate SHA-256 hashes here
        // Example: "sha256:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    ]

    /// Apple Tap to Pay service certificate hashes (if applicable)
    private let appleTapToPayCertHashes: [String] = [
        // Add Apple Tap to Pay certificate hashes if required
    ]

    init(logger: TapToPayLogger) {
        self.logger = logger
    }

    // MARK: - Public Interface

    /// Validate SSL certificate for Finix endpoints
    /// - Parameters:
    ///   - challenge: URLAuthenticationChallenge from URLSessionDelegate
    ///   - environment: SDK environment (production, sandbox, qa)
    /// - Returns: True if certificate is valid and pinned
    func validateFinixCertificate(
        _ challenge: URLAuthenticationChallenge,
        for environment: TapToPayConfiguration.Environment
    ) -> Bool {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            logger.error("SSL Pinning: No server trust found")
            return false
        }

        // Get the certificate hashes for the environment
        let expectedHashes = getCertificateHashes(for: environment)

        // Extract and validate the server certificate
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let serverCertificate = certificateChain.first
        else {
            logger.error("SSL Pinning: Could not get server certificate")
            return false
        }

        let serverCertData = SecCertificateCopyData(serverCertificate)
        let data = CFDataGetBytePtr(serverCertData)
        let size = CFDataGetLength(serverCertData)
        let certData = Data(bytes: data!, count: size)

        // Calculate SHA-256 hash of the certificate
        let certHash = SHA256.hash(data: certData)
        let certHashString = "sha256:" + Data(certHash).base64EncodedString()

        // Check if the certificate hash matches any expected hash
        let isValid = expectedHashes.contains(certHashString)

        if isValid {
            logger.info("SSL Pinning: Certificate validation successful for \(environment)")
            logger.info("SSL Pinning: Certificate hash: \(certHashString.prefix(20))...")
        } else {
            logger.error("SSL Pinning: Certificate validation FAILED for \(environment)")
            logger.error("SSL Pinning: Received hash: \(certHashString)")
            logger.error("SSL Pinning: Expected hashes: \(expectedHashes)")
        }

        return isValid
    }

    /// Validate SSL certificate for Apple Tap to Pay endpoints (if needed)
    /// - Parameter challenge: URLAuthenticationChallenge from URLSessionDelegate
    /// - Returns: True if certificate is valid and pinned
    func validateAppleTapToPayCertificate(_ challenge: URLAuthenticationChallenge) -> Bool {
        // Apple handles most certificate validation internally
        // This is for additional validation if needed for custom endpoints

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            logger.error("SSL Pinning: No server trust found for Apple endpoint")
            return false
        }

        // For Apple endpoints, we typically rely on their certificate validation
        // But we can add additional checks if needed

        let result = SecTrustEvaluateWithError(serverTrust, nil)

        if result {
            logger.info("SSL Pinning: Apple endpoint certificate validation successful")
        } else {
            logger.error("SSL Pinning: Apple endpoint certificate validation FAILED")
        }

        return result
    }

    // MARK: - Private Methods

    /// Get certificate hashes for the specified environment
    /// - Parameter environment: SDK environment
    /// - Returns: Array of expected certificate hashes
    private func getCertificateHashes(for environment: TapToPayConfiguration
        .Environment) -> [String]
    {
        switch environment {
            case .production:
                return finixProductionCertHashes
            case .sandbox:
                return finixSandboxCertHashes
            #if INTERNAL_BUILD
                case .qa:
                    return finixSandboxCertHashes
            #endif
        }
    }

    /// Extract public key from certificate for key pinning (alternative approach)
    /// - Parameter certificate: Server certificate
    /// - Returns: Public key data or nil
    private func extractPublicKey(from certificate: SecCertificate) -> Data? {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            logger.error("SSL Pinning: Could not extract public key from certificate")
            return nil
        }

        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            logger.error("SSL Pinning: Could not get external representation of public key")
            return nil
        }

        return publicKeyData as Data
    }

    /// Validate certificate chain
    /// - Parameter serverTrust: Server trust object
    /// - Returns: True if certificate chain is valid
    private func validateCertificateChain(_ serverTrust: SecTrust) -> Bool {
        // Set evaluation policy
        let policy = SecPolicyCreateSSL(true, nil)
        SecTrustSetPolicies(serverTrust, policy)

        // Evaluate trust
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        if isValid {
            logger.info("SSL Pinning: Certificate chain validation successful")
        } else {
            let errorDescription = error.map { String(describing: $0) } ?? "Unknown error"
            logger
                .error(
                    "SSL Pinning: Certificate chain validation failed - error: \(errorDescription)"
                )
        }

        return isValid
    }

    /// Log certificate details for debugging
    /// - Parameter certificate: Certificate to log
    private func logCertificateDetails(_ certificate: SecCertificate) {
        // Extract certificate subject
        if let summary = SecCertificateCopySubjectSummary(certificate) {
            logger.info("SSL Pinning: Certificate subject: \(summary)")
        }

        // Log certificate data hash for pinning setup
        let certData = SecCertificateCopyData(certificate)
        let data = CFDataGetBytePtr(certData)
        let size = CFDataGetLength(certData)
        let certificateData = Data(bytes: data!, count: size)

        let certHash = SHA256.hash(data: certificateData)
        let certHashString = "sha256:" + Data(certHash).base64EncodedString()

        logger.info("SSL Pinning: Certificate SHA-256 hash for pinning: \(certHashString)")
    }
}

// MARK: - URLSessionDelegate Extension

/// Extension to integrate SSL pinning with URLSession
extension SSLPinningManager {
    /// Handle URLSession authentication challenge with SSL pinning
    /// - Parameters:
    ///   - challenge: Authentication challenge
    ///   - environment: SDK environment
    /// - Returns: URLSession.AuthChallengeDisposition and URLCredential
    func handleAuthenticationChallenge(
        _ challenge: URLAuthenticationChallenge,
        for environment: TapToPayConfiguration.Environment
    ) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        // Only handle server trust authentication
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
        else {
            return (.performDefaultHandling, nil)
        }

        logger
            .info(
                "SSL Pinning: Handling authentication challenge for host: \(challenge.protectionSpace.host)"
            )

        // Check if this is a Tap to Pay endpoint requiring SSL pinning
        let isTapToPayEndpoint = isTapToPayHost(challenge.protectionSpace.host)

        if isTapToPayEndpoint {
            // Get expected certificate hashes for this environment
            let expectedHashes = getCertificateHashes(for: environment)

            // If no certificate hashes are configured, use default handling for development
            if expectedHashes.isEmpty {
                logger
                    .warn(
                        "SSL Pinning: No certificate hashes configured for \(environment) - using default handling"
                    )
                logger.warn("SSL Pinning: This should be fixed before production deployment")
                return (.performDefaultHandling, nil)
            }

            // Validate Finix certificate with pinning
            if validateFinixCertificate(challenge, for: environment) {
                // Certificate is pinned and valid
                guard let serverTrust = challenge.protectionSpace.serverTrust else {
                    return (.cancelAuthenticationChallenge, nil)
                }

                let credential = URLCredential(trust: serverTrust)
                return (.useCredential, credential)
            } else {
                // Certificate pinning failed - reject connection
                logger.error("SSL Pinning: Rejecting connection due to certificate pinning failure")
                return (.cancelAuthenticationChallenge, nil)
            }
        } else {
            // Non-Tap to Pay endpoint - use default handling
            logger
                .info(
                    "SSL Pinning: Using default handling for non-Tap to Pay host: \(challenge.protectionSpace.host)"
                )
            return (.performDefaultHandling, nil)
        }
    }

    /// Check if host is a Tap to Pay endpoint that requires SSL pinning
    /// - Parameter host: Hostname
    /// - Returns: True if this is a Tap to Pay endpoint requiring SSL pinning
    func isTapToPayHost(_ host: String) -> Bool {
        var tapToPayHosts = [
            // Apple Requirement: Only apply SSL pinning to Tap to Pay specific endpoints
            "cardpresent-orchestrator-http.sandbox.finixops.com",
            "cardpresent-orchestrator-http.prod.finixops.com",
            // NOTE: Dashboard endpoints (live.paymentsdashboard.io) use standard SSL validation
        ]

        #if INTERNAL_BUILD
            tapToPayHosts.append("cardpresent-orchestrator-http.qa.finixops.com")
        #endif

        return tapToPayHosts.contains(host.lowercased())
    }
}

// MARK: - Certificate Hash Generation Utility

/// Utility methods for generating certificate hashes during development
extension SSLPinningManager {
    /// Generate certificate hash for a given URL (development utility)
    /// - Parameter url: URL to get certificate from
    func generateCertificateHash(for url: URL) async {
        logger.info("SSL Pinning: Generating certificate hash for: \(url.absoluteString)")

        // This would be used during development to get the certificate hashes
        // for pinning. In production, this should be disabled.
        #if DEBUG
            // Implementation for fetching and logging certificate hashes
            // This helps developers get the correct hashes for pinning
        #endif
    }

    /// Validate that required certificate hashes are configured
    /// - Parameter environment: Environment to check
    /// - Returns: True if hashes are configured
    func validatePinningConfiguration(for environment: TapToPayConfiguration.Environment) -> Bool {
        let hashes = getCertificateHashes(for: environment)
        let isConfigured = !hashes.isEmpty

        if isConfigured {
            logger
                .info(
                    "SSL Pinning: Configuration valid for \(environment) - \(hashes.count) hashes"
                )
        } else {
            logger.warn("SSL Pinning: No certificate hashes configured for \(environment)")
            logger.warn("SSL Pinning: This is a security risk in production")
        }

        return isConfigured
    }
}
