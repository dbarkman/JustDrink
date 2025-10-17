//
// DrinkRecord.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
// 
//

import Foundation
import SwiftData

@Model
final class DrinkRecord {
    var id: UUID
    var timestamp: Date
    var containerName: String
    var capacity: Double
    var unit: VolumeUnit
    
    init(timestamp: Date, containerName: String, capacity: Double, unit: VolumeUnit) {
        self.id = UUID()
        self.timestamp = timestamp
        self.containerName = containerName
        self.capacity = capacity
        self.unit = unit
    }
    
    // Convert capacity to milliliters for calculations
    var capacityInML: Double {
        switch unit {
        case .oz:
            return capacity * 29.5735
        case .ml:
            return capacity
        case .liter:
            return capacity * 1000
        }
    }
}


