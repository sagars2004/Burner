import Foundation
import UserNotifications

public class NotificationManager {
    public static let shared = NotificationManager()
    private var lastNotifiedTimes: [String: Date] = [:]

    private init() {
        requestAuthorization()
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    public func sendAlert(title: String, subtitle: String, body: String, identifier: String) {
        // Debounce notifications per identifier (min 2 minutes apart)
        if let last = lastNotifiedTimes[identifier], Date().timeIntervalSince(last) < 120 {
            return
        }
        lastNotifiedTimes[identifier] = Date()

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(identifier)-\(UUID().uuidString)",
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to deliver notification: \(error)")
            }
        }
    }
}
