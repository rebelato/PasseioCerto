import Foundation
import UserNotifications

/// One local notification for when Margot gets hungry, scheduled as the app goes to the
/// background and withdrawn when it comes back. Only used when the player turned it on.
enum HungerReminder {
    private static let id = "margot-hungry"

    /// Asks for permission; returns whether reminders can be shown.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
    static func schedule(for pet: PetState, dogName: String, enabled: Bool, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard enabled, let wait = pet.timeUntilHungry(from: now), wait > 60 else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(dogName) está com fominha")
        content.body = String(localized: "Que tal um petisco e um passeio?")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
