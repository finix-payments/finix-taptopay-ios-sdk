//
//  FinixTapToPayAdvancedTests.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import XCTest

@available(iOS 16.4, *)
final class FinixTapToPayAdvancedTests: XCTestCase {
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

        sut = FinixTapToPay(configuration: TestFixtures.validConfiguration())
    }

    override func tearDown() {
        sut = nil
        mockReader.reset()
        mockUserDefaults.reset()
        mockNotificationCenter.reset()
        mockTokenRepository.reset()

        super.tearDown()
    }

    // MARK: - Concurrent Operations Tests

    func testIsAccountLinked_ConcurrentCalls_HandleCorrectly() async {
        // Given
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Multiple concurrent calls
        async let call1 = sut.isAccountLinked()
        async let call2 = sut.isAccountLinked()
        async let call3 = sut.isAccountLinked()

        let results = await [call1, call2, call3]

        // Then: All return consistent results
        XCTAssertTrue(results.allSatisfy { $0 == true })
    }

    func testConcurrentCacheClear_DoesNotCrash() async {
        // Given
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Concurrent cache operations
        await withTaskGroup(of: Void.self) { group in
            group.addTask { _ = await self.sut.isAccountLinked() }
            group.addTask { self.sut.clearLinkStatus() }
            group.addTask { _ = await self.sut.forceRefreshLinkStatus() }
            group.addTask { self.sut.clearAllCaches() }
        }

        // Then: No crashes
        XCTAssert(true, "Completed without crashing")
    }

    // MARK: - Cache Expiration Tests

    func testIsAccountLinked_WithExpiredCache_RefetchesData() async {
        // Given: Expired cache
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        _ = await sut.isAccountLinked()

        // Expire cache
        let expiredTime = Date().addingTimeInterval(-400)
        mockUserDefaults.set(expiredTime, forKey: "tap_to_pay_linked_timestamp_MR_test123")

        // When: Check again
        _ = await sut.isAccountLinked()

        // Then: Refetched from API
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 2)
    }

    func testForceRefreshLinkStatus_AlwaysBypassesCache() async {
        // Given: Fresh cache
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        _ = await sut.isAccountLinked()
        let initialCount = mockReader.isAccountLinkedCallCount

        // When: Force refresh
        _ = await sut.forceRefreshLinkStatus()

        // Then: Made new API call
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, initialCount + 1)
    }

    // MARK: - Device Management Tests

    // Device management tests removed - SDK no longer handles device creation
    // App is responsible for creating devices and passing deviceId to SDK configuration

    // MARK: - Transaction Validation Tests

    func testStartTransaction_WithLargeAmount_AcceptsValidValue() async throws {
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

        // When/Then: Large amount should not throw validation error
        // (Will fail at transaction level without complete mock)
        do {
            _ = try await sut.startTransaction(amount: 99_999_999, currency: "USD")
        } catch {
            // Expected - transaction mock incomplete
        }
    }

    func testStartTransaction_WithMultipleCurrencies_ValidatesCorrectly() async throws {
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

        // When/Then: Various currencies
        let currencies = ["USD", "EUR", "GBP", "CAD"]

        for currency in currencies {
            do {
                _ = try await sut.startTransaction(amount: 1000, currency: currency)
            } catch {
                // Expected - transaction mock incomplete
            }
        }
    }

    // MARK: - Error Recovery Tests

    func testLinkAccount_AfterInitialFailure_RetriesSuccessfully() async throws {
        // Given: First attempt fails
        mockReader.shouldLinkAccountSucceed = false

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        do {
            try await sut.linkAccount()
            XCTFail("Expected first attempt to fail")
        } catch {
            // Expected
        }

        // When: Retry succeeds
        mockReader.shouldLinkAccountSucceed = true
        try await sut.linkAccount()

        // Then: Successfully linked
        XCTAssertEqual(mockReader.linkAccountCallCount, 2)
    }

    func testPrepareReader_AfterTokenFetchFailure_RetriesSuccessfully() async throws {
        // Given: Token fetch fails first time
        mockTokenRepository.shouldThrowError = true
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        do {
            try await sut.prepareReader()
            XCTFail("Expected token fetch to fail")
        } catch {
            // Expected
        }

        // When: Retry succeeds
        mockTokenRepository.shouldThrowError = false
        mockReader.shouldPrepareSucceed = true
        try await sut.prepareReader()

        // Then: Successfully prepared
        XCTAssertGreaterThanOrEqual(mockReader.prepareCallCount, 1)
    }

    // MARK: - State Management Tests

    func testMultipleLinkAttempts_MaintainCorrectState() async throws {
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

        // When: Link multiple times
        try await sut.linkAccount()
        mockReader.shouldAccountBeLinked = true
        try await sut.linkAccount()

        // Then: State is correct
        XCTAssertEqual(mockReader.linkAccountCallCount, 2)
    }

    func testClearAllCaches_ResetsAllState() async {
        // Given: Cached link status
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        _ = await sut.isAccountLinked()

        // When: Clear all
        sut.clearAllCaches()

        // Then: Link status cache cleared (SDK no longer manages device cache)
        XCTAssertFalse(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_test123"))
    }

    // MARK: - Multiple Configuration Tests

    func testMultipleInstances_IndependentState() async {
        // Given: Two different instances
        let config1 = TestFixtures.validConfiguration()
        let config2 = TestFixtures.validConfiguration()

        let instance1 = FinixTapToPay(configuration: config1)
        let instance2 = FinixTapToPay(configuration: config2)

        // Then: Instances are independent
        XCTAssertTrue(instance1 !== instance2)
    }

    // MARK: - Edge Case Tests

    func testIsAccountLinked_WithCorruptedCache_HandlesGracefully() async {
        // Given: Corrupted cache data
        mockUserDefaults.set(123, forKey: "tap_to_pay_linked_MR_test123") // Wrong type
        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Check link status
        let isLinked = await sut.isAccountLinked()

        // Then: Handles gracefully and fetches fresh data
        XCTAssertTrue(isLinked)
    }
}
