//
//  IntegrationTests.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import XCTest

@available(iOS 16.4, *)
final class IntegrationTests: XCTestCase {
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

    // MARK: - Account Linking Flow Tests

    func testAccountLinkingFlow_CheckNotLinked_ThenLink_ThenCheckLinked() async throws {
        // Given
        mockReader.shouldAccountBeLinked = false
        mockReader.shouldLinkAccountSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Check status
        let initialStatus = await sut.isAccountLinked()
        XCTAssertFalse(initialStatus, "Should not be linked initially")

        // Link account
        try await sut.linkAccount()
        mockReader.shouldAccountBeLinked = true

        // Check status again (force refresh to bypass cache)
        let finalStatus = await sut.forceRefreshLinkStatus()

        // Then
        XCTAssertTrue(finalStatus, "Should be linked after linking")
        XCTAssertEqual(mockReader.linkAccountCallCount, 1)
    }

    func testAccountLinkingFlow_WithAlreadyLinkedAccount_SuccessfullyLinks() async throws {
        // Given: Already linked
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldLinkAccountSucceed = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: Try to link
        try await sut.linkAccount()

        // Then: Should succeed
        XCTAssertEqual(mockReader.linkAccountCallCount, 1)
    }

    // MARK: - Transaction Flow Tests

    func testTransactionFlow_LinkPrepareStart() async throws {
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

        // When: Complete flow
        try await sut.linkAccount()
        mockReader.shouldAccountBeLinked = true
        try await sut.prepareReader()

        // Then: Ready for transaction
        XCTAssertEqual(mockReader.linkAccountCallCount, 1)
        XCTAssertEqual(mockReader.prepareCallCount, 1)
    }

    func testTransactionFlow_PrepareMultipleTimes_ReusesPreparedReader() async throws {
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

        // When: Prepare multiple times
        try await sut.prepareReader()
        try await sut.prepareReader()

        // Then: Prepare can be called multiple times
        XCTAssertEqual(mockReader.prepareCallCount, 2)
    }

    func testTransactionFlow_AfterRefreshConfiguration_RequiresNewPrepare() async throws {
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
        let initialPrepareCount = mockReader.prepareCallCount

        // When: Refresh and prepare again
        sut.refreshConfiguration()
        try await sut.prepareReader()

        // Then: Prepared again
        XCTAssertGreaterThan(mockReader.prepareCallCount, initialPrepareCount)
    }

    // MARK: - Error Recovery Tests

    func testErrorRecovery_LinkFails_ThenRetrySucceeds() async throws {
        // Given
        mockReader.shouldLinkAccountSucceed = false

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: First attempt fails
        do {
            try await sut.linkAccount()
            XCTFail("Should throw error")
        } catch {
            // Expected
        }

        // Retry succeeds
        mockReader.shouldLinkAccountSucceed = true
        try await sut.linkAccount()

        // Then: Eventually succeeds
        XCTAssertEqual(mockReader.linkAccountCallCount, 2)
    }

    func testErrorRecovery_PrepareFails_ThenRetrySucceeds() async throws {
        // Given
        mockReader.shouldAccountBeLinked = true
        mockReader.shouldPrepareSucceed = false

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: First attempt fails
        do {
            try await sut.prepareReader()
            XCTFail("Should throw error")
        } catch {
            // Expected
        }

        // Retry succeeds
        mockReader.shouldPrepareSucceed = true
        try await sut.prepareReader()

        // Then: Eventually succeeds
        XCTAssertGreaterThanOrEqual(mockReader.prepareCallCount, 1)
    }

    func testErrorRecovery_TokenFetchFails_ThenRetrySucceeds() async throws {
        // Given
        mockTokenRepository.shouldThrowError = true

        sut = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        // When: First attempt fails
        do {
            try await sut.linkAccount()
            XCTFail("Should throw error")
        } catch {
            // Expected
        }

        // Retry succeeds
        mockTokenRepository.shouldThrowError = false
        mockReader.shouldLinkAccountSucceed = true
        try await sut.linkAccount()

        // Then: Eventually succeeds
        XCTAssertEqual(mockReader.linkAccountCallCount, 1)
    }

