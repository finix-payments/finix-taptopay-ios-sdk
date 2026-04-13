//
//  CachingPerformanceTests.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import XCTest

@available(iOS 16.4, *)
final class CachingPerformanceTests: XCTestCase {
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

        mockReader.shouldAccountBeLinked = true

        sut = FinixTapToPay(
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

    // MARK: - Link Status Cache Performance

    func testPerformance_LinkStatusCacheHit() async {
        // Given: Populate cache
        _ = await sut.isAccountLinked()

        // Measure: Cache hit performance - should be very fast
        let startTime = Date()
        _ = await sut.isAccountLinked()
        let duration = Date().timeIntervalSince(startTime)

        // Cache hit should be extremely fast (under 0.1 seconds)
        XCTAssertLessThan(duration, 0.1, "Cache hit should be very fast")

        // Verify only one API call was made
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1, "Should use cache")
    }

    func testPerformance_LinkStatusCacheMiss() async {
        // Measure: Cache miss (first call) - should complete in reasonable time
        let startTime = Date()
        _ = await sut.isAccountLinked()
        let duration = Date().timeIntervalSince(startTime)

        // Cache miss should complete within 2 seconds (network dependent)
        XCTAssertLessThan(duration, 2.0, "Cache miss should complete in reasonable time")

        // Verify API was called
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1, "Should call API on cache miss")
    }

    // MARK: - Device ID Cache Performance

    // Device ID caching test removed - SDK no longer handles device creation

    // MARK: - Cache Clear Performance

    func testPerformance_ClearAllCaches() async {
        // Given: Multiple cached values
        _ = await sut.isAccountLinked()
        mockUserDefaults.set("DV_test", forKey: "tap_to_pay_device_id_MR_test123")
        mockUserDefaults.set("extra_data", forKey: "extra_key")

        // Measure: Cache clearing performance
        measure {
            sut.clearAllCaches()
        }
    }

    // MARK: - Force Refresh Performance

    func testPerformance_ForceRefreshLinkStatus() async {
        // Measure: Force refresh bypasses cache - should complete in reasonable time
        let startTime = Date()
        _ = await sut.forceRefreshLinkStatus()
        let duration = Date().timeIntervalSince(startTime)

        // Force refresh should complete within 2 seconds (network dependent)
        XCTAssertLessThan(duration, 2.0, "Force refresh should complete in reasonable time")

        // Verify API was called
        XCTAssertEqual(mockReader.isAccountLinkedCallCount, 1, "Should call API on force refresh")
    }

    // MARK: - Cache Speedup Verification

    func testCacheSpeedup_LinkStatusCheck() async {
        // Measure first call (cache miss)
        let startMiss = Date()
        _ = await sut.isAccountLinked()
        let durationMiss = Date().timeIntervalSince(startMiss)

        // Measure second call (cache hit)
        let startHit = Date()
        _ = await sut.isAccountLinked()
        let durationHit = Date().timeIntervalSince(startHit)

        // Verify cache is significantly faster
        XCTAssertLessThan(durationHit, durationMiss / 10, "Cache hit should be at least 10x faster")
    }

    // MARK: - Additional Performance Tests

    func testPerformance_ClearLinkStatusOnly() async {
        // Given: Link status cached
        _ = await sut.isAccountLinked()

        // Measure: Clearing just link status
        measure {
            sut.clearLinkStatus()
        }
    }

    func testPerformance_RefreshConfiguration() async throws {
        // Given: Prepared reader with caches
        mockReader.shouldPrepareSucceed = true
        try await sut.prepareReader()

        // Measure: Configuration refresh
        measure {
            sut.refreshConfiguration()
        }
    }

    func testPerformance_MultipleSequentialLinkChecks() async {
        // Given: Account linked and cache populated
        _ = await sut.isAccountLinked()

        let initialCallCount = mockReader.isAccountLinkedCallCount

        // Measure: Multiple sequential checks (all using cache)
        let startTime = Date()
        for _ in 0 ..< 100 {
            _ = await sut.isAccountLinked()
        }
        let duration = Date().timeIntervalSince(startTime)

        // Verify: No additional API calls made (all from cache)
        XCTAssertEqual(
            mockReader.isAccountLinkedCallCount,
            initialCallCount,
            "Should use cache for all subsequent calls"
        )

        // Verify performance is reasonable (100 cache hits should be very fast)
        XCTAssertLessThan(duration, 0.1, "100 cache hits should complete in under 0.1 seconds")
    }

    // Device creation performance test removed - SDK no longer handles device creation
}
