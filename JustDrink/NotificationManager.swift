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
        ("Don't forget to drink water!", "💦"),
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
        
        // Create notifications for each frequency interval
        var currentHour = startHour
        var currentMinute = startMinute
        var notificationCount = 0
        
        while true {
            // Check if we've passed the stop time
            let currentTotalMinutes = currentHour * 60 + currentMinute
            let stopTotalMinutes = stopHour * 60 + stopMinute
            
            if currentTotalMinutes > stopTotalMinutes {
                break
            }
            
            // Schedule notification
            scheduleNotification(hour: currentHour, minute: currentMinute, context: context)
            notificationCount += 1
            
            // Move to next interval
            currentMinute += frequency.minutes
            if currentMinute >= 60 {
                currentHour += currentMinute / 60
                currentMinute = currentMinute % 60
            }
            
            // Safety check to prevent infinite loop
            if notificationCount > 100 {
                break
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


