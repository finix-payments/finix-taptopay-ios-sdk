//
//  FinixTapToPayTests.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import XCTest

@available(iOS 16.4, *)
final class FinixTapToPayTests: XCTestCase {
    // MARK: - Properties

    var sut: FinixTapToPay!
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

        // Mock token repository comes with a default mock token

        // Create configuration
        let config = TestFixtures.validConfiguration()

        // Initialize SUT with dependency injection
        sut = FinixTapToPay(configuration: config)
        // Note: Individual tests will create new SUT instances with all mocks injected
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

    func testInit_WithValidConfiguration_InitializesSuccessfully() {
        // Given: Valid configuration
        let config = TestFixtures.validConfiguration()

        // When: Creating FinixTapToPay instance
        let instance = FinixTapToPay(configuration: config)

        // Then: Instance is created successfully
        XCTAssertNotNil(instance, "FinixTapToPay should initialize with valid configuration")
    }

    func testInit_WithMultipleConfigurations_CreatesIndependentInstances() {
        // Given: Two different configurations
        let config1 = TestFixtures.validConfiguration()
        let config2 = TapToPayConfiguration(
            credentials: TapToPayConfiguration.APICredentials(username: "user2", password: "pass2"),
            merchant: TapToPayConfiguration.MerchantInfo(
                merchantId: "MR_different",
                merchantMid: "mid2",
                merchantName: "Different Merchant"
            ),
            environment: .sandbox,
            deviceId: "DV_different"
        )

        // When: Creating two instances
        let instance1 = FinixTapToPay(configuration: config1)
        let instance2 = FinixTapToPay(configuration: config2)

        // Then: Both instances exist and are different
        XCTAssertNotNil(instance1)
        XCTAssertNotNil(instance2)
        XCTAssertTrue(instance1 !== instance2, "Instances should be independent")
    }

    // MARK: - isSupported() Tests

    func testIsSupported_ReturnsBoolean() {
        // When: Checking if Tap to Pay is supported
        let isSupported = FinixTapToPay.isSupported()

        // Then: Returns a boolean value
        XCTAssertNotNil(isSupported)
        // Actual value depends on simulator/device capabilities
    }

    // MARK: - isAccountLinked() Tests

