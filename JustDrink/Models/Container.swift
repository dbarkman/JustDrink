//
// Container.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
// 
//

import Foundation
import SwiftData
import SwiftUI

enum VolumeUnit: String, Codable, CaseIterable {
    case oz = "oz"
    case ml = "ml"
    case liter = "L"
    
    var displayName: String {
        return self.rawValue
    }
}

@Model
final class Container {
    var id: UUID
    var name: String
    var capacity: Double
    var unit: VolumeUnit
    var imageData: Data?
    var colorIndex: Int // For default icon coloring
    var createdAt: Date
    var isDefault: Bool
    
    init(name: String, capacity: Double, unit: VolumeUnit, imageData: Data? = nil, colorIndex: Int = 0, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.capacity = capacity
        self.unit = unit
        self.imageData = imageData
        self.colorIndex = colorIndex
        self.createdAt = Date()
        self.isDefault = isDefault
    }
    
    // Convert capacity to milliliters for internal calculations
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


