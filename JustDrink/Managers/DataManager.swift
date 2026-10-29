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
        do {
            let states = try context.fetch(descriptor)
            if let state = states.first {
                return state
            } else {
                let newState = AppState()
                context.insert(newState)
                try context.save()
                return newState
            }
        } catch {
            print("Failed fetching/creating AppState: \(error)")
            let fallback = AppState()
            context.insert(fallback)
            do { try context.save() } catch { print("Failed saving fallback AppState: \(error)") }
            return fallback
        }
    }
    
    // Get or create reminder settings
    func getReminderSettings(context: ModelContext) -> ReminderSettings {
        let descriptor = FetchDescriptor<ReminderSettings>()
        do {
            let settings = try context.fetch(descriptor)
            if let setting = settings.first {
                return setting
            } else {
                let newSettings = ReminderSettings()
                context.insert(newSettings)
                try context.save()
                return newSettings
            }
        } catch {
            print("Failed fetching/creating ReminderSettings: \(error)")
            let fallback = ReminderSettings()
            context.insert(fallback)
            do { try context.save() } catch { print("Failed saving fallback ReminderSettings: \(error)") }
            return fallback
        }
    }
    
    // Get daily goal (optional)
    func getDailyGoal(context: ModelContext) -> DailyGoal? {
        let descriptor = FetchDescriptor<DailyGoal>()
        do {
            let goals = try context.fetch(descriptor)
            return goals.first
        } catch {
            print("Failed fetching DailyGoal: \(error)")
            return nil
        }
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
        // Snapshot current goal into history (in milliliters)
        let goalInML: Double = {
            switch unit {
            case .oz: return amount * 29.5735
            case .ml: return amount
            case .liter: return amount * 1000
            }
        }()
        context.insert(DailyGoalHistory(timestamp: Date(), goalML: goalInML))
        do {
            try context.save()
        } catch {
            print("Failed saving DailyGoal: \(error)")
        }
    }
    
    // Delete daily goal
    func deleteDailyGoal(context: ModelContext) {
        if let goal = getDailyGoal(context: context) {
            context.delete(goal)
            // Snapshot removal as 0 ML effective now
            context.insert(DailyGoalHistory(timestamp: Date(), goalML: 0))
            do {
                try context.save()
            } catch {
                print("Failed deleting DailyGoal: \(error)")
            }
        }
    }

    // Goal history lookup: return the goal that applied to a given calendar day
    // Today follows latest changes; previous days use the last snapshot at or before that day's end.
    // If no snapshot exists yet (e.g., feature added later), fall back to earliest snapshot or current goal
    func effectiveGoalML(for date: Date, context: ModelContext) -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<DailyGoalHistory>(
            predicate: #Predicate { entry in
                entry.timestamp < startOfNextDay
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        if let entries = try? context.fetch(descriptor), let last = entries.last {
            return last.goalML > 0 ? last.goalML : nil
        }
        // No snapshot before end of this day. Try earliest snapshot overall.
        let anyHistoryDesc = FetchDescriptor<DailyGoalHistory>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        if let all = try? context.fetch(anyHistoryDesc), let first = all.first, first.goalML > 0 {
            return first.goalML
        }
        // Fallback: use current goal if available (keeps messages visible for legacy days)
        if let current = getDailyGoal(context: context) {
            return current.amountInML
        }
        return nil
    }
    
    // Initialize default container on first launch
    func initializeDefaultContainer(context: ModelContext) {
        let descriptor = FetchDescriptor<Container>()
        do {
            let containers = try context.fetch(descriptor)
            if containers.isEmpty {
                let defaultImage = UIImage(named: "defaultBottle")
                let imageData = defaultImage?.jpegData(compressionQuality: 0.8)
                let defaultContainer = Container(
                    name: "Costco Water",
                    capacity: 500,
                    unit: .ml,
                    imageData: imageData,
                    colorIndex: 0,
                    isDefault: true
                )
                context.insert(defaultContainer)
                let appState = getAppState(context: context)
                appState.selectedContainerId = defaultContainer.id
                do { try context.save() } catch { print("Failed saving default container: \(error)") }
            }
            // Always attempt to dedupe; safe and idempotent
            dedupeDefaultContainers(context: context)
        } catch {
            print("Failed initializing default container: \(error)")
        }
    }

    // Remove duplicate default containers created before CloudKit sync completes
    func dedupeDefaultContainers(context: ModelContext) {
        let descriptor = FetchDescriptor<Container>()
        guard let allContainers = try? context.fetch(descriptor) else { return }
        // Group by identifying attributes of the default using a stable string key
        let grouped = Dictionary(grouping: allContainers) { container in
            let unitRaw = (container.unit ?? .ml).rawValue
            return "\(container.name)|\(container.capacity)|\(unitRaw)|\(container.isDefault ? "1" : "0")"
        }
        var didChange = false
        for (_, group) in grouped {
            guard group.count > 1 else { continue }
            // Keep the earliest by createdAt, fallback by UUID string
            let sorted = group.sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.createdAt < rhs.createdAt
            }
            guard let keep = sorted.first else { continue }
            let extras = sorted.dropFirst()
            // If selected container points to a duplicate, re-point to the kept one
            let appState = getAppState(context: context)
            if let selectedId = appState.selectedContainerId, extras.contains(where: { $0.id == selectedId }) {
                appState.selectedContainerId = keep.id
                didChange = true
            }
            // Delete extras
            for extra in extras {
                context.delete(extra)
                didChange = true
            }
        }
        if didChange {
            do { try context.save() } catch { print("Failed saving after dedupe: \(error)") }
        }
    }

    // Non-blocking initializer that runs on a background context to avoid UI stalls on first launch
    func initializeDefaultContainerAsync(container: ModelContainer) {
        Task.detached(priority: .background) { [weak self] in
            let bgContext = ModelContext(container)
            bgContext.autosaveEnabled = false
            self?.initializeDefaultContainer(context: bgContext)
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
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed fetching today's drinks: \(error)")
            return []
        }
    }
    
    // Calculate today's total in milliliters
    func getTodaysTotalInML(context: ModelContext) -> Double {
        let todaysDrinks = getTodaysDrinks(context: context)
        return todaysDrinks.reduce(0) { $0 + $1.capacityInML }
    }
    
    // Format volume for display based on locale
    func formatVolumeForDisplay(_ volumeInML: Double) -> String {
        let parts = volumeParts(volumeInML)
        return "\(parts.value) \(parts.unit)"
    }

    // The same display volume split into number and unit, for the big readout on the main screen
    func volumeParts(_ volumeInML: Double) -> (value: String, unit: String) {
        let locale = Locale.current
        let usesMetric = locale.measurementSystem == .metric

        if usesMetric {
            // Display in liters with decimals
            let liters = volumeInML / 1000.0
            return (String(format: "%.3f", liters), "L")
        } else {
            // Display in ounces
            let ounces = volumeInML / 29.5735
            return (String(format: "%.0f", ounces), "oz")
        }
    }
    
    // Get all drink records grouped by day
    func getDrinkRecordsGroupedByDay(context: ModelContext) -> [(date: Date, records: [DrinkRecord], totalML: Double)] {
        let descriptor = FetchDescriptor<DrinkRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let allRecords = try context.fetch(descriptor)
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: allRecords) { record in
                calendar.startOfDay(for: record.timestamp)
            }
            
            return grouped.map { date, records in
                let total = records.reduce(0) { $0 + $1.capacityInML }
                return (date: date, records: records, totalML: total)
            }.sorted { $0.date > $1.date }
        } catch {
            print("Failed fetching grouped drink records: \(error)")
            return []
        }
    }
    
    // Get rainbow colors for default containers
    func getContainerColor(index: Int) -> Color {
        let colors = Theme.containerColors
        return colors[index % colors.count]
    }
}

