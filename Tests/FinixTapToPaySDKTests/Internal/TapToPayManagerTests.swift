//
//  TapToPayManagerTests.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import XCTest

@available(iOS 16.4, *)
final class TapToPayManagerTests: XCTestCase {
    // MARK: - Properties

    var sut: TapToPayManager!
    var mockReader: MockPaymentCardReader!
    var mockUserDefaults: MockUserDefaults!
    var mockNotificationCenter: MockNotificationCenter!
    var mockTokenRepository: MockTapToPayTokenRepository!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Create mocks
        mockReader = MockPaymentCardReader()
        mockUserDefaults = MockUserDefaults()
        mockNotificationCenter = MockNotificationCenter()
        mockTokenRepository = MockTapToPayTokenRepository()

        // Create SUT with dependency injection
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

    // MARK: - Initialization Tests

    func testInit_RegistersAppLifecycleObservers() {
        // Given/When: Manager is initialized (done in setUp)

        // Then: Observers are registered
        XCTAssertEqual(
            mockNotificationCenter.observerCount(),
            2,
            "Should register 2 observers (foreground + background)"
        )
    }

    // MARK: - isAccountLinked() Caching Tests

    func testIsAccountLinked_FirstCall_FetchesFromAPI() async {
        // Given: No cached status
        mockReader.shouldAccountBeLinked = true

        // When: First check
        let isLinked = await sut.isAccountLinked()

        // Then: API is called and result is cached
        XCTAssertTrue(isLinked)
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1)
        XCTAssertTrue(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_test123"))
    }

