//
// DailyGoal.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
// 
//

import Foundation
import SwiftData

@Model
final class DailyGoal {
    var id: UUID
    var amount: Double
    var unit: VolumeUnit
    
    init(amount: Double, unit: VolumeUnit) {
        self.id = UUID()
        self.amount = amount
        self.unit = unit
    }
    
    // Convert goal to milliliters for calculations
    var amountInML: Double {
        switch unit {
        case .oz:
            return amount * 29.5735
        case .ml:
            return amount
        case .liter:
            return amount * 1000
        }
    }
}


