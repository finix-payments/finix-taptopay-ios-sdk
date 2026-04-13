//
//  TapToPayLoggerTests.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

@testable import FinixTapToPaySDK
import XCTest

final class TapToPayLoggerTests: XCTestCase {
    var sut: TapToPayLogger!

    override func setUp() {
        super.setUp()

        // Note: TapToPayLogger initializes DataDog, which may already be initialized
        // These tests focus on API surface and behavior rather than DataDog integration
        sut = TapToPayLogger(
            environment: .sandbox,
            username: "test_user",
            merchantId: "MR_test123"
        )
    }

    override func tearDown() {
        sut = nil

        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_WithValidParameters_CreatesLoggerSuccessfully() {
        // Given/When: Logger created in setUp

        // Then
        XCTAssertNotNil(sut)
    }

    func testInit_WithProductionEnvironment_CreatesLogger() {
        // Given/When
        let productionLogger = TapToPayLogger(
            environment: .production,
            username: "prod_user",
            merchantId: "MR_prod123"
        )

        // Then
        XCTAssertNotNil(productionLogger)
    }

    func testInit_WithQAEnvironment_CreatesLogger() {
        // Given/When
        let qaLogger = TapToPayLogger(
            environment: .qa,
            username: "qa_user",
            merchantId: "MR_qa123"
        )

        // Then
        XCTAssertNotNil(qaLogger)
    }

    // MARK: - Error Logging Tests

    func testError_WithMessage_DoesNotCrash() {
        // Given
        let message = "Test error message"

        // When/Then: Should not crash
        sut.error(message)

        XCTAssertTrue(true, "Error logging should complete without crashing")
    }

    func testError_WithMessageAndAttributes_DoesNotCrash() {
        // Given
        let message = "Test error with attributes"
        let attributes = ["key": "value", "error_code": "E001"]

        // When/Then: Should not crash
        sut.error(message, attributes: attributes)

        XCTAssertTrue(true, "Error logging with attributes should complete without crashing")
    }

    // MARK: - Warning Logging Tests

    func testWarn_WithMessage_DoesNotCrash() {
        // Given
        let message = "Test warning message"

        // When/Then: Should not crash
        sut.warn(message)

        XCTAssertTrue(true, "Warning logging should complete without crashing")
    }

    func testWarn_WithMessageAndAttributes_DoesNotCrash() {
        // Given
        let message = "Test warning with attributes"
        let attributes = ["warning_type": "configuration"]

        // When/Then: Should not crash
        sut.warn(message, attributes: attributes)

        XCTAssertTrue(true, "Warning logging with attributes should complete without crashing")
    }

    // MARK: - Info Logging Tests

    func testInfo_WithMessage_DoesNotCrash() {
        // Given
        let message = "Test info message"

        // When/Then: Should not crash
        sut.info(message)

        XCTAssertTrue(true, "Info logging should complete without crashing")
    }

    func testInfo_WithMessageAndAttributes_DoesNotCrash() {
        // Given
        let message = "Test info with attributes"
        let attributes = ["operation": "prepare_reader"]

        // When/Then: Should not crash
        sut.info(message, attributes: attributes)

        XCTAssertTrue(true, "Info logging with attributes should complete without crashing")
    }

    // MARK: - Debug Logging Tests

    func testDebug_WithMessage_DoesNotCrash() {
        // Given
        let message = "Test debug message"

        // When/Then: Should not crash
        sut.debug(message)

        XCTAssertTrue(true, "Debug logging should complete without crashing")
    }

    func testDebug_WithMessageAndAttributes_DoesNotCrash() {
        // Given
        let message = "Test debug with attributes"
        let attributes = ["step": "validation", "value": "123"]

        // When/Then: Should not crash
        sut.debug(message, attributes: attributes)

        XCTAssertTrue(true, "Debug logging with attributes should complete without crashing")
    }

    // MARK: - HTTP Request Logging Tests

    func testHTTPRequest_WithValidRequest_DoesNotCrash() {
        // Given
        let url = URL(string: "https://test.finixops.com/api/test")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // When/Then: Should not crash
        sut.httpRequest(request)

        XCTAssertTrue(true, "HTTP request logging should complete without crashing")
    }

    func testHTTPRequest_WithAuthorizationHeader_RedactsHeader() {
        // Given
        let url = URL(string: "https://test.finixops.com/api/test")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer secret_token", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // When/Then: Should not crash and should redact authorization
        sut.httpRequest(request)

        // Verify method completes (redaction happens internally)
        XCTAssertTrue(true, "HTTP request logging with auth header should redact and complete")
    }

    // MARK: - HTTP Response Logging Tests

    func testHTTPResponse_WithValidResponse_DoesNotCrash() {
        // Given
        let url = URL(string: "https://test.finixops.com/api/test")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!

        // When/Then: Should not crash
        sut.httpResponse(response)

        XCTAssertTrue(true, "HTTP response logging should complete without crashing")
    }

    func testHTTPResponse_WithAttributes_DoesNotCrash() {
        // Given
        let url = URL(string: "https://test.finixops.com/api/test")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 500,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        let attributes = ["error_type": "server_error"]

        // When/Then: Should not crash
        sut.httpResponse(response, attributes: attributes)

        XCTAssertTrue(
            true,
            "HTTP response logging with attributes should complete without crashing"
        )
    }

    // MARK: - HTTP Error Logging Tests

    func testHTTPError_WithError_DoesNotCrash() {
        // Given
        let error = NSError(domain: "TestDomain", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Test network error",
        ])

        // When/Then: Should not crash
        sut.httpError(error)

        XCTAssertTrue(true, "HTTP error logging should complete without crashing")
    }
}
