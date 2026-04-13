//
//  TapToPayTokenRepositoryProtocol.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation

protocol TapToPayTokenRepositoryProtocol {
    /// Fetch JWT token from backend
    /// - Parameters:
    ///   - merchantId: Merchant ID (for logging only, not sent to backend)
    ///   - merchantMid: Merchant MID (for logging only, not sent to backend)
    ///   - includeDevice: Deprecated - device_id is now always required by backend
    ///   - deviceId: Device ID (REQUIRED - backend API now uses device_id instead of merchant_id)
    /// - Returns: JWT token string
    func fetchToken(
        merchantId: String,
        merchantMid: String,
        includeDevice: Bool,
        deviceId: String?
    ) async throws -> String
}
