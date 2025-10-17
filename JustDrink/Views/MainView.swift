//
// MainView.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
// 
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var containers: [Container]
    @Query private var drinkRecords: [DrinkRecord]
    @State private var appState: AppState?
    @State private var dailyGoal: DailyGoal?
    @State private var selectedContainerIndex: Int = 0
    @State private var showDuplicateAlert = false
    @State private var showContainerSetup = false
    @State private var showDrinkLog = false
    @State private var showReminders = false
    @State private var showDailyGoal = false
    
    private let buttonSize: CGFloat = 120
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Menu button at top right
                HStack {
                    Spacer()
                    Menu {
                        Button(action: { showContainerSetup = true }) {
                            Label("Container Setup", systemImage: "waterbottle.fill")
                        }
                        Button(action: { showDrinkLog = true }) {
                            Label("Drink Log", systemImage: "list.bullet")
                        }
                        Button(action: { showReminders = true }) {
                            Label("Reminders", systemImage: "bell")
                        }
                        Button(action: { showDailyGoal = true }) {
                            Label("Daily Goal", systemImage: "target")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.circle")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 25)
                .padding(.top, 10)
                
                Spacer()
                    .frame(height: 40)
                
                // Big water drop button - almost full width
                GeometryReader { geometry in
                    VStack {
                        Button(action: recordDrink) {
                            Text("💧")
                                .font(.system(size: 80))
                                .frame(width: geometry.size.width - 50, height: geometry.size.width - 50)
                                .background(containers.isEmpty ? Color.gray : Color.blue)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 5)
                        }
                        .disabled(containers.isEmpty)
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: UIScreen.main.bounds.width - 50)
                .padding(.horizontal, 25)
                
                Spacer()
                
                // Horizontal scrolling container selection
                if !containers.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 30) {
                                ForEach(Array(containers.enumerated()), id: \.element.id) { index, container in
                                    ContainerCardView(
                                        container: container,
                                        isSelected: index == selectedContainerIndex
                                    )
                                    .onTapGesture {
                                        withAnimation {
                                            selectedContainerIndex = index
                                            appState?.selectedContainerId = container.id
                                            try? modelContext.save()
                                        }
                                    }
                                    .id(index)
                                }
                            }
                            .padding(.horizontal, max((UIScreen.main.bounds.width - 130) / 2, 30))
                        }
                        .frame(height: 140)
                        .onChange(of: selectedContainerIndex) { _, newIndex in
                            withAnimation {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                        .onAppear {
                            // Center the selected container
                            proxy.scrollTo(selectedContainerIndex, anchor: .center)
                        }
                    }
                }
                
                Spacer()
                
                // Progress bar or Set Goal button
                if let goal = dailyGoal {
                    ProgressBarView(
                        totalML: DataManager.shared.getTodaysTotalInML(context: modelContext),
                        goalML: goal.amountInML
                    )
                    .padding(.horizontal, 25)
                } else {
                    Button(action: { showDailyGoal = true }) {
                        Text("Set Goal")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 25)
                }
                
                Spacer()
                    .frame(height: 40)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showContainerSetup) {
                ContainerSetupView()
            }
            .sheet(isPresented: $showDrinkLog) {
                DrinkLogView()
            }
            .sheet(isPresented: $showReminders) {
                RemindersConfigView()
            }
            .sheet(isPresented: $showDailyGoal) {
                DailyGoalView()
                    .presentationDetents([.medium])
            }
            .alert("Confirm Drink Record", isPresented: $showDuplicateAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Record") {
                    recordDrinkConfirmed()
                }
            } message: {
                Text("You just recorded a drink less than a minute ago. Do you want to record another?")
            }
            .onAppear {
                loadAppState()
                DataManager.shared.initializeDefaultContainer(context: modelContext)
            }
        }
    }
    
    private func loadAppState() {
        appState = DataManager.shared.getAppState(context: modelContext)
        dailyGoal = DataManager.shared.getDailyGoal(context: modelContext)
        
        // Set selected container based on saved state
        if let selectedId = appState?.selectedContainerId,
           let index = containers.firstIndex(where: { $0.id == selectedId }) {
            selectedContainerIndex = index
        } else if !containers.isEmpty {
            selectedContainerIndex = 0
            appState?.selectedContainerId = containers[0].id
        }
    }
    
    private func recordDrink() {
        guard !containers.isEmpty else { return }
        
        // Check if last drink was within 1 minute
        if let lastDrink = appState?.lastDrinkTimestamp,
           Date().timeIntervalSince(lastDrink) < 60 {
            showDuplicateAlert = true
        } else {
            recordDrinkConfirmed()
        }
    }
    
    private func recordDrinkConfirmed() {
        guard selectedContainerIndex < containers.count else { return }
        
        let selectedContainer = containers[selectedContainerIndex]
        let record = DrinkRecord(
            timestamp: Date(),
            containerName: selectedContainer.name,
            capacity: selectedContainer.capacity,
            unit: selectedContainer.unit
        )
        
        modelContext.insert(record)
        appState?.lastDrinkTimestamp = Date()
        appState?.selectedContainerId = selectedContainer.id
        
        try? modelContext.save()
    }
}

struct ContainerCardView: View {
    let container: Container
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Image or SF Symbol
            if let imageData = container.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "waterbottle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 80)
                    .foregroundColor(DataManager.shared.getContainerColor(index: container.colorIndex))
            }
            
            Text(container.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 100)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
    }
}

struct ProgressBarView: View {
    let totalML: Double
    let goalML: Double
    
    var progress: Double {
        min(totalML / goalML, 1.0)
    }
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(DataManager.shared.formatVolumeForDisplay(totalML))
                    .font(.headline)
                Spacer()
                Text("\(progressPercentage)%")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                Text(DataManager.shared.formatVolumeForDisplay(goalML))
                    .font(.headline)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 20)
                        .cornerRadius(10)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .cyan]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 20)
                        .cornerRadius(10)
                }
            }
            .frame(height: 20)
        }
    }
}

#Preview {
    MainView()
        .modelContainer(for: [Container.self, DrinkRecord.self], inMemory: true)
}

