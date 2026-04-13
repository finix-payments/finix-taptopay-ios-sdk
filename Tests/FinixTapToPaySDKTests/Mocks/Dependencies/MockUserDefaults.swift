//
//  MockUserDefaults.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation

final class MockUserDefaults: UserDefaults {
    // MARK: - In-Memory Storage

    private var storage: [String: Any] = [:]

    // MARK: - Override UserDefaults Methods

    override func set(_ value: Any?, forKey key: String) {
        storage[key] = value
    }

    override func string(forKey key: String) -> String? {
        storage[key] as? String
    }

    override func integer(forKey key: String) -> Int {
        storage[key] as? Int ?? 0
    }

    override func bool(forKey key: String) -> Bool {
        storage[key] as? Bool ?? false
    }

    override func double(forKey key: String) -> Double {
        storage[key] as? Double ?? 0.0
    }

    override func object(forKey key: String) -> Any? {
        storage[key]
    }

    override func array(forKey key: String) -> [Any]? {
        storage[key] as? [Any]
    }

    override func dictionary(forKey key: String) -> [String: Any]? {
        storage[key] as? [String: Any]
    }

    override func data(forKey key: String) -> Data? {
        storage[key] as? Data
    }

    override func removeObject(forKey key: String) {
        storage.removeValue(forKey: key)
    }

    // MARK: - Test Helpers

    /// Reset all stored values
    func reset() {
        storage.removeAll()
    }

    /// Check if a key exists in storage
    func hasValue(forKey key: String) -> Bool {
        storage[key] != nil
    }

    /// Get all stored keys
    func allKeys() -> [String] {
        Array(storage.keys)
    }

    /// Get count of stored items
    func count() -> Int {
        storage.count
    }

    /// Print all stored values (for debugging)
    func printAllValues() {
        print("MockUserDefaults contents:")
        for (key, value) in storage {
            print("  \(key): \(value)")
        }
    }
}