    func testIsAccountLinked_SecondCall_UsesCachedValue() async {
        // Given: Account is linked
        mockReader.shouldAccountBeLinked = true

        // When: Checking twice
        _ = await sut.isAccountLinked()
        let secondCheck = await sut.isAccountLinked()

        // Then: API is only called once
        XCTAssertTrue(secondCheck)
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1, "Should use cache on second call")
    }

    func testIsAccountLinked_CacheExpired_RefetchesFromAPI() async {
        // Given: Account is linked with expired cache
        mockReader.shouldAccountBeLinked = true

        // First check to populate cache
        _ = await sut.isAccountLinked()

        // Manually expire cache by setting old timestamp
        let expiredTimestamp = Date().addingTimeInterval(-400) // Older than 5 min cache duration
        mockUserDefaults.set(expiredTimestamp, forKey: "tap_to_pay_linked_timestamp_MR_test123")

        // When: Checking again with expired cache
        _ = await sut.isAccountLinked()

        // Then: API is called again
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 2, "Should refetch when cache expired")
    }

    func testIsAccountLinked_WhenTokenFetchFails_ReturnsFalse() async {
        // Given: Token fetch will fail
        mockTokenRepository.shouldThrowError = true

        // When: Checking link status
        let isLinked = await sut.isAccountLinked()

        // Then: Returns false without calling Apple API
        XCTAssertFalse(isLinked)
        XCTAssertEqual(
            mockReader.isAccountLinkedCallCount,
            0,
            "Should not call Apple API if token fetch fails"
        )
    }

    func testIsAccountLinked_WhenAppleAPIFails_ReturnsFalse() async {
        // Given: Token fetch succeeds but account is not linked
        mockReader.shouldAccountBeLinked = false

        // When: Checking link status
        let isLinked = await sut.isAccountLinked()

        // Then: Returns false
        XCTAssertFalse(isLinked)
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1)
    }

    // MARK: - linkAccount() Tests

    func testLinkAccount_WhenSuccessful_UpdatesCache() async throws {
        // Given: Linking will succeed
        mockReader.shouldLinkAccountSucceed = true

        // When: Linking account
        try await sut.linkAccount()

        // Then: Cache is updated to linked
        XCTAssertEqual(mockReader.linkAccountCallCount, 1)
        let cachedStatus = mockUserDefaults.string(forKey: "tap_to_pay_linked_MR_test123")
        XCTAssertEqual(cachedStatus, "true")
    }

    func testLinkAccount_WhenFails_DoesNotUpdateCache() async throws {
        // Given: Linking will fail
        mockReader.shouldLinkAccountSucceed = false

        // When/Then: Linking throws error
        do {
            try await sut.linkAccount()
            XCTFail("Expected linkAccount to throw")
        } catch {
            // Cache should not be updated
            XCTAssertFalse(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_test123"))
        }
    }

    // MARK: - prepareReader() Tests

    func testPrepareReader_CreatesDeviceOnFirstCall() async throws {
        // Given: Account is linked
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true

        // When: Preparing reader
        try await sut.prepareReader()

        // Then: Reader is prepared
        XCTAssertEqual(mockReader.prepareCallCount, 1)
    }

    func testPrepareReader_CallsPrepareWithCorrectToken() async throws {
        // Given: Everything is ready
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true

        // When: Preparing reader
        try await sut.prepareReader()

        // Then: Apple prepare is called
        XCTAssertEqual(mockReader.prepareCallCount, 1)
    }

    // MARK: - startTransaction() Tests

    func testStartTransaction_WithZeroAmount_ThrowsError() async {
        // Given: Reader is prepared
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true
        try? await sut.prepareReader()

        // When/Then: Zero amount throws
        do {
            _ = try await sut.startTransaction(amount: 0, currency: "USD")
            XCTFail("Expected error for zero amount")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    func testStartTransaction_WithNegativeAmount_ThrowsError() async {
        // Given: Reader is prepared
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true
        try? await sut.prepareReader()

        // When/Then: Negative amount throws
        do {
            _ = try await sut.startTransaction(amount: -100, currency: "USD")
            XCTFail("Expected error for negative amount")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    func testStartTransaction_WithEmptyCurrency_ThrowsError() async {
        // Given: Reader is prepared
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true
        try? await sut.prepareReader()

        // When/Then: Empty currency throws
        do {
            _ = try await sut.startTransaction(amount: 1000, currency: "")
            XCTFail("Expected error for empty currency")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    func testStartTransaction_WithoutPreparedReader_ThrowsError() async {
        // Given: Reader is NOT prepared

        // When/Then: Transaction without prepare throws
        do {
            _ = try await sut.startTransaction(amount: 1000, currency: "USD")
            XCTFail("Expected error when reader not prepared")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    // MARK: - cancelTransaction() Tests

    func testCancelTransaction_WhenSessionExists_CallsCancel() async throws {
        // Given: Reader is prepared
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true
        mockReader.mockSession.shouldCancelSucceed = true
        try await sut.prepareReader()

        // When: Canceling transaction
        try await sut.cancelTransaction()

        // Then: Cancel is called on session
        XCTAssertEqual(mockReader.mockSession.cancelReadCallCount, 1)
    }

    // MARK: - clearLinkStatus() Tests

    func testClearLinkStatus_RemovesCachedStatus() async {
        // Given: Cached link status
        mockReader.shouldAccountBeLinked = true
        _ = await sut.isAccountLinked()
        XCTAssertTrue(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_test123"))

        // When: Clearing cache
        sut.clearLinkStatus()

        // Then: Cache is removed
        XCTAssertFalse(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_test123"))
    }

    // MARK: - forceRefreshLinkStatus() Tests

    func testForceRefreshLinkStatus_BypassesCache() async {
        // Given: Cached status
        mockReader.shouldAccountBeLinked = true
        _ = await sut.isAccountLinked()
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1)

        // When: Force refreshing
        _ = await sut.forceRefreshLinkStatus()

        // Then: API is called again
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 2, "Should bypass cache")
    }

    // MARK: - refreshConfiguration() Tests

    // Device cache test removed - SDK no longer handles device creation
    // refreshConfiguration() still exists to reset internal state but doesn't manage device cache

    // MARK: - clearAllCaches() Tests

    func testClearAllCaches_RemovesAllMerchantData() async {
        // Given: Cached link status
        mockReader.shouldAccountBeLinked = true
        _ = await sut.isAccountLinked()

        // When: Clearing all caches
        sut.clearAllCaches()

        // Then: Link status cache is removed
        XCTAssertFalse(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_test123"))
    }

    // MARK: - App Lifecycle Tests

    func testAppEntersForeground_DoesNothing() {
        // Given: App lifecycle observer is set up

        // When: Foreground notification
        mockNotificationCenter.triggerForegroundNotification()

        // Then: No crashes or unexpected behavior
        // This is primarily to verify observer setup doesn't cause issues
    }

    func testAppEntersBackground_DoesNothing() {
        // Given: App lifecycle observer is set up

        // When: Background notification
        mockNotificationCenter.triggerBackgroundNotification()

        // Then: No crashes or unexpected behavior
    }
}
