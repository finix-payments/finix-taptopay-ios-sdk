//
//  MockNotificationCenter.swift
//  FinixTapToPaySDKTests
//
//  Created by Israrul Haque on 06/04/26.
//

import Foundation
import UIKit

final class MockNotificationCenter: NotificationCenter {
    // MARK: - Properties

    /// Registered observers
    private var observers: [(
        name: Notification.Name?,
        object: Any?,
        queue: OperationQueue?,
        block: (Notification) -> Void
    )] = []

    /// Posted notifications for verification
    private(set) var postedNotifications: [(name: Notification.Name, object: Any?)] = []

    // MARK: - Override NotificationCenter Methods

    override func addObserver(
        forName name: NSNotification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        let observer = (name: name, object: obj, queue: queue, block: block)
        observers.append(observer)
        return NSObject() // Return dummy object (normally would be used to remove observer)
    }

    override func post(name aName: NSNotification.Name, object anObject: Any?) {
        postedNotifications.append((name: aName, object: anObject))

        // Trigger observers
        for observer in observers {
            // Check if observer is listening for this notification
            if let observerName = observer.name, observerName != aName {
                continue
            }

            // Check if observer is listening for this object
            if let observerObject = observer.object,
               observerObject as AnyObject !== anObject as AnyObject
            {
                continue
            }

            // Create notification
            let notification = Notification(name: aName, object: anObject)

            // Call observer block on the appropriate queue
            if let queue = observer.queue {
                queue.addOperation {
                    observer.block(notification)
                }
            } else {
                observer.block(notification)
            }
        }
    }

    override func post(_ notification: Notification) {
        post(name: notification.name, object: notification.object)
    }

    override func removeObserver(_: Any) {
        // In a more sophisticated mock, we'd track observers by identity
        // For testing purposes, this basic implementation is sufficient
    }

    // MARK: - Test Helpers

    /// Reset all observers and posted notifications
    func reset() {
        observers.removeAll()
        postedNotifications.removeAll()
    }

    /// Check if a notification was posted
    func wasNotificationPosted(_ name: Notification.Name) -> Bool {
        postedNotifications.contains { $0.name == name }
    }

    /// Get count of times a notification was posted
    func notificationPostCount(_ name: Notification.Name) -> Int {
        postedNotifications.filter { $0.name == name }.count
    }

    /// Get count of registered observers
    func observerCount() -> Int {
        observers.count
    }

    /// Get count of observers for a specific notification
    func observerCount(for name: Notification.Name) -> Int {
        observers.filter { $0.name == name }.count
    }

    /// Manually trigger foreground notification (for testing app lifecycle)
    func triggerForegroundNotification() {
        post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    /// Manually trigger background notification (for testing app lifecycle)
    func triggerBackgroundNotification() {
        post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
}
