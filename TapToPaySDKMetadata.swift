//
//  TapToPaySDKMetadata.swift
//  FinixTapToPaySDK
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation

/// Internal SDK metadata for logging and debugging
/// Not exposed to integrators - used by Finix support team only
internal enum TapToPaySDKMetadata {
    /// Current version of the FinixTapToPaySDK
    /// Used internally for DataDog logging and issue tracking
    static let version = "1.0.0"
}
