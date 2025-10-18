//
// DailyGoalHistory.swift
// JustDrink
//
// Created by Assistant on 10/18/25.
//

import Foundation
import SwiftData

@Model
final class DailyGoalHistory {
    // CloudKit-friendly defaults
    var id: UUID = UUID()
    var timestamp: Date = Date() // when this goal became effective
    var goalML: Double = 0 // 0 means "no goal"
    
    init(timestamp: Date, goalML: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.goalML = goalML
    }
}


