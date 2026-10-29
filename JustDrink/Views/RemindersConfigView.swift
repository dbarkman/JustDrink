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
    @ScaledMetric(relativeTo: .headline) private var iconSide: CGFloat = 44

    private var reminderSettings: ReminderSettings? {
        settings.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $isEnabled) {
                        HStack(spacing: 14) {
                            Image(systemName: isEnabled ? "bell.fill" : "bell.slash")
                                .font(.rounded(.title3, weight: .semibold))
                                .foregroundStyle(Theme.waterInk)
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: iconSide, height: iconSide)
                                .background(RoundedRectangle(cornerRadius: iconSide * 0.3, style: .continuous).fill(Theme.water.opacity(0.14)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remind Me to Drink")
                                    .font(.rounded(.headline, weight: .heavy))
                                    .foregroundStyle(Theme.ink)
                                Text("A gentle nudge through the day")
                                    .font(.rounded(.subheadline, weight: .bold))
                                    .foregroundStyle(Theme.ink2)
                            }
                        }
                    }
                    .onChange(of: isEnabled) { oldValue, newValue in
                        handleToggleChange(newValue)
                    }
                }
                .listRowBackground(Theme.card)

                Section {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                        .disabled(!isEnabled)
                        .foregroundStyle(isEnabled ? Theme.ink : Theme.ink2)

                    DatePicker("Stop", selection: $stopTime, displayedComponents: .hourAndMinute)
                        .disabled(!isEnabled)
                        .foregroundStyle(isEnabled ? Theme.ink : Theme.ink2)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("How Often")
                            .foregroundStyle(isEnabled ? Theme.ink : Theme.ink2)
                        Picker("Frequency", selection: $frequency) {
                            ForEach(ReminderFrequency.allCases, id: \.self) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                    .disabled(!isEnabled)
                } footer: {
                    Label(summary, systemImage: isEnabled ? "clock" : "moon.zzz")
                        .font(.rounded(.subheadline, weight: .bold))
                        .foregroundStyle(Theme.ink2)
                        .contentTransition(.interpolate)
                        .padding(.top, 6)
                }
                .listRowBackground(Theme.card)
            }
            .font(.rounded(.body, weight: .bold))
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .animation(.default, value: isEnabled)
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
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

    // One line describing the schedule as set on screen
    private var summary: String {
        guard isEnabled else { return "Reminders are off." }
        let every: String
        switch frequency {
        case .thirtyMinutes: every = "every 30 minutes"
        case .oneHour: every = "every hour"
        case .twoHours: every = "every 2 hours"
        }
        let start = startTime.formatted(date: .omitted, time: .shortened)
        let stop = stopTime.formatted(date: .omitted, time: .shortened)
        return "You'll get a reminder \(every) from \(start) to \(stop)."
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

