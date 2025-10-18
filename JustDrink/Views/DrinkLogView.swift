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
            .navigationTitle("Drink Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
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
    
    private var matchingContainer: Container? {
        containers.first { $0.name == record.containerName }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Container thumbnail
            if let container = matchingContainer {
                if let imageData = container.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "waterbottle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 40)
                        .foregroundColor(DataManager.shared.getContainerColor(index: container.colorIndex))
                }
            } else {
                // Fallback if container not found
                Image(systemName: "waterbottle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 40)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading) {
                Text(record.containerName)
                    .font(.headline)
                Text("\(record.capacity.formatted()) \(record.unit?.displayName ?? VolumeUnit.ml.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct DaySectionHeader: View {
    let date: Date
    let totalML: Double
    let goalML: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatDate(date))
                    .font(.headline)
                Spacer()
                Text(DataManager.shared.formatVolumeForDisplay(totalML))
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            if let goalML = goalML {
                GoalComparisonView(totalML: totalML, goalML: goalML, date: date)
            }
        }
        .padding(.vertical, 4)
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
        HStack(spacing: 4) {
            if metGoal {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Goal achieved! 🎉")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                if isToday {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("\(percentageOfGoal)% of goal - Keep going! 💪")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("\(percentageOfGoal)% of goal - Every drop counts! 💧")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
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
            Section("Record Details") {
                TextField("Container Name", text: $containerName)
                
                HStack {
                    TextField("Capacity", text: $capacity)
                        .keyboardType(.decimalPad)
                    
                    Picker("", selection: $selectedUnit) {
                        ForEach(VolumeUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                
                DatePicker("Date & Time", selection: $selectedDate)
            }
        }
        .navigationTitle("Edit Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveRecord()
                }
                .disabled(!isValid)
            }
        }
        .onAppear {
            containerName = record.containerName
            capacity = formatCapacity(record.capacity)
            selectedUnit = record.unit ?? .ml
            selectedDate = record.timestamp
        }
    }
    
    private func formatCapacity(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(value)
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


