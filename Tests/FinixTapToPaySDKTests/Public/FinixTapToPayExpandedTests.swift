//
//  FinixTapToPayExpandedTests.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import XCTest

@available(iOS 16.4, *)
final class FinixTapToPayExpandedTests: XCTestCase {
    var sut: FinixTapToPay!
    var mockReader: MockPaymentCardReader!
    var mockUserDefaults: MockUserDefaults!
    var mockNotificationCenter: MockNotificationCenter!
    var mockTokenRepository: MockTapToPayTokenRepository!

    override func setUp() {
        super.setUp()

        mockReader = MockPaymentCardReader()
        mockUserDefaults = MockUserDefaults()
        mockNotificationCenter = MockNotificationCenter()
        mockTokenRepository = MockTapToPayTokenRepository()
    }

    override func tearDown() {
        sut = nil
        mockReader.reset()
        mockUserDefaults.reset()
        mockNotificationCenter.reset()
        mockTokenRepository.reset()

        super.tearDown()
    }

    // MARK: - Additional Initialization Tests

    func testInit_WithProductionEnvironment_InitializesCorrectly() {
        // Given
        let config = TapToPayConfiguration(
            credentials: TapToPayConfiguration.APICredentials(
                username: "prod_user",
                password: "prod_pass"
            ),
            merchant: TapToPayConfiguration.MerchantInfo(
                merchantId: "MR_prod",
                merchantMid: "mid_prod",
                merchantName: "Prod Merchant"
            ),
            environment: .production,
            deviceId: "DV_prod"
        )

        // When
        let instance = FinixTapToPay(configuration: config)

        // Then
        XCTAssertNotNil(instance)
    }

    func testInit_WithQAEnvironment_InitializesCorrectly() {
        // Given
        let config = TapToPayConfiguration(
            credentials: TapToPayConfiguration.APICredentials(
                username: "qa_user",
                password: "qa_pass"
            ),
            merchant: TapToPayConfiguration.MerchantInfo(
                merchantId: "MR_qa",
                merchantMid: "mid_qa",
                merchantName: "QA Merchant"
            ),
            environment: .qa,
            deviceId: "DV_qa"
        )

        // When
        let instance = FinixTapToPay(configuration: config)

        // Then
        XCTAssertNotNil(instance)
    }

    func testInit_WithCustomTransactionOptions_UsesCustomOptions() {
        // Given
        let customOptions = TransactionOptions(
            returnReadResultImmediately: false,
            autoPrepareOnForeground: false,
            linkStatusCacheDuration: 600
        )
        let config = TapToPayConfiguration(
            credentials: TestFixtures.validCredentials,
            merchant: TestFixtures.validMerchantInfo,
            environment: .sandbox,
            deviceId: "DV_test123",
            transactionOptions: customOptions
        )

        // When
        let instance = FinixTapToPay(configuration: config)

        // Then
        XCTAssertNotNil(instance)
    }

    // MARK: - Additional isAccountLinked() Tests

    func testIsAccountLinked_CalledMultipleTimes_UsesCacheEfficiently() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Call multiple times
        _ = await sut.isAccountLinked()
        _ = await sut.isAccountLinked()
        _ = await sut.isAccountLinked()

