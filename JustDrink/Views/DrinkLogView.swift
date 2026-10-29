//
// DrinkLogView.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
//
//

import SwiftUI
import SwiftData

struct DrinkLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DrinkRecord.timestamp, order: .reverse) private var drinkRecords: [DrinkRecord]
    @Query private var goals: [DailyGoal]
    @State private var groupedRecordsCache: [(date: Date, records: [DrinkRecord], totalML: Double)] = []

    private var dailyGoal: DailyGoal? {
        goals.first
    }

    private func recomputeGroupedRecords() {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: drinkRecords) { record in
            calendar.startOfDay(for: record.timestamp)
        }
        groupedRecordsCache = grouped.map { date, records in
            let total = records.reduce(0) { $0 + $1.capacityInML }
            return (date: date, records: records, totalML: total)
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedRecordsCache, id: \.date) { group in
                    Section {
                        ForEach(group.records) { record in
                            NavigationLink {
                                DrinkRecordEditView(record: record)
                            } label: {
                                DrinkRecordRow(record: record)
                            }
                            .listRowBackground(Theme.card)
                        }
                        .onDelete { offsets in
                            deleteRecords(from: group.records, at: offsets)
                        }
                    } header: {
                        DaySectionHeader(
                            date: group.date,
                            totalML: group.totalML,
                            goalML: DataManager.shared.effectiveGoalML(for: group.date, context: modelContext)
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .overlay {
                if drinkRecords.isEmpty {
                    ContentUnavailableView(
                        "No Drinks Yet",
                        systemImage: "drop",
                        description: Text("Drinks you log show up here, grouped by day.")
                    )
                    .transition(.opacity)
                }
            }
            .animation(.default, value: drinkRecords.isEmpty)
            .navigationTitle("Drink Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                recomputeGroupedRecords()
            }
            .onChange(of: drinkRecords) { _, _ in
                recomputeGroupedRecords()
            }
        }
    }

    private func deleteRecords(from records: [DrinkRecord], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to save after deleting drink records: \(error)")
        }
    }
}

struct DrinkRecordRow: View {
    let record: DrinkRecord
    @Query private var containers: [Container]
    @ScaledMetric(relativeTo: .headline) private var iconSide: CGFloat = 40

    private var matchingContainer: Container? {
        containers.first { $0.name == record.containerName }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Container thumbnail, gray if the container is gone
            if let container = matchingContainer {
                ContainerIcon(container: container, side: iconSide)
            } else {
                ContainerIcon(imageData: nil, color: .gray, side: iconSide)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(record.containerName)
                    .font(.rounded(.headline, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("\(record.capacity.formatted()) \(record.unit?.displayName ?? VolumeUnit.ml.displayName)")
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(Theme.ink2)
            }

            Spacer()

            Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.rounded(.subheadline, weight: .bold))
                .foregroundStyle(Theme.ink2)
        }
        .padding(.vertical, 2)
    }
}

struct DaySectionHeader: View {
    let date: Date
    let totalML: Double
    let goalML: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(formatDate(date))
                    .font(.rounded(.title3, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(DataManager.shared.formatVolumeForDisplay(totalML))
                    .font(.rounded(.title3, weight: .heavy))
                    .foregroundStyle(Theme.waterInk)
            }

            if let goalML = goalML {
                ProgressCapsule(progress: totalML / goalML)
                GoalComparisonView(totalML: totalML, goalML: goalML, date: date)
            }
        }
        .textCase(nil)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

struct GoalComparisonView: View {
    let totalML: Double
    let goalML: Double
    let date: Date

    var percentageOfGoal: Int {
        Int((totalML / goalML) * 100)
    }

    var metGoal: Bool {
        totalML >= goalML
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        Group {
            if metGoal {
                Label("Goal achieved!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.good)
            } else if isToday {
                Label("\(percentageOfGoal)% of goal. Keep going!", systemImage: "drop.fill")
                    .foregroundStyle(Theme.warm)
            } else {
                Label("\(percentageOfGoal)% of goal. Every drop counts!", systemImage: "drop")
                    .foregroundStyle(Theme.waterInk)
            }
        }
        .font(.rounded(.footnote, weight: .heavy))
        .labelStyle(TightLabelStyle())
    }
}

// Icon and title close together, for small status lines
private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            configuration.title
        }
    }
}

struct DrinkRecordEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let record: DrinkRecord

    @State private var containerName: String = ""
    @State private var capacity: String = ""
    @State private var selectedUnit: VolumeUnit = .ml
    @State private var selectedDate: Date = Date()

    var body: some View {
        Form {
            Section {
                TextField("Container Name", text: $containerName)
            } header: {
                Eyebrow("Container")
            }
            .listRowBackground(Theme.card)

            Section {
                HStack {
                    TextField("Capacity", text: $capacity)
                        .keyboardType(.decimalPad)

                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(VolumeUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            } header: {
                Eyebrow("Amount")
            }
            .listRowBackground(Theme.card)

            Section {
                DatePicker("Date & Time", selection: $selectedDate)
            } header: {
                Eyebrow("When")
            }
            .listRowBackground(Theme.card)
        }
        .font(.rounded(.body, weight: .semibold))
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .navigationTitle("Edit Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveRecord()
                }
                .disabled(!isValid)
            }
        }
        .onAppear {
            containerName = record.containerName
            capacity = editableNumber(record.capacity)
            selectedUnit = record.unit ?? .ml
            selectedDate = record.timestamp
        }
    }

    private var isValid: Bool {
        !containerName.isEmpty && Double(capacity) != nil && (Double(capacity) ?? 0) > 0
    }

    private func saveRecord() {
        guard let capacityValue = Double(capacity) else { return }

        record.containerName = containerName
        record.capacity = capacityValue
        record.unit = selectedUnit
        record.timestamp = selectedDate

        do {
            try modelContext.save()
        } catch {
            print("Failed to save edited drink record: \(error)")
        }
        dismiss()
    }
}

#Preview {
    DrinkLogView()
        .modelContainer(for: [DrinkRecord.self, DailyGoal.self], inMemory: true)
}

