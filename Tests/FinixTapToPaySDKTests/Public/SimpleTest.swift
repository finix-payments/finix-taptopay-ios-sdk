//
//  SimpleTest.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import XCTest

final class SimpleTest: XCTestCase {
    func testSimpleAssertion() {
        // Given
        let value = 1 + 1

        // Then
        XCTAssertEqual(value, 2, "Math should work")
    }

    func testConfigurationCanBeCreated() {
        // Given
        let credentials = TapToPayConfiguration.APICredentials(username: "test", password: "pass")
        let merchant = TapToPayConfiguration.MerchantInfo(
            merchantId: "MR_test",
            merchantMid: "mid",
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
        XCTAssertEqual(config.merchant.merchantId, "MR_test")
    }
}
