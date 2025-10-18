//
// RemindersConfigView.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
// 
//

import SwiftUI
import SwiftData
import UserNotifications

struct RemindersConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [ReminderSettings]
    @State private var isEnabled: Bool = false
    @State private var startTime: Date = Date()
    @State private var stopTime: Date = Date()
    @State private var frequency: ReminderFrequency = .oneHour
    @State private var showPermissionAlert = false
    
    private var reminderSettings: ReminderSettings? {
        settings.first
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Reminders", isOn: $isEnabled)
                        .onChange(of: isEnabled) { oldValue, newValue in
                            handleToggleChange(newValue)
                        }
                }
                
                Section {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        .disabled(!isEnabled)
                        .foregroundColor(isEnabled ? .primary : .secondary)
                    
                    DatePicker("Stop Time", selection: $stopTime, displayedComponents: .hourAndMinute)
                        .disabled(!isEnabled)
                        .foregroundColor(isEnabled ? .primary : .secondary)
                    
                    Picker("Frequency", selection: $frequency) {
                        ForEach(ReminderFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .disabled(!isEnabled)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                }
            }
            .alert("Notifications Disabled", isPresented: $showPermissionAlert) {
                Button("Cancel", role: .cancel) {
                    isEnabled = false
                }
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    isEnabled = false
                }
            } message: {
                Text("Please enable notifications for JustDrink in Settings to receive drink reminders.")
            }
            .onAppear {
                if let settings = reminderSettings {
                    isEnabled = settings.isEnabled
                    startTime = settings.startTime ?? startTime
                    stopTime = settings.stopTime ?? stopTime
                    frequency = settings.frequency ?? .oneHour
                }
            }
        }
    }
    
    private func handleToggleChange(_ newValue: Bool) {
        if newValue {
            // Check notification permissions
            checkNotificationPermissions { authorized in
                if !authorized {
                    // Request permission
                    requestNotificationPermission { granted in
                        if !granted {
                            showPermissionAlert = true
                        }
                    }
                }
            }
        } else {
            // Cancel all notifications when disabled
            NotificationManager.shared.cancelAllNotifications()
        }
    }
    
    private func checkNotificationPermissions(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    private func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    private func saveSettings() {
        if let settings = reminderSettings {
            settings.isEnabled = isEnabled
            settings.startTime = startTime
            settings.stopTime = stopTime
            settings.frequency = frequency
        } else {
            let newSettings = ReminderSettings(isEnabled: isEnabled, startTime: startTime, stopTime: stopTime, frequency: frequency)
            modelContext.insert(newSettings)
        }
        
        try? modelContext.save()
        
        // Schedule or cancel notifications based on settings
        if isEnabled {
            NotificationManager.shared.scheduleNotifications(
                startTime: startTime,
                stopTime: stopTime,
                frequency: frequency,
                context: modelContext
            )
        } else {
            NotificationManager.shared.cancelAllNotifications()
        }
        
        dismiss()
    }
}

#Preview {
    RemindersConfigView()
        .modelContainer(for: ReminderSettings.self, inMemory: true)
}


