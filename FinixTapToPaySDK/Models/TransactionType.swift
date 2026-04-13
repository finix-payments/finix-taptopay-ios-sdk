//
//  TransactionType.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation

/// Transaction type for Tap to Pay transactions
public enum TransactionType: String, Encodable, CaseIterable {
    case sale = "SALE"
    case authorization = "AUTHORIZATION"
    case refund = "REFUND"

    /// Display name for UI
    public var displayName: String {
        switch self {
            case .sale:
                "Sale"
            case .authorization:
                "Authorization"
            case .refund:
                "Refund"
        }
    }
}
