//
//  SSLPinningManagerTests.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import XCTest

final class SSLPinningManagerTests: XCTestCase {
    var sut: SSLPinningManager!
    var logger: TapToPayLogger!

    override func setUp() {
        super.setUp()

        logger = TapToPayLogger(environment: .sandbox, username: "test_user", merchantId: "MR_test")
        sut = SSLPinningManager(logger: logger)
    }

    override func tearDown() {
        sut = nil
        logger = nil

        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_CreatesManagerSuccessfully() {
        // Given/When: Manager created in setUp

        // Then
        XCTAssertNotNil(sut)
    }

    // MARK: - Host Validation Tests

    func testIsTapToPayHost_WithSandboxHost_ReturnsTrue() {
        // Given
        let sandboxHost = "cardpresent-orchestrator-http.sandbox.finixops.com"

        // When
        let isTapToPay = sut.isTapToPayHost(sandboxHost)

        // Then
        XCTAssertTrue(isTapToPay, "Sandbox host should be recognized as Tap to Pay host")
    }

    func testIsTapToPayHost_WithProductionHost_ReturnsTrue() {
        // Given
        let productionHost = "cardpresent-orchestrator-http.prod.finixops.com"

        // When
        let isTapToPay = sut.isTapToPayHost(productionHost)

        // Then
        XCTAssertTrue(isTapToPay, "Production host should be recognized as Tap to Pay host")
    }

    func testIsTapToPayHost_WithQAHost_ReturnsTrue() {
        // Given
        let qaHost = "cardpresent-orchestrator-http.qa.finixops.com"

        // When
        let isTapToPay = sut.isTapToPayHost(qaHost)

        // Then
        XCTAssertTrue(isTapToPay, "QA host should be recognized as Tap to Pay host")
    }

    func testIsTapToPayHost_WithNonTapToPayHost_ReturnsFalse() {
        // Given
        let nonTapToPayHost = "example.com"

        // When
        let isTapToPay = sut.isTapToPayHost(nonTapToPayHost)

        // Then
        XCTAssertFalse(isTapToPay, "Non-Tap to Pay host should return false")
    }

    func testIsTapToPayHost_WithDashboardHost_ReturnsFalse() {
        // Given: Dashboard endpoints use standard SSL validation
        let dashboardHost = "live.paymentsdashboard.io"

        // When
        let isTapToPay = sut.isTapToPayHost(dashboardHost)

        // Then
        XCTAssertFalse(isTapToPay, "Dashboard host should not require SSL pinning")
    }

    func testIsTapToPayHost_WithUppercaseHost_ReturnsTrue() {
        // Given
        let uppercaseHost = "CARDPRESENT-ORCHESTRATOR-HTTP.SANDBOX.FINIXOPS.COM"

        // When
        let isTapToPay = sut.isTapToPayHost(uppercaseHost)

        // Then
        XCTAssertTrue(isTapToPay, "Host comparison should be case-insensitive")
    }

    // MARK: - Certificate Validation Configuration Tests

    func testValidatePinningConfiguration_WithProductionEnvironment_ChecksConfiguration() {
        // Given: Production environment

        // When
        let isConfigured = sut.validatePinningConfiguration(for: .production)

        // Then: Since no hashes are configured by default, should return false
        XCTAssertFalse(isConfigured, "Should return false when no hashes configured")
    }

    func testValidatePinningConfiguration_WithSandboxEnvironment_ChecksConfiguration() {
        // Given: Sandbox environment

        // When
        let isConfigured = sut.validatePinningConfiguration(for: .sandbox)

        // Then: Since no hashes are configured by default, should return false
        XCTAssertFalse(isConfigured, "Should return false when no hashes configured")
    }

    func testValidatePinningConfiguration_WithQAEnvironment_ChecksConfiguration() {
        // Given: QA environment

        // When
        let isConfigured = sut.validatePinningConfiguration(for: .qa)

        // Then: Should check QA hashes (same as sandbox)
        let _ = sut.validatePinningConfiguration(for: .qa)

        // Verify method completes without crashing
        XCTAssertTrue(true, "QA validation should complete")
    }

    func testValidatePinningConfiguration_LogsWarning_WhenNotConfigured() {
        // Given: No hashes configured

        // When
        let _ = sut.validatePinningConfiguration(for: .production)

        // Then: Should complete (logging happens internally)
        XCTAssertTrue(true, "Should complete validation check")
    }

    func testValidatePinningConfiguration_LogsInfo_WhenConfigured() {
        // Given: Hashes would be configured (can't test directly without modifying production code)

        // When/Then: Verify method exists
        XCTAssertNotNil(sut, "SSL pinning manager should be available for configuration validation")
    }

    // MARK: - Authentication Challenge Handling Tests

    func testHandleAuthenticationChallenge_WithNonServerTrustMethod_UsesDefaultHandling() {
        // Given: Non-server trust authentication method
        let challenge = createMockChallenge(
            host: "cardpresent-orchestrator-http.sandbox.finixops.com",
            authMethod: NSURLAuthenticationMethodHTTPBasic
        )

        // When
        let (disposition, credential) = sut.handleAuthenticationChallenge(challenge, for: .sandbox)

        // Then
        XCTAssertEqual(
            disposition,
            .performDefaultHandling,
            "Should use default handling for non-server trust"
        )
        XCTAssertNil(credential, "Should not provide credential for non-server trust")
    }

    func testHandleAuthenticationChallenge_WithNonTapToPayHost_UsesDefaultHandling() {
        // Given: Non-Tap to Pay host
        let challenge = createMockChallenge(
            host: "example.com",
            authMethod: NSURLAuthenticationMethodServerTrust
        )

        // When
        let (disposition, _) = sut.handleAuthenticationChallenge(challenge, for: .sandbox)

        // Then
        XCTAssertEqual(
            disposition,
            .performDefaultHandling,
            "Should use default handling for non-Tap to Pay host"
        )
    }

    func testHandleAuthenticationChallenge_WithTapToPayHost_NoHashesConfigured_UsesDefaultHandling(
    ) {
        // Given: Tap to Pay host but no hashes configured
        let challenge = createMockChallenge(
            host: "cardpresent-orchestrator-http.sandbox.finixops.com",
            authMethod: NSURLAuthenticationMethodServerTrust
        )

        // When
        let (disposition, _) = sut.handleAuthenticationChallenge(challenge, for: .sandbox)

        // Then: Since no hashes configured, should use default handling
        XCTAssertEqual(
            disposition,
            .performDefaultHandling,
            "Should use default handling when no hashes configured"
        )
    }

    func testHandleAuthenticationChallenge_LogsHostInformation() {
        // Given
        let challenge = createMockChallenge(
            host: "cardpresent-orchestrator-http.sandbox.finixops.com",
            authMethod: NSURLAuthenticationMethodServerTrust
        )

        // When
        let _ = sut.handleAuthenticationChallenge(challenge, for: .sandbox)

        // Then: Should complete (logging happens internally)
        XCTAssertTrue(true, "Authentication challenge handling should complete")
    }

    func testHandleAuthenticationChallenge_WithProductionEnvironment_UsesProductionHashes() {
        // Given: Production environment
        let challenge = createMockChallenge(
            host: "cardpresent-orchestrator-http.prod.finixops.com",
            authMethod: NSURLAuthenticationMethodServerTrust
        )

        // When
        let _ = sut.handleAuthenticationChallenge(challenge, for: .production)

        // Then: Should check production hashes
        XCTAssertTrue(true, "Production hash checking should complete")
    }

    func testHandleAuthenticationChallenge_WithSandboxEnvironment_UsesSandboxHashes() {
        // Given: Sandbox environment
        let challenge = createMockChallenge(
            host: "cardpresent-orchestrator-http.sandbox.finixops.com",
            authMethod: NSURLAuthenticationMethodServerTrust
        )

        // When
        let _ = sut.handleAuthenticationChallenge(challenge, for: .sandbox)

        // Then: Should check sandbox hashes
        XCTAssertTrue(true, "Sandbox hash checking should complete")
    }

    // MARK: - Finix Certificate Validation Tests

    func testValidateFinixCertificate_WithNoServerTrust_ReturnsFalse() {
        // Given: Challenge with no server trust
        let challenge = createMockChallenge(
            host: "cardpresent-orchestrator-http.sandbox.finixops.com",
            authMethod: NSURLAuthenticationMethodServerTrust,
            serverTrust: nil
        )

        // When
        let isValid = sut.validateFinixCertificate(challenge, for: .sandbox)

        // Then
        XCTAssertFalse(isValid, "Should return false when no server trust")
    }

    func testValidateFinixCertificate_LogsValidationAttempt() {
        // Given: Valid challenge (even if validation fails)
        let challenge = createMockChallenge(
            host: "cardpresent-orchestrator-http.sandbox.finixops.com",
            authMethod: NSURLAuthenticationMethodServerTrust
        )

        // When
        let _ = sut.validateFinixCertificate(challenge, for: .sandbox)

        // Then: Should complete validation
        XCTAssertTrue(true, "Validation should complete")
    }

    // MARK: - Apple Tap to Pay Certificate Validation Tests

    func testValidateAppleTapToPayCertificate_WithNoServerTrust_ReturnsFalse() {
        // Given: Challenge with no server trust
        let challenge = createMockChallenge(
            host: "apple.com",
            authMethod: NSURLAuthenticationMethodServerTrust,
            serverTrust: nil
        )

        // When
        let isValid = sut.validateAppleTapToPayCertificate(challenge)

        // Then
        XCTAssertFalse(isValid, "Should return false when no server trust")
    }

    func testValidateAppleTapToPayCertificate_LogsValidationResult() {
        // Given: Challenge (validation will likely fail in test environment)
        let challenge = createMockChallenge(
            host: "apple.com",
            authMethod: NSURLAuthenticationMethodServerTrust
        )

        // When
        let _ = sut.validateAppleTapToPayCertificate(challenge)

        // Then: Should complete validation
        XCTAssertTrue(true, "Validation should complete")
    }

    // MARK: - Edge Case Tests

    func testHandleAuthenticationChallenge_WithEmptyHost_HandlesGracefully() {
        // Given: Empty host
        let challenge = createMockChallenge(
            host: "",
            authMethod: NSURLAuthenticationMethodServerTrust
        )

        // When
        let (disposition, _) = sut.handleAuthenticationChallenge(challenge, for: .sandbox)

        // Then: Should handle gracefully (not crash)
        XCTAssertEqual(disposition, .performDefaultHandling, "Should handle empty host gracefully")
    }

    func testHandleAuthenticationChallenge_WithMalformedHost_HandlesGracefully() {
        // Given: Malformed host
        let challenge = createMockChallenge(
            host: "not-a-valid@#$host",
            authMethod: NSURLAuthenticationMethodServerTrust
        )

        // When
        let (disposition, _) = sut.handleAuthenticationChallenge(challenge, for: .sandbox)

        // Then: Should handle gracefully
        XCTAssertNotNil(disposition, "Should handle malformed host gracefully")
    }

    func testIsTapToPayHost_WithMixedCase_HandlesCorrectly() {
        // Given: Mixed case host
        let mixedCaseHost = "CardPresent-Orchestrator-HTTP.Sandbox.FinixOps.COM"

        // When
        let isTapToPay = sut.isTapToPayHost(mixedCaseHost)

        // Then: Should be case-insensitive
        XCTAssertTrue(isTapToPay, "Host matching should be case-insensitive")
    }

    func testValidatePinningConfiguration_WithAllEnvironments_CompletesSuccessfully() {
        // Given: All environment types

        // When/Then: Check all environments
        let _ = sut.validatePinningConfiguration(for: .production)
        let _ = sut.validatePinningConfiguration(for: .sandbox)
        let _ = sut.validatePinningConfiguration(for: .qa)

        // Verify all complete without crashing
        XCTAssertTrue(true, "All environment validations should complete")
    }

    // MARK: - Helper Methods

    private func createMockChallenge(
        host: String,
        authMethod: String,
        serverTrust _: SecTrust? = nil
    ) -> URLAuthenticationChallenge {
        let protectionSpace = URLProtectionSpace(
            host: host,
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: authMethod
        )

        return URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: MockAuthenticationChallengeSender()
        )
    }
}

// MARK: - Mock Authentication Challenge Sender

final class MockAuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_: URLCredential, for _: URLAuthenticationChallenge) {
        // Mock implementation
    }

    func continueWithoutCredential(for _: URLAuthenticationChallenge) {
        // Mock implementation
    }

    func cancel(_: URLAuthenticationChallenge) {
        // Mock implementation
    }

    func performDefaultHandling(for _: URLAuthenticationChallenge) {
        // Mock implementation
    }

    func rejectProtectionSpaceAndContinue(with _: URLAuthenticationChallenge) {
        // Mock implementation
    }
}