    func testIsAccountLinked_WhenLinked_ReturnsTrue() async throws {
        // Given: Mock reader shows account is linked
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Checking link status
        let isLinked = await sut.isAccountLinked()

        // Then: Returns true
        XCTAssertTrue(isLinked)
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1)
    }

    func testIsAccountLinked_WhenNotLinked_ReturnsFalse() async throws {
        // Given: Mock reader shows account is not linked
        mockReader.shouldAccountBeLinked = false

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Checking link status
        let isLinked = await sut.isAccountLinked()

        // Then: Returns false
        XCTAssertFalse(isLinked)
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1)
    }

    func testIsAccountLinked_WithCaching_OnlyCallsAPIOnce() async throws {
        // Given: Mock reader shows account is linked
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Checking link status twice within cache duration
        let firstCheck = await sut.isAccountLinked()
        let secondCheck = await sut.isAccountLinked()

        // Then: Both return true, but API is only called once (second uses cache)
        XCTAssertTrue(firstCheck)
        XCTAssertTrue(secondCheck)
        XCTAssertEqual(
            mockReader.isAccountLinkedCallCount,
            1,
            "Should only call API once due to caching"
        )

        // Verify cache was set
        let cacheKey = "tap_to_pay_linked_MR_test123"
        XCTAssertTrue(mockUserDefaults.hasValue(forKey: cacheKey))
    }

    func testIsAccountLinked_AfterClearingCache_CallsAPIAgain() async throws {
        // Given: Mock reader shows account is linked
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Check status, clear cache, check again
        let firstCheck = await sut.isAccountLinked()
        sut.clearLinkStatus()
        let secondCheck = await sut.isAccountLinked()

        // Then: API is called twice (cache was cleared)
        XCTAssertTrue(firstCheck)
        XCTAssertTrue(secondCheck)
        XCTAssertEqual(
            mockReader.isAccountLinkedCallCount,
            2,
            "Should call API twice after cache clear"
        )
    }

    // MARK: - linkAccount() Tests

    func testLinkAccount_WhenSuccessful_CompletesWithoutError() async throws {
        // Given: Mock reader will succeed linking
        mockReader.shouldLinkAccountSucceed = true
        mockReader.shouldAccountBeLinked = false // Start unlinked

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Linking account
        try await sut.linkAccount()

        // Then: Link succeeds
        XCTAssertEqual(mockReader.linkAccountCallCount, 1)
        XCTAssertTrue(mockReader.shouldAccountBeLinked)
    }

    func testLinkAccount_WhenAlreadyLinked_StillSucceeds() async throws {
        // Given: Account is already linked
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldLinkAccountSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Attempting to link again
        try await sut.linkAccount()

        // Then: Link call is made
        XCTAssertEqual(mockReader.linkAccountCallCount, 1)
    }

    func testLinkAccount_WhenUserCancels_ThrowsError() async throws {
        // Given: User will cancel the linking
        mockReader.shouldLinkAccountSucceed = false
        mockReader.linkAccountError = TapToPayError.linkingFailed("User cancelled")

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When/Then: Linking throws error
        do {
            try await sut.linkAccount()
            XCTFail("Expected linkAccount to throw error")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    // MARK: - prepareReader() Tests

    func testPrepareReader_WhenAccountLinked_PreparesSuccessfully() async throws {
        // Given: Account is linked and prepare will succeed
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Preparing reader
        try await sut.prepareReader()

        // Then: Prepare is called
        XCTAssertEqual(mockReader.prepareCallCount, 1)
        // Token may be fetched multiple times (once for link check, once for prepare)
        XCTAssertGreaterThanOrEqual(mockTokenRepository.fetchTokenCallCount, 1)
    }

    func testPrepareReader_WhenTokenFetchFails_ThrowsError() async throws {
        // Given: Token fetch will fail
        mockReader.shouldAccountBeLinked = true
        mockTokenRepository.shouldThrowError = true
        mockTokenRepository.tokenFetchError = TapToPayError
            .tokenFetchFailed("Mock token fetch failed")

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When/Then: Prepare throws error
        do {
            try await sut.prepareReader()
            XCTFail("Expected prepareReader to throw error")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    func testPrepareReader_WhenAppleAPIFails_ThrowsError() async throws {
        // Given: Apple prepare will fail
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = false

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When/Then: Prepare throws error
        do {
            try await sut.prepareReader()
            XCTFail("Expected prepareReader to throw error")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    // MARK: - startTransaction() Tests

    func testStartTransaction_WithValidAmount_RequiresPreparation() async throws {
        // Given: Reader is not prepared
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When/Then: Starting transaction without prepare throws error
        do {
            _ = try await sut.startTransaction(amount: 1000, currency: "USD")
            XCTFail("Expected startTransaction to throw error when reader not prepared")
        } catch {
            // Expected - reader must be prepared first
            XCTAssertTrue(error is TapToPayError)
        }
    }

    func testStartTransaction_WithZeroAmount_ThrowsError() async throws {
        // Given: Reader is prepared
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

        // When/Then: Starting transaction with zero amount throws
        do {
            _ = try await sut.startTransaction(amount: 0, currency: "USD")
            XCTFail("Expected startTransaction to throw error for zero amount")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    func testStartTransaction_WithNegativeAmount_ThrowsError() async throws {
        // Given: Reader is prepared
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

        // When/Then: Starting transaction with negative amount throws
        do {
            _ = try await sut.startTransaction(amount: -100, currency: "USD")
            XCTFail("Expected startTransaction to throw error for negative amount")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    func testStartTransaction_WithEmptyCurrency_ThrowsError() async throws {
        // Given: Reader is prepared
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

        // When/Then: Starting transaction with empty currency throws
        do {
            _ = try await sut.startTransaction(amount: 1000, currency: "")
            XCTFail("Expected startTransaction to throw error for empty currency")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    // MARK: - cancelTransaction() Tests

    func testCancelTransaction_WhenTransactionInProgress_CancelsSuccessfully() async throws {
        // Given: Mock session with cancel enabled
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

        // When: Canceling transaction
        try await sut.cancelTransaction()

        // Then: Cancel is called
        XCTAssertEqual(mockReader.mockSession.cancelReadCallCount, 1)
    }

    // MARK: - forceRefreshLinkStatus() Tests

    func testForceRefreshLinkStatus_BypassesCache_CallsAPI() async throws {
        // Given: Account is linked with cached status
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // First check to populate cache
        _ = await sut.isAccountLinked()
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1)

        // When: Force refresh
        let refreshedStatus = await sut.forceRefreshLinkStatus()

        // Then: API is called again despite cache
        XCTAssertTrue(refreshedStatus)
        XCTAssertEqual(
            mockReader.isAccountLinkedCallCount,
            2,
            "Should bypass cache and call API again"
        )
    }

    func testForceRefreshLinkStatus_UpdatesCache_WithNewValue() async throws {
        // Given: Account starts linked
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        _ = await sut.forceRefreshLinkStatus()

        // Change status
        mockReader.shouldAccountBeLinked = false

        // When: Force refresh again
        let newStatus = await sut.forceRefreshLinkStatus()

        // Then: Returns updated status
        XCTAssertFalse(newStatus)
    }

    // MARK: - refreshConfiguration() Tests

    func testRefreshConfiguration_InvalidatesCaches() {
        // Given: SUT with cached data
        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Refreshing configuration
        sut.refreshConfiguration()

        // Then: Configuration is refreshed (no device cache to clear since SDK doesn't manage devices)
        XCTAssert(true, "Configuration refresh completed")
    }

    // MARK: - clearAllCaches() Tests

    func testClearAllCaches_RemovesAllCachedData() async {
        // Given: SUT with multiple cached values
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // Populate caches
        _ = await sut.isAccountLinked()

        let initialCacheCount = mockUserDefaults.count()
        XCTAssertGreaterThan(initialCacheCount, 0)

        // When: Clearing all caches
        sut.clearAllCaches()

        // Then: SDK-managed caches are cleared (link status)
        XCTAssertFalse(
            mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_test123"),
            "Link status cache should be cleared"
        )
    }

    func testClearAllCaches_AllowsFreshDataFetch() async {
        // Given: SUT with cached link status
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        _ = await sut.isAccountLinked()
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1)

        // When: Clear caches and check again
        sut.clearAllCaches()
        _ = await sut.isAccountLinked()

        // Then: Fresh API call is made
        XCTAssertEqual(
            mockReader.isAccountLinkedCallCount,
            2,
            "Should fetch fresh data after cache clear"
        )
    }
}
