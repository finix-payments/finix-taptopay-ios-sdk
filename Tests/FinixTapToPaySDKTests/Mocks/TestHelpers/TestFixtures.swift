//
//  TestFixtures.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import Foundation

/// Common test fixtures for FinixTapToPaySDK tests
enum TestFixtures {
    // MARK: - API Credentials

    static let validCredentials = TapToPayConfiguration.APICredentials(
        username: "test_user",
        password: "test_password_123"
    )

    static let invalidCredentials = TapToPayConfiguration.APICredentials(
        username: "",
        password: ""
    )

    // MARK: - Merchant Info

    static let validMerchantInfo = TapToPayConfiguration.MerchantInfo(
        merchantId: "MR_test123",
        merchantMid: "test_mid_70783139",
        merchantName: "Test Merchant Inc"
    )

    static let altMerchantInfo = TapToPayConfiguration.MerchantInfo(
        merchantId: "MR_test456",
        merchantMid: "test_mid_alt",
        merchantName: "Alt Merchant LLC"
    )

    // MARK: - Transaction Options

    static let defaultTransactionOptions = TapToPayConfiguration.TransactionOptions(
        returnReadResultImmediately: true,
        autoPrepareOnForeground: true,
        linkStatusCacheDuration: 300
    )

    static let noCacheTransactionOptions = TapToPayConfiguration.TransactionOptions(
        returnReadResultImmediately: true,
        autoPrepareOnForeground: false,
        linkStatusCacheDuration: 0
    )

    // MARK: - Configuration

    static func validConfiguration(
        deviceId: String = "DV_test123"
    ) -> TapToPayConfiguration {
        TapToPayConfiguration(
            credentials: validCredentials,
            merchant: validMerchantInfo,
            environment: .sandbox,
            deviceId: deviceId,
            transactionOptions: defaultTransactionOptions
        )
    }

    static func configurationWithNoCache(
        deviceId: String = "DV_test123"
    ) -> TapToPayConfiguration {
        TapToPayConfiguration(
            credentials: validCredentials,
            merchant: validMerchantInfo,
            environment: .sandbox,
            deviceId: deviceId,
            transactionOptions: noCacheTransactionOptions
        )
    }

    // MARK: - Token Responses

    /// Valid JWT token JSON response from backend
    static let validTokenJSON = """
    {
        "tap_to_pay_token": "eyJraWQiOiI1MTFhNzk2NS05MDc3LTQxOGQtYWE5Yy01NmNhNmRlNjQyMzUiLCJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiJ9.eyJhdWQiOiJjZXJ0aWZpY2F0aW9uLXBvcy12MSIsInRwaWQiOiI0Yzg0MDAwMC0wMDAwLTAwMDAtMDdhOS0xNTJiNjc5MDM1NGIiLCJuYmYiOjE3NzUwNTk0ODksIm1ibiI6IkFscGhlcmF0eiIsIm1pZCI6IjcwNzgzMTM5LTdjNDQtNDYzNC1iNjkwLTZkNGYxNWE4OWY0MCIsImV4cCI6MTc3NTA1OTU1NCwibWNjIjoiMDc0MiIsImlhdCI6MTc3NTA1OTQ5NCwianRpIjoiM2NkYjBmN2YtMDY1NS00YjE1LWI3MDQtODA0ZWRlZmQ5MmJlIiwiYXZzIjpbImF2Ym9iMjVsbHdscWFnOXV6czB5bmk0emxqZSJdfQ.zGjJeXa3axVMyJEqEUZyZVMjRrWWa9td_8DP2j_AGJFzLfqiTBBr_vbI_XuSJIS1xCnJsVDo4McixiLBe9404w"
    }
    """

    static let validTokenData: Data = validTokenJSON.data(using: .utf8)!

    static let invalidTokenJSON = """
    {
        "error": "Unauthorized"
    }
    """

    static let invalidTokenData: Data = invalidTokenJSON.data(using: .utf8)!

    // MARK: - Transaction Results

    static let validTransactionResult = TapToPayTransactionResult(
        amount: 1000,
        currency: "USD",
        cardBrand: "VISA",
        last4: "1234",
        maskedCardNumber: "**** **** **** 1234",
        cardType: "CREDIT",
        emvData: "test_emv_data_encrypted",
        timestamp: Date(),
        readerIdentifier: "reader_test_123",
        transactionIdentifier: "txn_test_456",
        rawData: ["test_key": "test_value"]
    )

    static func transactionResult(amount: Int, currency: String) -> TapToPayTransactionResult {
        TapToPayTransactionResult(
            amount: amount,
            currency: currency,
            cardBrand: "VISA",
            last4: "1234",
            maskedCardNumber: "**** **** **** 1234",
            cardType: "CREDIT",
            emvData: nil,
            timestamp: Date(),
            readerIdentifier: nil,
            transactionIdentifier: nil,
            rawData: [:]
        )
    }

    // MARK: - HTTP Responses

    static func httpResponse(
        statusCode: Int,
        url: URL = sandboxTokenURL
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    // MARK: - URLs

    static let sandboxTokenURL =
        URL(string: "https://cardpresent-orchestrator-http.sandbox.finixops.com/tap_to_pay_token")!
    static let productionTokenURL =
        URL(string: "https://cardpresent-orchestrator-http.prod.finixops.com/tap_to_pay_token")!
    static let qaTokenURL =
        URL(string: "https://cardpresent-orchestrator-http.qa.finixops.com/tap_to_pay_token")!

    // MARK: - Cache Keys

    static func linkStatusCacheKey(merchantId: String) -> String {
        "tap_to_pay_linked_\(merchantId)"
    }

    static func linkStatusTimestampKey(merchantId: String) -> String {
        "tap_to_pay_linked_timestamp_\(merchantId)"
    }

    static func deviceIdCacheKey(merchantId: String) -> String {
        "tap_to_pay_device_id_\(merchantId)"
    }

    // MARK: - Helper Methods

    /// Create a mock URLRequest for testing
    static func mockURLRequest(
        url: URL = sandboxTokenURL,
        method: String = "GET"
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    /// Create a dated timestamp for cache testing
    static func timestampAgo(seconds: TimeInterval) -> Date {
        Date().addingTimeInterval(-seconds)
    }

    /// Create a future timestamp for cache testing
    static func timestampFuture(seconds: TimeInterval) -> Date {
        Date().addingTimeInterval(seconds)
    }
}
