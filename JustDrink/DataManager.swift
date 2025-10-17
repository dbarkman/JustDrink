//
// DataManager.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
// 
//

import Foundation
import SwiftData
import SwiftUI

class DataManager {
    static let shared = DataManager()
    
    private init() {}
    
    // Get or create app state
    func getAppState(context: ModelContext) -> AppState {
        let descriptor = FetchDescriptor<AppState>()
        let states = try? context.fetch(descriptor)
        
        if let state = states?.first {
            return state
        } else {
            let newState = AppState()
            context.insert(newState)
            try? context.save()
            return newState
        }
    }
    
    // Get or create reminder settings
    func getReminderSettings(context: ModelContext) -> ReminderSettings {
        let descriptor = FetchDescriptor<ReminderSettings>()
        let settings = try? context.fetch(descriptor)
        
        if let setting = settings?.first {
            return setting
        } else {
            let newSettings = ReminderSettings()
            context.insert(newSettings)
            try? context.save()
            return newSettings
        }
    }
    
    // Get daily goal (optional)
    func getDailyGoal(context: ModelContext) -> DailyGoal? {
        let descriptor = FetchDescriptor<DailyGoal>()
        let goals = try? context.fetch(descriptor)
        return goals?.first
    }
    
    // Create or update daily goal
    func setDailyGoal(context: ModelContext, amount: Double, unit: VolumeUnit) {
        if let existingGoal = getDailyGoal(context: context) {
            existingGoal.amount = amount
            existingGoal.unit = unit
        } else {
            let newGoal = DailyGoal(amount: amount, unit: unit)
            context.insert(newGoal)
        }
        try? context.save()
    }
    
    // Delete daily goal
    func deleteDailyGoal(context: ModelContext) {
        if let goal = getDailyGoal(context: context) {
            context.delete(goal)
            try? context.save()
        }
    }
    
    // Initialize default container on first launch
    func initializeDefaultContainer(context: ModelContext) {
        let descriptor = FetchDescriptor<Container>()
        let containers = try? context.fetch(descriptor)
        
        // Only create default if no containers exist
        if containers?.isEmpty ?? true {
            // Try to load default image from assets, but continue if not found
            let defaultImage = UIImage(named: "defaultBottle")
            let imageData = defaultImage?.jpegData(compressionQuality: 0.8)
            
            let defaultContainer = Container(
                name: "Costco Water Bottle",
                capacity: 500,
                unit: .ml,
                imageData: imageData,
                colorIndex: 0,
                isDefault: true
            )
            
            context.insert(defaultContainer)
            
            // Set as selected container
            let appState = getAppState(context: context)
            appState.selectedContainerId = defaultContainer.id
            
            try? context.save()
        }
    }
    
    // Get today's drink records
    func getTodaysDrinks(context: ModelContext) -> [DrinkRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<DrinkRecord>(
            predicate: #Predicate { record in
                record.timestamp >= startOfDay && record.timestamp < endOfDay
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    // Calculate today's total in milliliters
    func getTodaysTotalInML(context: ModelContext) -> Double {
        let todaysDrinks = getTodaysDrinks(context: context)
        return todaysDrinks.reduce(0) { $0 + $1.capacityInML }
    }
    
    // Format volume for display based on locale
    func formatVolumeForDisplay(_ volumeInML: Double) -> String {
        let locale = Locale.current
        let usesMetric = locale.measurementSystem == .metric
        
        if usesMetric {
            // Display in liters with decimals
            let liters = volumeInML / 1000.0
            return String(format: "%.3f L", liters)
        } else {
            // Display in ounces
            let ounces = volumeInML / 29.5735
            return String(format: "%.0f oz", ounces)
        }
    }
    
    // Get all drink records grouped by day
    func getDrinkRecordsGroupedByDay(context: ModelContext) -> [(date: Date, records: [DrinkRecord], totalML: Double)] {
        let descriptor = FetchDescriptor<DrinkRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        guard let allRecords = try? context.fetch(descriptor) else {
            return []
        }
        
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: allRecords) { record in
            calendar.startOfDay(for: record.timestamp)
        }
        
        return grouped.map { date, records in
            let total = records.reduce(0) { $0 + $1.capacityInML }
            return (date: date, records: records, totalML: total)
        }.sorted { $0.date > $1.date }
    }
    
    // Get rainbow colors for default containers
    func getContainerColor(index: Int) -> Color {
        let colors: [Color] = [.blue, .red, .green, .orange, .purple, .pink, .yellow, .cyan]
        return colors[index % colors.count]
    }
}

