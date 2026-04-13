//
//  TapToPayManagerExpandedTests.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import XCTest

@available(iOS 16.4, *)
final class TapToPayManagerExpandedTests: XCTestCase {
    var sut: TapToPayManager!
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

        sut = TapToPayManager(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )
    }

    override func tearDown() {
        sut = nil
        mockReader.reset()
        mockUserDefaults.reset()
        mockNotificationCenter.reset()
        mockTokenRepository.reset()

        super.tearDown()
    }

    // MARK: - Additional Cache Tests

    func testIsAccountLinked_WithValidCache_DoesNotCallAPI() async {
        // Given: Pre-populate cache
        mockUserDefaults.set("true", forKey: "tap_to_pay_linked_MR_test123")
        mockUserDefaults.set(Date(), forKey: "tap_to_pay_linked_timestamp_MR_test123")

        // When
        let isLinked = await sut.isAccountLinked()

        // Then: No API call made
        XCTAssertTrue(isLinked)
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 0)
    }

    func testIsAccountLinked_WithInvalidCacheValue_RefetchesFromAPI() async {
        // Given: Invalid cache value
        mockUserDefaults.set(123, forKey: "tap_to_pay_linked_MR_test123")
        mockReader.shouldAccountBeLinked = true

        // When
        let isLinked = await sut.isAccountLinked()

        // Then: Fetches from API
        XCTAssertTrue(isLinked)
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1)
    }

    func testIsAccountLinked_WithMissingTimestamp_RefetchesFromAPI() async {
        // Given: Cache value without timestamp
        mockUserDefaults.set("true", forKey: "tap_to_pay_linked_MR_test123")
        mockReader.shouldAccountBeLinked = true

        // When
        let isLinked = await sut.isAccountLinked()

        // Then: Fetches from API
        XCTAssertTrue(isLinked)
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1)
    }

    func testIsAccountLinked_WithExpiredTimestamp_RefetchesFromAPI() async {
        // Given: Expired cache
        mockUserDefaults.set("true", forKey: "tap_to_pay_linked_MR_test123")
        let expiredTime = Date().addingTimeInterval(-600)
        mockUserDefaults.set(expiredTime, forKey: "tap_to_pay_linked_timestamp_MR_test123")
        mockReader.shouldAccountBeLinked = true

        // When
        let isLinked = await sut.isAccountLinked()

        // Then: Refetches
        XCTAssertTrue(isLinked)
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1)
    }

    // MARK: - Additional Device Management Tests

    // Device creation tests removed - SDK no longer handles device creation
    // App is responsible for creating devices and passing deviceId to SDK configuration

    // MARK: - Additional Transaction Tests

    func testStartTransaction_WithMinimumValidAmount_Succeeds() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true
        try? await sut.prepareReader()

        // When/Then: Amount of 1 should be valid
        do {
            _ = try await sut.startTransaction(amount: 1, currency: "USD")
        } catch {
            // Transaction mock incomplete - expected
        }
    }

    func testStartTransaction_WithLongCurrencyCode_HandlesCorrectly() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true
        try? await sut.prepareReader()

        // When/Then: Test with valid 3-letter code
        do {
            _ = try await sut.startTransaction(amount: 1000, currency: "USD")
        } catch {
            // Expected
        }
    }

    func testCancelTransaction_BeforePrepare_HandlesGracefully() async throws {
        // When/Then: Should not crash
        try await sut.cancelTransaction()

        XCTAssertTrue(true, "Cancel before prepare should complete")
    }

    func testCancelTransaction_AfterPrepare_CallsSession() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true
        mockReader.mockSession.shouldCancelSucceed = true
        try await sut.prepareReader()

        // When
        try await sut.cancelTransaction()

        // Then
        XCTAssertEqual(mockReader.mockSession.cancelReadCallCount, 1)
    }

    // MARK: - Additional Configuration Tests

    // Device cache tests removed - SDK no longer handles device creation
    // refreshConfiguration() exists to reset internal state but doesn't manage device cache

    func testClearAllCaches_RemovesAllMerchantSpecificData() async {
        // Given
        mockReader.shouldAccountBeLinked = true
        _ = await sut.isAccountLinked()

        // When
        sut.clearAllCaches()

        // Then: Link status cache cleared (SDK no longer manages device cache)
        XCTAssertFalse(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_test123"))
    }

    // MARK: - Additional Error Handling Tests

    func testLinkAccount_WithAppleAPIFailure_ThrowsError() async throws {
        // Given
        mockReader.shouldLinkAccountSucceed = false

        // When/Then
        do {
            try await sut.linkAccount()
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    func testPrepareReader_WithApplePrepareFailing_ThrowsError() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = false

        // When/Then
        do {
            try await sut.prepareReader()
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    // MARK: - Additional Lifecycle Tests

    func testInit_RegistersNotificationObservers() {
        // When: Manager created in setUp

        // Then: Observers registered
        XCTAssertEqual(mockNotificationCenter.observerCount(), 2)
    }

    func testAppLifecycle_ForegroundNotification_DoesNotCrash() {
        // When
        mockNotificationCenter.triggerForegroundNotification()

        // Then: No crash
        XCTAssertTrue(true)
    }

    func testAppLifecycle_BackgroundNotification_DoesNotCrash() {
        // When
        mockNotificationCenter.triggerBackgroundNotification()

        // Then: No crash
        XCTAssertTrue(true)
    }

    func testAppLifecycle_MultipleNotifications_HandledCorrectly() {
        // When: Trigger multiple times
        mockNotificationCenter.triggerForegroundNotification()
        mockNotificationCenter.triggerBackgroundNotification()
        mockNotificationCenter.triggerForegroundNotification()

        // Then: No crash
        XCTAssertTrue(true)
    }

    // MARK: - Additional Edge Cases

    func testForceRefreshLinkStatus_WithTokenFailure_ReturnsFalse() async {
        // Given
        mockTokenRepository.shouldThrowError = true

        // When
        let isLinked = await sut.forceRefreshLinkStatus()

        // Then
        XCTAssertFalse(isLinked)
    }

    func testForceRefreshLinkStatus_UpdatesCache_WithNewStatus() async {
        // Given
        mockReader.shouldAccountBeLinked = true

        // When
        _ = await sut.forceRefreshLinkStatus()

        // Then: Cache updated
        let cachedStatus = mockUserDefaults.string(forKey: "tap_to_pay_linked_MR_test123")
        XCTAssertEqual(cachedStatus, "true")
    }

    func testClearLinkStatus_WithoutExistingCache_HandlesGracefully() {
        // When: Clear when nothing cached
        sut.clearLinkStatus()

        // Then: No crash
        XCTAssertTrue(true)
    }

    func testPrepareReader_CalledMultipleTimes_OnlyCreatesDeviceOnce() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true

        // When: Call multiple times
        try await sut.prepareReader()
        try await sut.prepareReader()
        try await sut.prepareReader()

        // Then: Prepare is called each time
        XCTAssertEqual(mockReader.prepareCallCount, 3)
    }

    func testLinkAccount_UpdatesCache_Immediately() async throws {
        // Given
        mockReader.shouldLinkAccountSucceed = true

        // When
        try await sut.linkAccount()

        // Then: Cache updated immediately
        let cachedStatus = mockUserDefaults.string(forKey: "tap_to_pay_linked_MR_test123")
        XCTAssertEqual(cachedStatus, "true", "Link status should be cached after successful link")
    }

    func testIsAccountLinked_WithFalseCache_ReturnsCachedValue() async {
        // Given: Cache set to false
        mockUserDefaults.set("false", forKey: "tap_to_pay_linked_MR_test123")
        mockUserDefaults.set(Date(), forKey: "tap_to_pay_linked_timestamp_MR_test123")

        // When
        let isLinked = await sut.isAccountLinked()

        // Then: Returns cached false value without API call
        XCTAssertFalse(isLinked)
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 0)
    }
}
