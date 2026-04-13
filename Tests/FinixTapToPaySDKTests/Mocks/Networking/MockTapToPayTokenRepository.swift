//
//  MockTapToPayTokenRepository.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import Foundation

final class MockTapToPayTokenRepository: TapToPayTokenRepositoryProtocol {
    // MARK: - Configurable Behavior

    /// Mock token string to return (default JWT-like token)
    var mockTokenString: String =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6Ik1vY2sgVG9rZW4iLCJpYXQiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

    /// Whether fetchToken() should throw an error
    var shouldThrowError: Bool = false

    /// Error to throw when token fetch fails
    var tokenFetchError: Error?

    /// Simulated delay for token fetching (in seconds)
    var fetchDelay: TimeInterval = 0

    // MARK: - Call Tracking

    /// Number of times fetchToken() was called
    private(set) var fetchTokenCallCount = 0

    /// Merchant IDs passed to fetchToken()
    private(set) var merchantIds: [String] = []

    /// Merchant MIDs passed to fetchToken()
    private(set) var merchantMids: [String] = []

    /// Include device flags passed to fetchToken()
    private(set) var includeDeviceFlags: [Bool] = []

    /// Device IDs passed to fetchToken()
    private(set) var deviceIds: [String?] = []

    // MARK: - TapToPayTokenRepositoryProtocol Implementation

    func fetchToken(
        merchantId: String,
        merchantMid: String,
        includeDevice: Bool,
        deviceId: String?
    ) async throws -> String {
        fetchTokenCallCount += 1
        merchantIds.append(merchantId)
        merchantMids.append(merchantMid)
        includeDeviceFlags.append(includeDevice)
        deviceIds.append(deviceId)

        // Simulate delay if configured
        if fetchDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(fetchDelay * 1_000_000_000))
        }

        // Throw error if configured
        if shouldThrowError {
            throw tokenFetchError ?? TapToPayError.tokenFetchFailed("Mock token fetch failed")
        }

        // Return configured mock token
        return mockTokenString
    }

    // MARK: - Test Helpers

    /// Reset all tracked calls and behavior to defaults
    func reset() {
        // Reset call counts
        fetchTokenCallCount = 0
        merchantIds.removeAll()
        merchantMids.removeAll()
        includeDeviceFlags.removeAll()
        deviceIds.removeAll()

        // Reset behavior to defaults
        mockTokenString =
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6Ik1vY2sgVG9rZW4iLCJpYXQiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        shouldThrowError = false
        tokenFetchError = nil
        fetchDelay = 0
    }

    /// Verify that fetchToken was called exactly once
    func verifyFetchTokenCalledOnce() -> Bool {
        fetchTokenCallCount == 1
    }

    /// Get the last device ID used
    func getLastDeviceId() -> String? {
        deviceIds.last ?? nil
    }

    /// Get the last merchant ID used
    func getLastMerchantId() -> String? {
        merchantIds.last
    }

    /// Configure mock with a specific token string
    func configureMockToken(tokenString: String) {
        mockTokenString = tokenString
    }
}
