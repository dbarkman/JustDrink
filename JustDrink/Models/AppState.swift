//
// AppState.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
// 
//

import Foundation
import SwiftData

@Model
final class AppState {
    var id: UUID = UUID()
    var lastDrinkTimestamp: Date? = nil
    var selectedContainerId: UUID? = nil
    
    init() {
        self.id = UUID()
        self.lastDrinkTimestamp = nil
        self.selectedContainerId = nil
    }
}


