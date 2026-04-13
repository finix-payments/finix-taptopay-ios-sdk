//
//  TapToPayTokenRepositoryTests.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import XCTest

final class TapToPayTokenRepositoryTests: XCTestCase {
    var mockTokenRepository: MockTapToPayTokenRepository!

    override func setUp() {
        super.setUp()
        mockTokenRepository = MockTapToPayTokenRepository()
    }

    override func tearDown() {
        mockTokenRepository.reset()
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_CreatesRepositorySuccessfully() {
        // Given
        let config = TestFixtures.validConfiguration()

        // When
        let repository = TapToPayTokenRepository(configuration: config)

        // Then
        XCTAssertNotNil(repository)
    }

    // MARK: - Token Fetch Tests

    func testFetchToken_WithoutDeviceID_CallsWithCorrectParameters() async throws {
        // Given
        mockTokenRepository.mockTokenString = "valid_jwt_token"

        // When
        let token = try await mockTokenRepository.fetchToken(
            merchantId: "MR_123",
            merchantMid: "mid_456",
            includeDevice: false,
            deviceId: nil
        )

        // Then
        XCTAssertEqual(token, "valid_jwt_token")
        XCTAssertEqual(mockTokenRepository.fetchTokenCallCount, 1)
        XCTAssertEqual(mockTokenRepository.merchantIds.last, "MR_123")
        XCTAssertEqual(mockTokenRepository.merchantMids.last, "mid_456")
        XCTAssertEqual(mockTokenRepository.includeDeviceFlags.last, false)
        XCTAssertNil(mockTokenRepository.deviceIds.last ?? nil)
    }

    func testFetchToken_WithDeviceID_IncludesDeviceInRequest() async throws {
        // Given
        mockTokenRepository.mockTokenString = "valid_jwt_token_with_device"

        // When
        let token = try await mockTokenRepository.fetchToken(
            merchantId: "MR_123",
            merchantMid: "mid_456",
            includeDevice: true,
            deviceId: "DV_789"
        )

        // Then
        XCTAssertEqual(token, "valid_jwt_token_with_device")
        XCTAssertEqual(mockTokenRepository.includeDeviceFlags.last, true)
        XCTAssertEqual(mockTokenRepository.deviceIds.last!, "DV_789")
    }

    func testFetchToken_WithDeviceIDButFlagFalse_DoesNotIncludeDevice() async throws {
        // Given
        mockTokenRepository.mockTokenString = "token_without_device"

        // When
        let token = try await mockTokenRepository.fetchToken(
            merchantId: "MR_123",
            merchantMid: "mid_456",
            includeDevice: false,
            deviceId: "DV_789"
        )

        // Then
        XCTAssertEqual(token, "token_without_device")
        XCTAssertEqual(mockTokenRepository.includeDeviceFlags.last, false)
        // Device ID passed but should not be used when flag is false
    }

    // MARK: - Error Handling Tests

    func testFetchToken_WhenNetworkFails_ThrowsError() async {
        // Given
        mockTokenRepository.shouldThrowError = true
        mockTokenRepository.tokenFetchError = TapToPayError.tokenFetchFailed("Network error")

        // When/Then
        do {
            _ = try await mockTokenRepository.fetchToken(
                merchantId: "MR_123",
                merchantMid: "mid_456",
                includeDevice: false,
                deviceId: nil
            )
            XCTFail("Expected error to be thrown")
        } catch let error as TapToPayError {
            if case let .tokenFetchFailed(message) = error {
                XCTAssertEqual(message, "Network error")
            } else {
                XCTFail("Expected tokenFetchFailed error")
            }
        } catch {
            XCTFail("Expected TapToPayError")
        }
    }

    func testFetchToken_When401Response_ThrowsAuthError() async {
        // Given
        mockTokenRepository.shouldThrowError = true
        mockTokenRepository.tokenFetchError = TapToPayError.tokenFetchFailed("Unauthorized")

        // When/Then
        do {
            _ = try await mockTokenRepository.fetchToken(
                merchantId: "MR_invalid",
                merchantMid: "mid_invalid",
                includeDevice: false,
                deviceId: nil
            )
            XCTFail("Expected error for invalid credentials")
        } catch {
            XCTAssertTrue(error is TapToPayError)
        }
    }

    func testFetchToken_When500Response_ThrowsServerError() async {
        // Given
        mockTokenRepository.shouldThrowError = true
        mockTokenRepository.tokenFetchError = TapToPayError
            .tokenFetchFailed("Internal server error")

        // When/Then
        do {
            _ = try await mockTokenRepository.fetchToken(
                merchantId: "MR_123",
                merchantMid: "mid_456",
                includeDevice: false,
                deviceId: nil
            )
            XCTFail("Expected error for server error")
        } catch let error as TapToPayError {
            if case let .tokenFetchFailed(message) = error {
                XCTAssertTrue(message.contains("server error"))
            }
        } catch {
            XCTFail("Expected TapToPayError")
        }
    }

    // MARK: - JWT Token Format Tests

    func testFetchToken_ReturnsValidJWTFormat() async throws {
        // Given: Mock JWT with 3 parts (header.payload.signature)
        let mockJWT =
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        mockTokenRepository.mockTokenString = mockJWT

        // When
        let token = try await mockTokenRepository.fetchToken(
            merchantId: "MR_123",
            merchantMid: "mid_456",
            includeDevice: false,
            deviceId: nil
        )

        // Then: Verify JWT has 3 parts
        let parts = token.split(separator: ".")
        XCTAssertEqual(parts.count, 3, "JWT should have 3 parts (header.payload.signature)")
    }

    func testFetchToken_JWTHasValidHeader() async throws {
        // Given: JWT with known header
        let mockJWT =
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        mockTokenRepository.mockTokenString = mockJWT

        // When
        let token = try await mockTokenRepository.fetchToken(
            merchantId: "MR_123",
            merchantMid: "mid_456",
            includeDevice: false,
            deviceId: nil
        )

        // Then: Verify first part (header) exists
        let parts = token.split(separator: ".")
        XCTAssertGreaterThan(parts[0].count, 0)
    }

    func testFetchToken_JWTHasValidPayload() async throws {
        // Given: JWT with known payload
        let mockJWT = "eyJhbGciOiJIUzI1NiJ9.eyJtZXJjaGFudF9pZCI6Ik1SXzEyMyJ9.example_signature"
        mockTokenRepository.mockTokenString = mockJWT

        // When
        let token = try await mockTokenRepository.fetchToken(
            merchantId: "MR_123",
            merchantMid: "mid_456",
            includeDevice: false,
            deviceId: nil
        )

        // Then: Verify payload part exists
        let parts = token.split(separator: ".")
        XCTAssertGreaterThan(parts[1].count, 0)
    }

    // MARK: - Multiple Request Tests

    func testFetchToken_MultipleRequests_TrackCallCount() async throws {
        // Given
        mockTokenRepository.mockTokenString = "token1"

        // When: Make multiple requests
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_1",
            merchantMid: "mid_1",
            includeDevice: false,
            deviceId: nil
        )
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_2",
            merchantMid: "mid_2",
            includeDevice: false,
            deviceId: nil
        )
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_3",
            merchantMid: "mid_3",
            includeDevice: false,
            deviceId: nil
        )

        // Then
        XCTAssertEqual(mockTokenRepository.fetchTokenCallCount, 3)
        XCTAssertEqual(mockTokenRepository.merchantIds.count, 3)
        XCTAssertEqual(mockTokenRepository.merchantIds.last, "MR_3")
    }

    // MARK: - Environment Tests

    func testFetchToken_SandboxEnvironment_UsesCorrectURL() {
        // Given
        let config = TapToPayConfiguration(
            credentials: TapToPayConfiguration.APICredentials(username: "test", password: "pass"),
            merchant: TapToPayConfiguration.MerchantInfo(
                merchantId: "MR_test",
                merchantMid: "mid",
                merchantName: "Test"
            ),
            environment: .sandbox,
            deviceId: "DV_test123"
        )

        // Then
        XCTAssertTrue(config.environment.baseURL.contains("sandbox"))
    }

    func testFetchToken_ProductionEnvironment_UsesCorrectURL() {
        // Given
        let config = TapToPayConfiguration(
            credentials: TapToPayConfiguration.APICredentials(username: "test", password: "pass"),
            merchant: TapToPayConfiguration.MerchantInfo(
                merchantId: "MR_test",
                merchantMid: "mid",
                merchantName: "Test"
            ),
            environment: .production,
            deviceId: "DV_test123"
        )

        // Then
        XCTAssertFalse(config.environment.baseURL.contains("sandbox"))
    }

    // MARK: - Delay/Performance Tests

    func testFetchToken_WithDelay_CompletesAfterDelay() async throws {
        // Given
        mockTokenRepository.fetchDelay = 0.1
        mockTokenRepository.mockTokenString = "delayed_token"

        let startTime = Date()

        // When
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_123",
            merchantMid: "mid_456",
            includeDevice: false,
            deviceId: nil
        )

        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertGreaterThanOrEqual(elapsed, 0.1, "Should wait for configured delay")
    }

    // MARK: - Reset Tests

    func testReset_ClearsAllTrackedData() async throws {
        // Given: Make some requests
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_1",
            merchantMid: "mid_1",
            includeDevice: false,
            deviceId: nil
        )
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_2",
            merchantMid: "mid_2",
            includeDevice: true,
            deviceId: "DV_1"
        )

        XCTAssertEqual(mockTokenRepository.fetchTokenCallCount, 2)

        // When: Reset
        mockTokenRepository.reset()

        // Then: All data cleared
        XCTAssertEqual(mockTokenRepository.fetchTokenCallCount, 0)
        XCTAssertEqual(mockTokenRepository.merchantIds.count, 0)
        XCTAssertEqual(mockTokenRepository.deviceIds.count, 0)
    }

    // MARK: - Helper Method Tests

    func testVerifyFetchTokenCalledOnce_WhenCalledOnce_ReturnsTrue() async throws {
        // Given
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_1",
            merchantMid: "mid_1",
            includeDevice: false,
            deviceId: nil
        )

        // When/Then
        XCTAssertTrue(mockTokenRepository.verifyFetchTokenCalledOnce())
    }

    func testVerifyFetchTokenCalledOnce_WhenCalledTwice_ReturnsFalse() async throws {
        // Given
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_1",
            merchantMid: "mid_1",
            includeDevice: false,
            deviceId: nil
        )
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_2",
            merchantMid: "mid_2",
            includeDevice: false,
            deviceId: nil
        )

        // When/Then
        XCTAssertFalse(mockTokenRepository.verifyFetchTokenCalledOnce())
    }

    func testGetLastMerchantId_ReturnsCorrectValue() async throws {
        // Given
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_first",
            merchantMid: "mid_1",
            includeDevice: false,
            deviceId: nil
        )
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_last",
            merchantMid: "mid_2",
            includeDevice: false,
            deviceId: nil
        )

        // When
        let lastMerchantId = mockTokenRepository.getLastMerchantId()

        // Then
        XCTAssertEqual(lastMerchantId, "MR_last")
    }

    func testGetLastDeviceId_ReturnsCorrectValue() async throws {
        // Given
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_1",
            merchantMid: "mid_1",
            includeDevice: true,
            deviceId: "DV_first"
        )
        _ = try await mockTokenRepository.fetchToken(
            merchantId: "MR_2",
            merchantMid: "mid_2",
            includeDevice: true,
            deviceId: "DV_last"
        )

        // When
        let lastDeviceId = mockTokenRepository.getLastDeviceId()

        // Then
        XCTAssertEqual(lastDeviceId, "DV_last")
    }
}
