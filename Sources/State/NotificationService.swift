import Foundation
import UserNotifications

/// Abstraction over `UNUserNotificationCenter` so notification behaviour is
/// testable without the system framework (TKT-M5-04).
protocol NotificationDispatching: Sendable {
    func authorizationStatus() async -> NotificationPermission
    func requestAuthorization() async -> NotificationPermission
    func post(title: String, body: String) async
}

/// Real implementation backed by `UNUserNotificationCenter`.
final class SystemNotificationService: NotificationDispatching {
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> NotificationPermission {
        let settings = await center.notificationSettings()
        return Self.map(settings.authorizationStatus)
    }

    func requestAuthorization() async -> NotificationPermission {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return .denied
        }
        return await authorizationStatus()
    }

    func post(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }

    static func map(_ status: UNAuthorizationStatus) -> NotificationPermission {
        switch status {
        case .authorized, .ephemeral: return .authorized
        case .provisional: return .provisional
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
}

/// Decides and delivers completion notifications, respecting the user toggle and
/// the OS authorization state.
@MainActor
final class NotificationCoordinator: ObservableObject {
    private let service: NotificationDispatching
    private var requestedOnce = false

    init(service: NotificationDispatching = SystemNotificationService()) {
        self.service = service
    }

    /// Notifies about a finished task when enabled and permitted.
    func notifyTaskFinished(record: TaskRecord, enabled: Bool) async {
        guard enabled else { return }
        var permission = await service.authorizationStatus()
        if permission == .notDetermined, !requestedOnce {
            requestedOnce = true
            permission = await service.requestAuthorization()
        }
        guard NotificationPolicy.shouldDeliver(permission: permission, userEnabled: enabled) else { return }

        switch record.state {
        case .succeeded:
            await service.post(title: record.title, body: "Completed successfully.")
        case .failed:
            await service.post(title: record.title, body: record.errorDescription ?? "Failed.")
        default:
            break
        }
    }
}
