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
        
        // Use CloudKit-backed store (automatic picks the default container from entitlements)
        let configuration = ModelConfiguration(cloudKitDatabase: .automatic)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        Theme.styleNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .tint(Theme.tint)
                .onAppear {
                    // Kick off default data init on background context to reduce first-run UI jank
                    DataManager.shared.initializeDefaultContainerAsync(container: sharedModelContainer)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
