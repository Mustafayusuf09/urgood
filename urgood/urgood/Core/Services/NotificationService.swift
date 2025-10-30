import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Service
class NotificationService: ObservableObject {
    @Published var hasPermission = false
    @Published var isEnabled = true
    
    private let center = UNUserNotificationCenter.current()
    private let localStore: LocalStore
    
    init(localStore: LocalStore) {
        self.localStore = localStore
        checkPermissionStatus()
    }
    
    // MARK: - Permission Management
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            _ = await MainActor.run {
                self.hasPermission = granted
            }
            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
    }
    
    private func checkPermissionStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleDailyReminder() {
        guard hasPermission else { return }
        
        // Cancel existing daily reminders
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        
        // Create daily reminder at 8pm
        let content = UNMutableNotificationContent()
        content.title = "Quick check-in?"
        content.body = "tap to keep your streak up 💫"
        content.sound = .default
        content.badge = 1
        
        // Schedule for 8pm daily
        var dateComponents = DateComponents()
        dateComponents.hour = 20 // 8pm
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule daily reminder: \(error)")
            } else {
                print("✅ Daily reminder scheduled for 8pm")
            }
        }
    }
    
    func scheduleContextualNudge() {
        guard hasPermission else { return }
        
        // Cancel existing contextual nudges
        center.removePendingNotificationRequests(withIdentifiers: ["contextual_nudge"])
        
        // Get the most recent mood entry to create contextual nudge
        guard let lastMoodEntry = localStore.moodEntries.last else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Reflection time"
        
        // Create contextual message based on last tag
        if let lastTag = lastMoodEntry.tags.first {
            content.body = "Yesterday you mentioned \(lastTag.name). Want to reflect again tonight?"
        } else {
            content.body = "How are you feeling today? Take a moment to check in ✨"
        }
        
        content.sound = .default
        content.badge = 1
        
        // Schedule for next day at 8pm (avoiding midnight-7am)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        dateComponents.hour = 20 // 8pm
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "contextual_nudge", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule contextual nudge: \(error)")
            } else {
                print("✅ Contextual nudge scheduled for tomorrow 8pm")
            }
        }
    }
    
    func scheduleStreakReminder() {
        guard hasPermission else { return }
        
        // Only schedule if user has a streak of 1 day or more
        let streakCount = calculateCurrentStreak()
        guard streakCount >= 1 else { return }
        
        // Cancel existing streak reminders
        center.removePendingNotificationRequests(withIdentifiers: ["streak_reminder"])
        
        let content = UNMutableNotificationContent()
        content.title = "Keep your streak alive! 🔥"
        content.body = "You're on a \(streakCount) day streak. Don't break it now!"
        content.sound = .default
        content.badge = 1
        
        // Schedule for 8pm today if not already past
        let now = Date()
        let calendar = Calendar.current
        let today8pm = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
        
        let trigger: UNNotificationTrigger
        if today8pm > now {
            // Schedule for today 8pm
            let timeInterval = today8pm.timeIntervalSince(now)
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        } else {
            // Schedule for tomorrow 8pm
            let tomorrow8pm = calendar.date(byAdding: .day, value: 1, to: today8pm) ?? now
            let timeInterval = tomorrow8pm.timeIntervalSince(now)
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        }
        
        let request = UNNotificationRequest(identifier: "streak_reminder", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule streak reminder: \(error)")
            } else {
                print("✅ Streak reminder scheduled")
            }
        }
    }
    
    // MARK: - Notification Management
    
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        print("🗑️ All notifications cancelled")
    }
    
    func cancelNotification(withIdentifier identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Notification cancelled: \(identifier)")
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }
    
    // MARK: - Helper Methods
    
    private func calculateCurrentStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        
        while true {
            let dayStart = currentDate
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? currentDate
            
            let hasCheckin = localStore.moodEntries.contains { entry in
                entry.date >= dayStart && entry.date < dayEnd
            }
            
            if hasCheckin {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    // MARK: - Public Methods
    
    func enableNotifications() {
        isEnabled = true
        if hasPermission {
            scheduleDailyReminder()
        }
    }
    
    func disableNotifications() {
        isEnabled = false
        cancelAllNotifications()
    }
    
    func toggleNotifications() {
        if isEnabled {
            disableNotifications()
        } else {
            enableNotifications()
        }
    }
    
    // MARK: - Smart Scheduling
    
    func scheduleSmartNotifications() {
        guard hasPermission && isEnabled else { return }
        
        // Cancel all existing notifications first
        cancelAllNotifications()
        
        // Schedule daily reminder
        scheduleDailyReminder()
        
        // Schedule contextual nudge for next day
        scheduleContextualNudge()
        
        // Schedule streak reminder if applicable
        scheduleStreakReminder()
    }
    
    // MARK: - Notification Actions
    
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let identifier = response.notification.request.identifier
        
        switch identifier {
        case "daily_reminder", "contextual_nudge", "streak_reminder":
            // Open app to check-in screen
            DispatchQueue.main.async {
                // In a real app, this would navigate to the check-in screen
                print("📱 Opening check-in screen from notification")
            }
        default:
            break
        }
    }
}

// MARK: - Notification Categories
extension NotificationService {
    func registerNotificationCategories() {
        let checkInAction = UNNotificationAction(
            identifier: "CHECK_IN",
            title: "Check In",
            options: [.foreground]
        )
        
        let remindLaterAction = UNNotificationAction(
            identifier: "REMIND_LATER",
            title: "Remind Later",
            options: []
        )
        
        let checkInCategory = UNNotificationCategory(
            identifier: "CHECK_IN_CATEGORY",
            actions: [checkInAction, remindLaterAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([checkInCategory])
    }
}
