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
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Container.createdAt) private var containers: [Container]
    @Query private var appStates: [AppState]
    @Query private var goals: [DailyGoal]
    @State private var todaysTotalML: Double = 0
    @State private var selectedContainerIndex: Int = 0
    @State private var showDuplicateAlert = false
    @State private var showContainerSetup = false
    @State private var showDrinkLog = false
    @State private var showReminders = false
    @State private var showDailyGoal = false
    @State private var isInitialized = false
    
    private var appState: AppState? {
        appStates.first
    }
    
    private var dailyGoal: DailyGoal? {
        goals.first
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Menu button at top right
                HStack {
                    Spacer()
                    Menu {
                        Button(action: { showContainerSetup = true }) {
                            Label("Containers", systemImage: "waterbottle.fill")
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
                
                // Big water drop button - fixed, capped diameter
                GeometryReader { geometry in
                    let diameter = min(geometry.size.width, 320)
                    Button(action: recordDrink) {
                        Image(systemName: "waterbottle.fill")
                            .font(.system(size: diameter * 0.5))
                            .foregroundColor(.white)
                            .frame(width: diameter, height: diameter)
                            .background(containers.isEmpty ? Color.gray : Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 5)
                    }
                    .disabled(containers.isEmpty)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 360)
                
                Spacer()
                
                // Horizontal scrolling container selection
                if !containers.isEmpty {
                    GeometryReader { geometry in
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
                                if let state = appState {
                                    state.selectedContainerId = container.id
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        print("Failed to save selected container: \(error)")
                                    }
                                }
                            }
                        }
                                        .id(index)
                                    }
                                }
                                .padding(.horizontal, max((geometry.size.width - 130) / 2, 30))
                            }
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
                    .frame(height: 140)
                }
                
                Spacer()
                
                // Progress bar or Set Goal button
                if let goal = dailyGoal {
                    ProgressBarView(
                        totalML: todaysTotalML,
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
                if !isInitialized {
                    isInitialized = true
                    DataManager.shared.initializeDefaultContainer(context: modelContext)
                    loadAppState()
                    updateTodaysTotal()
                }
            }
            // Recalculate progress when app becomes active (e.g., in the morning)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    updateTodaysTotal()
                }
            }
            // Recalculate on significant time changes (midnight, DST, time zone)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                updateTodaysTotal()
            }
        }
    }
    
    private func loadAppState() {
        // Create app state if it doesn't exist
        if appState == nil {
            let newState = AppState()
            modelContext.insert(newState)
            do {
                try modelContext.save()
            } catch {
                print("Failed to create initial AppState: \(error)")
            }
        }
        
        // Set selected container based on saved state
        if let selectedId = appState?.selectedContainerId,
           let index = containers.firstIndex(where: { $0.id == selectedId }) {
            selectedContainerIndex = index
        } else if !containers.isEmpty {
            selectedContainerIndex = 0
            if let state = appState {
                state.selectedContainerId = containers[0].id
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to save default selected container: \(error)")
                }
            }
        }
        
        updateTodaysTotal()
    }
    
    private func updateTodaysTotal() {
        // Fetch only today's records
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<DrinkRecord>(
            predicate: #Predicate { record in
                record.timestamp >= startOfDay && record.timestamp < endOfDay
            }
        )
        
        let todaysRecords = (try? modelContext.fetch(descriptor)) ?? []
        todaysTotalML = todaysRecords.reduce(0) { $0 + $1.capacityInML }
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
            unit: selectedContainer.unit ?? .ml
        )
        
        modelContext.insert(record)
        
        if let state = appState {
            state.lastDrinkTimestamp = Date()
            state.selectedContainerId = selectedContainer.id
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save new drink record: \(error)")
        }
        
        // Update today's total after recording
        updateTodaysTotal()
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
        .modelContainer(for: [Container.self, DrinkRecord.self, AppState.self, DailyGoal.self], inMemory: true)
}

