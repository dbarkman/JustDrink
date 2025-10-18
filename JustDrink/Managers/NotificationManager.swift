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
        ("Time to hydrate!", "💧"),
        ("Don't forget your H2O!", "💦"),
        ("Keep that water flowing!", "🚰"),
        ("Stay cool and hydrated!", "🧊"),
        ("Ride the hydration wave!", "🌊")
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
        
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let stopComponents = calendar.dateComponents([.hour, .minute], from: stopTime)
        
        guard let startHour = startComponents.hour,
              let startMinute = startComponents.minute,
              let stopHour = stopComponents.hour,
              let stopMinute = stopComponents.minute else {
            return
        }
        
        // Helper to iterate minutes within a range with wrap at 24h
        func iterate(from start: (h: Int, m: Int), to stop: (h: Int, m: Int), action: (_ hour: Int, _ minute: Int) -> Void) {
            var hour = start.h
            var minute = start.m
            var count = 0
            while true {
                action(hour, minute)
                count += 1
                minute += frequency.minutes
                if minute >= 60 {
                    hour += minute / 60
                    minute = minute % 60
                }
                hour = hour % 24
                let currentTotal = hour * 60 + minute
                let stopTotal = stop.h * 60 + stop.m
                if start.h * 60 + start.m <= stopTotal {
                    // same-day window
                    if currentTotal > stopTotal { break }
                } else {
                    // cross-midnight window
                    if currentTotal > stopTotal && (hour * 60 + minute) >= (start.h * 60 + start.m) { break }
                }
                if count > 200 { break }
            }
        }
        
        let startTotal = startHour * 60 + startMinute
        let stopTotal = stopHour * 60 + stopMinute
        if startTotal <= stopTotal {
            // Same-day range
            iterate(from: (startHour, startMinute), to: (stopHour, stopMinute)) { h, m in
                scheduleNotification(hour: h, minute: m, context: context)
            }
        } else {
            // Cross-midnight: start..23:59 then 00:00..stop
            iterate(from: (startHour, startMinute), to: (23, 59)) { h, m in
                scheduleNotification(hour: h, minute: m, context: context)
            }
            iterate(from: (0, 0), to: (stopHour, stopMinute)) { h, m in
                scheduleNotification(hour: h, minute: m, context: context)
            }
        }
    }
    
    private func scheduleNotification(hour: Int, minute: Int, context: ModelContext) {
        let content = UNMutableNotificationContent()
        
        // Get today's total
        let todaysTotalML = DataManager.shared.getTodaysTotalInML(context: context)
        let formattedTotal = DataManager.shared.formatVolumeForDisplay(todaysTotalML)
        
        // Get next message
        let messageInfo = notificationMessages[currentMessageIndex]
        currentMessageIndex = (currentMessageIndex + 1) % notificationMessages.count
        
        content.title = messageInfo.message
        content.body = "\(messageInfo.emoji) \(formattedTotal) recorded today"
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


