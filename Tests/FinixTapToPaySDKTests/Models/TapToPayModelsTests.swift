//
//  TapToPayModelsTests.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import XCTest

final class TapToPayModelsTests: XCTestCase {
    // MARK: - APICredentials Tests

    func testAPICredentials_Initialization() {
        // Given/When
        let credentials = TapToPayConfiguration.APICredentials(
            username: "test_user",
            password: "test_pass"
        )

        // Then
        XCTAssertEqual(credentials.username, "test_user")
        XCTAssertEqual(credentials.password, "test_pass")
    }

    // MARK: - MerchantInfo Tests

    func testMerchantInfo_Initialization() {
        // Given/When
        let merchantInfo = TapToPayConfiguration.MerchantInfo(
            merchantId: "MR_123",
            merchantMid: "mid_456",
            merchantName: "Test Merchant"
        )

        // Then
        XCTAssertEqual(merchantInfo.merchantId, "MR_123")
        XCTAssertEqual(merchantInfo.merchantMid, "mid_456")
        XCTAssertEqual(merchantInfo.merchantName, "Test Merchant")
    }

    // MARK: - TapToPayConfiguration Tests

    func testTapToPayConfiguration_WithAllParameters_InitializesCorrectly() {
        // Given
        let credentials = TapToPayConfiguration.APICredentials(username: "user", password: "pass")
        let merchant = TapToPayConfiguration.MerchantInfo(
            merchantId: "MR_test",
            merchantMid: "mid_test",
            merchantName: "Test"
        )
        let transactionOptions = TapToPayConfiguration.TransactionOptions(
            returnReadResultImmediately: true,
            autoPrepareOnForeground: false,
            linkStatusCacheDuration: 600
        )

        // When
        let config = TapToPayConfiguration(
            credentials: credentials,
            merchant: merchant,
            environment: .production,
            deviceId: "DV_test123",
            transactionOptions: transactionOptions
        )

        // Then
        XCTAssertEqual(config.credentials.username, "user")
        XCTAssertEqual(config.merchant.merchantId, "MR_test")
        XCTAssertEqual(config.environment, .production)
        XCTAssertEqual(config.transactionOptions.linkStatusCacheDuration, 600)
    }

    func testTapToPayConfiguration_WithDefaultOptions_UsesDefaults() {
        // Given
        let credentials = TapToPayConfiguration.APICredentials(username: "user", password: "pass")
        let merchant = TapToPayConfiguration.MerchantInfo(
            merchantId: "MR_test",
            merchantMid: "mid_test",
            merchantName: "Test"
        )
        // When
        let config = TapToPayConfiguration(
            credentials: credentials,
            merchant: merchant,
            environment: .sandbox,
            deviceId: "DV_test123"
        )

        // Then
        XCTAssertEqual(config.transactionOptions.returnReadResultImmediately, true)
        XCTAssertEqual(config.transactionOptions.autoPrepareOnForeground, true)
        XCTAssertEqual(config.transactionOptions.linkStatusCacheDuration, 300)
    }

    // MARK: - TransactionOptions Tests

    func testTransactionOptions_DefaultInitialization() {
        // Given/When
        let options = TapToPayConfiguration.TransactionOptions()

        // Then
        XCTAssertTrue(options.returnReadResultImmediately)
        XCTAssertTrue(options.autoPrepareOnForeground)
        XCTAssertEqual(options.linkStatusCacheDuration, 300)
    }

    func testTransactionOptions_CustomInitialization() {
        // Given/When
        let options = TapToPayConfiguration.TransactionOptions(
            returnReadResultImmediately: false,
            autoPrepareOnForeground: false,
            linkStatusCacheDuration: 600
        )

        // Then
        XCTAssertFalse(options.returnReadResultImmediately)
        XCTAssertFalse(options.autoPrepareOnForeground)
        XCTAssertEqual(options.linkStatusCacheDuration, 600)
    }

    // MARK: - Environment Tests

    func testEnvironment_SandboxBaseURL() {
        // Given/When
        let sandbox = TapToPayConfiguration.Environment.sandbox

        // Then
        XCTAssertTrue(sandbox.baseURL.contains("sandbox"))
    }

    func testEnvironment_ProductionBaseURL() {
        // Given/When
        let production = TapToPayConfiguration.Environment.production

        // Then
        XCTAssertFalse(production.baseURL.contains("sandbox"))
    }

    // MARK: - TapToPayError Tests

    func testTapToPayError_NotSupported_HasCorrectDescription() {
        // Given/When
        let error = TapToPayError.notSupported

        // Then
        XCTAssertEqual(error.errorDescription, "Tap to Pay is not supported on this device")
    }

    func testTapToPayError_LinkingFailed_IncludesMessage() {
        // Given/When
        let error = TapToPayError.linkingFailed("User cancelled")

        // Then
        XCTAssertTrue(error.errorDescription?.contains("User cancelled") ?? false)
    }

    func testTapToPayError_TransactionFailed_IncludesMessage() {
        // Given/When
        let error = TapToPayError.transactionFailed("Card declined")

        // Then
        XCTAssertTrue(error.errorDescription?.contains("Card declined") ?? false)
    }

    func testTapToPayError_TokenFetchFailed_IncludesMessage() {
        // Given/When
        let error = TapToPayError.tokenFetchFailed("Network error")

        // Then
        XCTAssertTrue(error.errorDescription?.contains("Network error") ?? false)
    }

    func testTapToPayError_ReaderPreparationFailed_IncludesMessage() {
        // Given/When
        let error = TapToPayError.readerPreparationFailed("Token expired")

        // Then
        XCTAssertTrue(error.errorDescription?.contains("Token expired") ?? false)
    }

    func testTapToPayError_TransactionCancelled_HasCorrectDescription() {
        // Given/When
        let error = TapToPayError.transactionCancelled

        // Then
        XCTAssertEqual(error.errorDescription, "Transaction was cancelled")
    }

    func testTapToPayError_AccountNotLinked_HasCorrectDescription() {
        // Given/When
        let error = TapToPayError.accountNotLinked

        // Then
        XCTAssertEqual(error.errorDescription, "Merchant account is not linked to Tap to Pay")
    }

    // MARK: - TapToPayTransactionResult Tests

    func testTapToPayTransactionResult_Initialization() {
        // Given/When
        let result = TapToPayTransactionResult(
            amount: 1000,
            currency: "USD",
            cardBrand: "VISA",
            last4: "1234",
            maskedCardNumber: "**** **** **** 1234",
            cardType: "CREDIT",
            emvData: "emv_data",
            timestamp: Date(),
            readerIdentifier: "reader_123",
            transactionIdentifier: "txn_123",
            rawData: ["key": "value"]
        )

        // Then
        XCTAssertEqual(result.amount, 1000)
        XCTAssertEqual(result.currency, "USD")
        XCTAssertEqual(result.cardBrand, "VISA")
        XCTAssertEqual(result.last4, "1234")
        XCTAssertEqual(result.cardType, "CREDIT")
    }
}
