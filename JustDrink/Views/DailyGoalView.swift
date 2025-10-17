//
// DailyGoalView.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
// 
//

import SwiftUI
import SwiftData

struct DailyGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var dailyGoal: DailyGoal?
    @State private var amount: String = ""
    @State private var selectedUnit: VolumeUnit = .oz
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Daily Goal:")
                            .font(.headline)
                        
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(VolumeUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                if dailyGoal != nil {
                    Section {
                        Button("Remove Goal", role: .destructive) {
                            removeGoal()
                        }
                    }
                }
            }
            .navigationTitle("Daily Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadGoal()
            }
        }
    }
    
    private var isValid: Bool {
        guard let value = Double(amount) else { return false }
        return value > 0
    }
    
    private func loadGoal() {
        dailyGoal = DataManager.shared.getDailyGoal(context: modelContext)
        if let goal = dailyGoal {
            amount = String(goal.amount)
            selectedUnit = goal.unit
        } else {
            // Default to user's locale
            selectedUnit = Locale.current.measurementSystem == .metric ? .liter : .oz
        }
    }
    
    private func saveGoal() {
        guard let amountValue = Double(amount) else { return }
        
        DataManager.shared.setDailyGoal(
            context: modelContext,
            amount: amountValue,
            unit: selectedUnit
        )
        
        dismiss()
    }
    
    private func removeGoal() {
        DataManager.shared.deleteDailyGoal(context: modelContext)
        dismiss()
    }
}

#Preview {
    DailyGoalView()
        .modelContainer(for: DailyGoal.self, inMemory: true)
}