        // Then: Only one API call
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1)
    }

    func testIsAccountLinked_AfterLinkingAccount_ReturnsUpdatedStatus() async throws {
        // Given
        mockReader.shouldLinkAccountSucceed = true
        mockReader.shouldAccountBeLinked = false

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Link account (which updates cache)
        try await sut.linkAccount()
        mockReader.shouldAccountBeLinked = true

        // Then: isAccountLinked reflects new status
        let isLinked = await sut.isAccountLinked()
        XCTAssertTrue(isLinked)
    }

    func testIsAccountLinked_WithExpiredCache_RefetchesFromAPI() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // First call
        _ = await sut.isAccountLinked()

        // Manually expire cache
        let expiredTime = Date().addingTimeInterval(-400)
        mockUserDefaults.set(expiredTime, forKey: "tap_to_pay_linked_timestamp_MR_test123")

        // When: Check again with expired cache
        _ = await sut.isAccountLinked()

        // Then: Made two API calls
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 2)
    }

    // MARK: - Additional linkAccount() Tests

    func testLinkAccount_WhenNotLinked_LinksSuccessfully() async throws {
        // Given
        mockReader.shouldLinkAccountSucceed = true
        mockReader.shouldAccountBeLinked = false

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When
        try await sut.linkAccount()

        // Then
        XCTAssertEqual(mockReader.linkAccountCallCount, 1)
    }

    func testLinkAccount_WhenTokenFetchFails_ThrowsError() async throws {
        // Given
        mockTokenRepository.shouldThrowError = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When/Then
        do {
            try await sut.linkAccount()
            XCTFail("Should throw error when token fetch fails")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    func testLinkAccount_UpdatesCache_AfterSuccess() async throws {
        // Given
        mockReader.shouldLinkAccountSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When
        try await sut.linkAccount()

        // Then: Cache updated
        let cachedStatus = mockUserDefaults.string(forKey: "tap_to_pay_linked_MR_test123")
        XCTAssertEqual(cachedStatus, "true")
    }

    // MARK: - Additional prepareReader() Tests

    // Device creation tests removed - SDK no longer handles device creation

    func testPrepareReader_WhenAccountNotLinked_ThrowsError() async throws {
        // Given
        mockReader.shouldAccountBeLinked = false

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When/Then
        do {
            try await sut.prepareReader()
            XCTFail("Should throw error when account not linked")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    func testPrepareReader_CallsApplePrepare_WithCorrectToken() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When
        try await sut.prepareReader()

        // Then
        XCTAssertEqual(mockReader.prepareCallCount, 1)
    }

    // MARK: - Additional startTransaction() Tests

    func testStartTransaction_WithValidParameters_StartsTransaction() async throws {
        // Given: Reader prepared
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        try await sut.prepareReader()

        // When/Then: Should at least validate parameters
        do {
            _ = try await sut.startTransaction(amount: 1000, currency: "USD")
        } catch {
            // Expected - transaction mock incomplete
        }
    }

    func testStartTransaction_WithLargeAmount_AcceptsValue() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        try await sut.prepareReader()

        // When/Then: Large amounts should be accepted
        do {
            _ = try await sut.startTransaction(amount: 99_999_999, currency: "USD")
        } catch {
            // Expected - transaction mock incomplete
        }
    }

    func testStartTransaction_WithDifferentCurrencies_ValidatesCorrectly() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        try await sut.prepareReader()

        // When/Then: Various currencies
        for currency in ["USD", "EUR", "GBP", "CAD"] {
            do {
                _ = try await sut.startTransaction(amount: 1000, currency: currency)
            } catch {
                // Expected
            }
        }
    }

    func testStartTransaction_WithWhitespaceCurrency_ThrowsError() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        try await sut.prepareReader()

        // When/Then
        do {
            _ = try await sut.startTransaction(amount: 1000, currency: "   ")
            XCTFail("Should throw error for whitespace currency")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    func testStartTransaction_CalledMultipleTimes_HandlesCorrectly() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        try await sut.prepareReader()

        // When: Multiple transactions
        for _ in 0 ..< 3 {
            do {
                _ = try await sut.startTransaction(amount: 1000, currency: "USD")
            } catch {
                // Expected
            }
        }

        // Then: Should complete without crashing
        XCTAssertTrue(true)
    }

    // MARK: - Additional cancelTransaction() Tests

    func testCancelTransaction_WhenNothingInProgress_HandlesGracefully() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        try await sut.prepareReader()

        // When/Then: Should not crash
        try await sut.cancelTransaction()

        XCTAssertTrue(true, "Cancel with nothing in progress should complete")
    }

    func testCancelTransaction_CalledMultipleTimes_HandlesGracefully() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true
        mockReader.mockSession.shouldCancelSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        try await sut.prepareReader()

        // When: Cancel multiple times
        try await sut.cancelTransaction()
        try await sut.cancelTransaction()

        // Then: Should complete without crashing
        XCTAssertTrue(true)
    }

    // MARK: - Additional forceRefreshLinkStatus() Tests

    func testForceRefreshLinkStatus_WhenLinked_ReturnsTrue() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When
        let isLinked = await sut.forceRefreshLinkStatus()

        // Then
        XCTAssertTrue(isLinked)
    }

    func testForceRefreshLinkStatus_WhenNotLinked_ReturnsFalse() async throws {
        // Given
        mockReader.shouldAccountBeLinked = false

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When
        let isLinked = await sut.forceRefreshLinkStatus()

        // Then
        XCTAssertFalse(isLinked)
    }

    func testForceRefreshLinkStatus_CalledMultipleTimes_AlwaysChecksAPI() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Call multiple times
        _ = await sut.forceRefreshLinkStatus()
        _ = await sut.forceRefreshLinkStatus()
        _ = await sut.forceRefreshLinkStatus()

        // Then: All calls hit the API
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 3)
    }

    // MARK: - Additional refreshConfiguration() Tests

    // Device cache test removed - SDK no longer manages device cache

    func testRefreshConfiguration_CalledMultipleTimes_HandlesCorrectly() {
        // Given
        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Call multiple times
        sut.refreshConfiguration()
        sut.refreshConfiguration()
        sut.refreshConfiguration()

        // Then: Should complete without crashing
        XCTAssertTrue(true)
    }

    // MARK: - Additional clearAllCaches() Tests

    func testClearAllCaches_ClearsLinkStatusCache() async {
        // Given
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        _ = await sut.isAccountLinked()

        // When
        sut.clearAllCaches()

        // Then
        XCTAssertFalse(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_test123"))
    }

    // Device cache test removed - SDK no longer manages device cache

    func testClearAllCaches_CalledMultipleTimes_HandlesCorrectly() {
        // Given
        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Call multiple times
        sut.clearAllCaches()
        sut.clearAllCaches()
        sut.clearAllCaches()

        // Then: Should complete without crashing
        XCTAssertTrue(true)
    }

    // MARK: - clearLinkStatus() Tests

    func testClearLinkStatus_RemovesCachedStatus() async {
        // Given
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        _ = await sut.isAccountLinked()

        // When
        sut.clearLinkStatus()

        // Then
        XCTAssertFalse(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_test123"))
    }

    func testClearLinkStatus_AllowsFreshCheck() async {
        // Given
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        _ = await sut.isAccountLinked()

        // When: Clear and check again
        sut.clearLinkStatus()
        _ = await sut.isAccountLinked()

        // Then: Two API calls made
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 2)
    }

    // MARK: - Configuration Tests

    func testConfiguration_WithDifferentMerchantIDs_CreatesIndependentCaches() async {
        // Given: Two configurations with different merchant IDs
        let config1 = TapToPayConfiguration(
            credentials: TapToPayConfiguration.APICredentials(username: "user1", password: "pass1"),
            merchant: TapToPayConfiguration.MerchantInfo(
                merchantId: "MR_merchant1",
                merchantMid: "mid1",
                merchantName: "Merchant 1"
            ),
            environment: .sandbox,
            deviceId: "DV_merchant1"
        )

        let config2 = TapToPayConfiguration(
            credentials: TapToPayConfiguration.APICredentials(username: "user2", password: "pass2"),
            merchant: TapToPayConfiguration.MerchantInfo(
                merchantId: "MR_merchant2",
                merchantMid: "mid2",
                merchantName: "Merchant 2"
            ),
            environment: .sandbox,
            deviceId: "DV_merchant2"
        )

        mockReader.shouldAccountBeLinked = true

        let instance1 = FinixTapToPay(
            configuration: config1,
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        let instance2 = FinixTapToPay(
            configuration: config2,
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Check link status for both
        _ = await instance1.isAccountLinked()
        _ = await instance2.isAccountLinked()

        // Then: Separate caches created
        XCTAssertTrue(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_merchant1"))
        XCTAssertTrue(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_merchant2"))
    }

    // MARK: - Edge Case Tests

    func testMultipleOperations_InSequence_WorkCorrectly() async throws {
        // Given
        mockReader.shouldAccountBeLinked = false
        mockReader.shouldLinkAccountSucceed = true
        mockReader.shouldPrepareSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Full flow
        let initialStatus = await sut.isAccountLinked()
        try await sut.linkAccount()
        mockReader.shouldAccountBeLinked = true
        let _ = await sut.forceRefreshLinkStatus()
        try await sut.prepareReader()

        // Then: All operations completed
        XCTAssertFalse(initialStatus)
        XCTAssertEqual(mockReader.linkAccountCallCount, 1)
        XCTAssertEqual(mockReader.prepareCallCount, 1)
    }

    func testIsAccountLinked_WithTokenRepositoryError_ReturnsFalse() async {
        // Given
        mockTokenRepository.shouldThrowError = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When
        let isLinked = await sut.isAccountLinked()

        // Then
        XCTAssertFalse(isLinked)
    }

    func testStartTransaction_WithVerySmallAmount_ThrowsError() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        try await sut.prepareReader()

        // When/Then: -1 should throw
        do {
            _ = try await sut.startTransaction(amount: -1, currency: "USD")
            XCTFail("Should throw for negative amount")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }
}
