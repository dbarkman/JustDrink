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
    @State private var groupedRecords: [(date: Date, records: [DrinkRecord], totalML: Double)] = []
    @State private var dailyGoal: DailyGoal?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedRecords, id: \.date) { group in
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
                            goalML: dailyGoal?.amountInML
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
                loadData()
            }
        }
    }
    
    private func loadData() {
        groupedRecords = DataManager.shared.getDrinkRecordsGroupedByDay(context: modelContext)
        dailyGoal = DataManager.shared.getDailyGoal(context: modelContext)
    }
    
    private func deleteRecords(from records: [DrinkRecord], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
        loadData()
    }
}

struct DrinkRecordRow: View {
    let record: DrinkRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(record.containerName)
                    .font(.headline)
                Text("\(record.capacity.formatted()) \(record.unit.displayName)")
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
                GoalComparisonView(totalML: totalML, goalML: goalML)
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
    
    var percentageOfGoal: Int {
        Int((totalML / goalML) * 100)
    }
    
    var metGoal: Bool {
        totalML >= goalML
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
                Image(systemName: "heart.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("\(percentageOfGoal)% of goal - Keep going! 💪")
                    .font(.caption)
                    .foregroundColor(.orange)
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
                    
                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(VolumeUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
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
            capacity = String(record.capacity)
            selectedUnit = record.unit
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
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    DrinkLogView()
        .modelContainer(for: [DrinkRecord.self, DailyGoal.self], inMemory: true)
}


