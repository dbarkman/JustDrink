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
    @Query private var goals: [DailyGoal]
    @State private var amount: String = ""
    @State private var selectedUnit: VolumeUnit = .oz
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 60
    @FocusState private var amountFocused: Bool

    private var dailyGoal: DailyGoal? {
        goals.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Eyebrow("Drink this much every day")

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            TextField("0", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: amountSize, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.center)
                                .fixedSize()
                                .focused($amountFocused)
                                .accessibilityLabel("Daily Goal Amount")
                            Text(selectedUnit.displayName)
                                .font(.rounded(.title, weight: .heavy))
                                .foregroundStyle(Theme.ink2)
                                .contentTransition(.interpolate)
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)
                        .overlay(alignment: .bottom) {
                            Capsule()
                                .fill(Theme.water)
                                .frame(height: 3)
                        }
                        // The whole underlined area focuses the field, not just its digits
                        .contentShape(Rectangle())
                        .onTapGesture { amountFocused = true }
                        .animation(.default, value: selectedUnit)
                    }

                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(VolumeUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)

                    if dailyGoal != nil {
                        Button("Remove Goal", role: .destructive) {
                            removeGoal()
                        }
                        .font(.rounded(.body, weight: .heavy))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.horizontal, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Daily Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let goal = dailyGoal {
                    amount = editableNumber(goal.amount)
                    selectedUnit = goal.unit ?? selectedUnit
                } else {
                    // Default to user's locale
                    selectedUnit = Locale.current.measurementSystem == .metric ? .liter : .oz
                }
            }
        }
    }

    private var isValid: Bool {
        guard let value = Double(amount) else { return false }
        return value > 0
    }

    private func saveGoal() {
        guard let amountValue = Double(amount) else { return }
        DataManager.shared.setDailyGoal(context: modelContext, amount: amountValue, unit: selectedUnit)
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

