//
// JustDrinkApp.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
// 
//

import SwiftUI
import SwiftData

@main
struct JustDrinkApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Container.self,
            DrinkRecord.self,
            DailyGoal.self,
            ReminderSettings.self,
            AppState.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(sharedModelContainer)
    }
}