    // MARK: - Cache Integration Tests

    func testCacheIntegration_LinkStatusPersistsAcrossInstances() async throws {
        // Given: First instance checks and caches status
        mockReader.shouldAccountBeLinked = true

        let instance1 = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        _ = await instance1.isAccountLinked()

        // When: Create second instance with same UserDefaults
        let instance2 = FinixTapToPay(
            configuration: TestFixtures.validConfiguration(),
            readerFactory: { self.mockReader },
            userDefaults: mockUserDefaults,
            notificationCenter: mockNotificationCenter,
            repository: mockTokenRepository
        )

        let cachedStatus = await instance2.isAccountLinked()

        // Then: Second instance uses cache
        XCTAssertTrue(cachedStatus)
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1, "Should only call API once")
    }

    func testCacheIntegration_ClearAllCaches_AffectsBothLinkAndDevice() async throws {
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

        _ = await sut.isAccountLinked()
        try await sut.prepareReader()

        // When: Clear all caches
        sut.clearAllCaches()

        // Then: Both caches cleared
        XCTAssertFalse(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_test123"))
        XCTAssertNil(mockUserDefaults.string(forKey: "tap_to_pay_device_id_MR_test123"))

        // Next check should hit API
        _ = await sut.isAccountLinked()
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 2)
    }

    // MARK: - Configuration Change Tests

    // Device creation test removed - SDK no longer handles device creation

    // MARK: - Multi-Merchant Tests

    func testMultiMerchant_DifferentMerchants_IndependentCaches() async throws {
        // Given: Two different merchant configurations
        let config1 = TapToPayConfiguration(
            credentials: TapToPayConfiguration.APICredentials(username: "user1", password: "pass1"),
            merchant: TapToPayConfiguration.MerchantInfo(
                merchantId: "MR_merchant1",
                merchantMid: "mid1",
                merchantName: "Merchant 1"
            ),
            environment: .sandbox,
            deviceId: "DV_test123"
        )

        let config2 = TapToPayConfiguration(
            credentials: TapToPayConfiguration.APICredentials(username: "user2", password: "pass2"),
            merchant: TapToPayConfiguration.MerchantInfo(
                merchantId: "MR_merchant2",
                merchantMid: "mid2",
                merchantName: "Merchant 2"
            ),
            environment: .sandbox,
            deviceId: "DV_test123"
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

        // When: Both check status
        _ = await instance1.isAccountLinked()
        _ = await instance2.isAccountLinked()

        // Then: Independent caches
        XCTAssertTrue(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_merchant1"))
        XCTAssertTrue(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_merchant2"))

        // Clearing one doesn't affect the other
        instance1.clearLinkStatus()
        XCTAssertFalse(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_merchant1"))
        XCTAssertTrue(mockUserDefaults.hasValue(forKey: "tap_to_pay_linked_MR_merchant2"))
    }

    // MARK: - Full Lifecycle Test

    func testFullLifecycle_CheckLinkPrepareClearRepeat() async throws {
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

        // Phase 1: Check not linked
        let status1 = await sut.isAccountLinked()
        XCTAssertFalse(status1)

        // Phase 2: Link account
        try await sut.linkAccount()
        mockReader.shouldAccountBeLinked = true

        // Phase 3: Verify linked
        let status2 = await sut.forceRefreshLinkStatus()
        XCTAssertTrue(status2)

        // Phase 4: Prepare reader
        try await sut.prepareReader()
        XCTAssertEqual(mockReader.prepareCallCount, 1)

        // Phase 5: Clear all caches
        sut.clearAllCaches()

        // Phase 6: Verify caches cleared
        let status3 = await sut.isAccountLinked()
        XCTAssertTrue(status3) // Still linked but fetched fresh

        // Phase 7: Prepare again (with cache cleared)
        try await sut.prepareReader()

        // Then: Full lifecycle completed
        XCTAssertEqual(mockReader.linkAccountCallCount, 1)
        XCTAssertGreaterThanOrEqual(mockReader.prepareCallCount, 1)
    }
}
