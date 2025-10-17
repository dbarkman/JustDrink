//
// ReminderSettings.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
// 
//

import Foundation
import SwiftData

enum ReminderFrequency: String, Codable, CaseIterable {
    case thirtyMinutes = "30 min"
    case oneHour = "1 hour"
    case twoHours = "2 hours"
    
    var minutes: Int {
        switch self {
        case .thirtyMinutes:
            return 30
        case .oneHour:
            return 60
        case .twoHours:
            return 120
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}

@Model
final class ReminderSettings {
    var id: UUID
    var isEnabled: Bool
    var startTime: Date
    var stopTime: Date
    var frequency: ReminderFrequency
    
    init(isEnabled: Bool = false, startTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date(), stopTime: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date(), frequency: ReminderFrequency = .oneHour) {
        self.id = UUID()
        self.isEnabled = isEnabled
        self.startTime = startTime
        self.stopTime = stopTime
        self.frequency = frequency
    }
}


