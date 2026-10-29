//
// NotificationManager.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
// 
//

import Foundation
import UserNotifications
import SwiftData

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    // Rotating notification messages with water emojis
    private let notificationMessages: [(message: String, emoji: String)] = [
        ("💧 Time to hydrate!", "💧"),
        ("💦 Don't forget your H2O!", "💦"),
        ("🚰 Keep that water flowing!", "🚰"),
        ("🧊 Stay cool and hydrated!", "🧊"),
        ("🌊 Ride the hydration wave!", "🌊")
    ]
    
    private var currentMessageIndex: Int {
        get {
            UserDefaults.standard.integer(forKey: "currentMessageIndex")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "currentMessageIndex")
        }
    }
    
    func scheduleNotifications(startTime: Date, stopTime: Date, frequency: ReminderFrequency, context: ModelContext) {
        // Cancel existing notifications first
        cancelAllNotifications()

        for slot in Self.reminderSlots(startTime: startTime, stopTime: stopTime, frequency: frequency) {
            scheduleNotification(hour: slot.hour, minute: slot.minute, context: context)
        }
        UserDefaults.standard.set(Self.scheduleVersion, forKey: Self.scheduleVersionKey)
    }

    // The times of day reminders fire: from the start time through the stop time, every `frequency` minutes.
    // A stop time earlier than the start time runs past midnight into the next morning.
    static func reminderSlots(startTime: Date, stopTime: Date, frequency: ReminderFrequency) -> [(hour: Int, minute: Int)] {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let stopComponents = calendar.dateComponents([.hour, .minute], from: stopTime)

        guard let startHour = startComponents.hour,
              let startMinute = startComponents.minute,
              let stopHour = stopComponents.hour,
              let stopMinute = stopComponents.minute else {
            return []
        }

        // Count in minutes from the start of the day, past 24:00 for a window that crosses midnight
        let startTotal = startHour * 60 + startMinute
        var stopTotal = stopHour * 60 + stopMinute
        if stopTotal < startTotal {
            stopTotal += 24 * 60
        }
        return stride(from: startTotal, through: stopTotal, by: frequency.minutes).map { total in
            (hour: (total / 60) % 24, minute: total % 60)
        }
    }

    // Bumped when schedules made by older builds need rebuilding; 2 clears the old midnight-wrap slots
    private static let scheduleVersion = 2
    private static let scheduleVersionKey = "reminderScheduleVersion"

    // Brings the scheduled reminders in line with the saved settings: schedules them when they're on but none
    // are pending (a reinstall, a new phone, or settings synced from iCloud) and cancels them when they're off.
    // An existing schedule is otherwise left alone, because its triggers follow the local clock across time zones
    // while the saved start and stop times don't; the one exception is a single rebuild after an update.
    func rescheduleFromSavedSettings(context: ModelContext) {
        guard let settings = try? context.fetch(FetchDescriptor<ReminderSettings>()).first else { return }
        let isEnabled = settings.isEnabled
        let startTime = settings.startTime
        let stopTime = settings.stopTime
        let frequency = settings.frequency ?? .oneHour
        let needsRebuild = UserDefaults.standard.integer(forKey: Self.scheduleVersionKey) < Self.scheduleVersion

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let hasReminders = pending.contains { $0.identifier.hasPrefix("reminder_") }
            guard isEnabled, let startTime, let stopTime else {
                if hasReminders {
                    DispatchQueue.main.async { self.cancelAllNotifications() }
                }
                return
            }
            guard needsRebuild || !hasReminders else { return }
            center.getNotificationSettings { notificationSettings in
                guard notificationSettings.authorizationStatus == .authorized else { return }
                DispatchQueue.main.async {
                    self.scheduleNotifications(startTime: startTime, stopTime: stopTime, frequency: frequency, context: context)
                }
            }
        }
    }
    
    private func scheduleNotification(hour: Int, minute: Int, context: ModelContext) {
        let content = UNMutableNotificationContent()
        
        // Get next message
        let messageInfo = notificationMessages[currentMessageIndex]
        currentMessageIndex = (currentMessageIndex + 1) % notificationMessages.count
        
        content.title = "Just Drink"
        content.body = messageInfo.message
        content.sound = .default
        
        // Create date components for the trigger
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        // Create trigger that repeats daily
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create request with unique identifier
        let identifier = "reminder_\(hour)_\(minute)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}


