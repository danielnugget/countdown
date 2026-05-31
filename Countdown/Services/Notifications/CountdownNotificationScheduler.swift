import CountdownShared
import Foundation
import UserNotifications

final class CountdownNotificationScheduler {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func schedule(snapshot: CountdownSnapshot) async {
        guard snapshot.status == .running,
              snapshot.targetDate > Date(),
              let notificationDate = CountdownCalculator.notificationDate(
                targetDate: snapshot.targetDate,
                pausedRemainingSeconds: snapshot.pausedRemainingSeconds,
                now: Date()
              ) else {
            await cancel(identifier: snapshot.notificationIdentifier)
            return
        }

        guard await requestAuthorizationIfNeeded() else {
            return
        }

        let identifier = snapshot.notificationIdentifier ?? "countdown-\(snapshot.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = snapshot.title
        content.body = "Your countdown has finished."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: notificationDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            // Notification failures should not block countdown persistence.
        }
    }

    func cancel(identifier: String?) async {
        guard let identifier else {
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }
}
