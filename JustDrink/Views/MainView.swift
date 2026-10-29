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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var pickerWidth: CGFloat = 0
    @State private var drinkTick = 0
    @ScaledMetric(relativeTo: .largeTitle) private var totalSize: CGFloat = 64
    @ScaledMetric(relativeTo: .footnote) private var cardWidth: CGFloat = 104

    private var appState: AppState? {
        appStates.first
    }

    private var dailyGoal: DailyGoal? {
        goals.first
    }

    private var selectedContainer: Container? {
        selectedContainerIndex < containers.count ? containers[selectedContainerIndex] : nil
    }

    // While a sheet covers the main screen, the glass stops animating and stops reading motion
    private var sheetOpen: Bool {
        showContainerSetup || showDrinkLog || showReminders || showDailyGoal
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 12)

                    // The glass: tap to record a drink; its water level is today's progress
                    Button(action: recordDrink) {
                        WaterGlass(level: glassLevel, amountText: selectedContainer.map(capacityText), live: !sheetOpen)
                    }
                    .buttonStyle(PressScaleStyle())
                    .disabled(containers.isEmpty)
                    .containerRelativeFrame(.horizontal) { width, _ in min(width * 0.74, 300) }
                    .padding(.top, 24)
                    .accessibilityLabel("Log a drink")
                    .accessibilityValue(selectedContainer.map { "\(capacityText($0)) from \($0.name)" } ?? "Add a container first")
                    .sensoryFeedback(.impact(weight: .medium), trigger: drinkTick)

                    caption
                        .padding(.top, 16)

                    // Horizontal scrolling container selection
                    if !containers.isEmpty {
                        containerPicker
                            .padding(.top, 22)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.ground)
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showContainerSetup) {
                ContainerSetupView()
            }
            .sheet(isPresented: $showDrinkLog, onDismiss: updateTodaysTotal) {
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
                    NotificationManager.shared.rescheduleFromSavedSettings(context: modelContext)
                }
            }
            // Recalculate progress when app becomes active (e.g., in the morning)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    updateTodaysTotal()
                    NotificationManager.shared.rescheduleFromSavedSettings(context: modelContext)
                }
            }
            // Recalculate on significant time changes (midnight, DST, time zone)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                updateTodaysTotal()
            }
            // Recalculate after drinks are edited or deleted (the Drink Log saves through this same context)
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave, object: modelContext)) { _ in
                updateTodaysTotal()
            }
            // Keep the selection on the saved container when containers are added or deleted
            .onChange(of: containers.map(\.id)) { _, _ in
                syncSelection()
            }
        }
    }

    // Water level in the glass: progress toward the goal, empty when there is no goal
    private var glassLevel: Double {
        guard let goal = dailyGoal else { return 0 }
        return min(todaysTotalML / goal.amountInML, 1.0)
    }

    private func capacityText(_ container: Container) -> String {
        "\(container.capacity.formatted()) \(container.unit?.displayName ?? VolumeUnit.ml.displayName)"
    }

    // Date, today's total, and progress toward the goal (or a button to set one)
    private var header: some View {
        VStack(spacing: 8) {
            TimelineView(.everyMinute) { context in
                Eyebrow(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            }

            let total = DataManager.shared.volumeParts(todaysTotalML)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(total.value)
                    .font(.system(size: totalSize, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText(value: todaysTotalML))
                Text(total.unit)
                    .font(.rounded(.title2, weight: .bold))
                    .foregroundStyle(Theme.ink2)
            }
            .foregroundStyle(Theme.ink)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Today, \(DataManager.shared.formatVolumeForDisplay(todaysTotalML))")

            if let goal = dailyGoal {
                let percent = Int(glassLevel * 100)
                Text("\(Text("\(percent)%").foregroundStyle(Theme.waterInk)) of your \(DataManager.shared.formatVolumeForDisplay(goal.amountInML)) goal")
                    .font(.rounded(.callout, weight: .bold))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText(value: Double(percent)))
                    .transition(.opacity)
            } else {
                Button(action: { showDailyGoal = true }) {
                    Label("Set Goal", systemImage: "target")
                        .font(.rounded(.callout, weight: .heavy))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(Theme.waterInk)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .animation(.spring(duration: 0.5), value: todaysTotalML)
        .animation(.default, value: dailyGoal == nil)
    }

    @ViewBuilder
    private var caption: some View {
        if containers.isEmpty {
            Button("Add a container to start", systemImage: "plus") {
                showContainerSetup = true
            }
            .font(.rounded(.subheadline, weight: .heavy))
            .tint(Theme.waterInk)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        } else {
            Text("Tap the glass to log a drink")
                .font(.rounded(.subheadline, weight: .bold))
                .foregroundStyle(Theme.ink2)
        }
    }

    private var containerPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow("Drinking from")
                .padding(.horizontal, 25)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(containers.enumerated()), id: \.element.id) { index, container in
                            Button {
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
                            } label: {
                                ContainerCardView(
                                    container: container,
                                    isSelected: index == selectedContainerIndex,
                                    width: cardWidth
                                )
                            }
                            .buttonStyle(PressScaleStyle())
                            .id(index)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, max((pickerWidth - cardWidth) / 2, 20))
                    // Room for the selected card's badge and shadow
                    .padding(.vertical, 12)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    pickerWidth = width
                    // The side padding depends on the width, so re-center once it is known
                    proxy.scrollTo(selectedContainerIndex, anchor: .center)
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
    }

    // Floating bar with the four screens that used to live in the menu
    private var bottomBar: some View {
        HStack(spacing: 0) {
            barButton("Log", name: "Drink Log", systemImage: "clock.arrow.circlepath") { showDrinkLog = true }
            barButton("Containers", name: "Containers", systemImage: "waterbottle") { showContainerSetup = true }
            barButton("Goal", name: "Daily Goal", systemImage: "target") { showDailyGoal = true }
            barButton("Reminders", name: "Reminders", systemImage: "bell") { showReminders = true }
        }
        .padding(6)
        .modifier(BarBackground())
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    // title is the short label under the icon; name is the screen's full name for VoiceOver and the large content viewer
    private func barButton(_ title: String, name: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.rounded(.title3, weight: .semibold))
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(title)
                        .font(.rounded(.caption2, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle(scale: 0.9))
        .accessibilityLabel(name)
        .accessibilityShowsLargeContentViewer {
            Label(name, systemImage: systemImage)
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

    // Points selectedContainerIndex back at the saved container after the list changes. If that container
    // is gone, the card now in its place is selected and saved instead.
    private func syncSelection() {
        guard !containers.isEmpty else {
            selectedContainerIndex = 0
            return
        }
        withAnimation {
            if let selectedId = appState?.selectedContainerId,
               let index = containers.firstIndex(where: { $0.id == selectedId }) {
                selectedContainerIndex = index
            } else {
                selectedContainerIndex = min(selectedContainerIndex, containers.count - 1)
                if let state = appState {
                    state.selectedContainerId = containers[selectedContainerIndex].id
                    do {
                        try modelContext.save()
                    } catch {
                        print("Failed to save re-synced selected container: \(error)")
                    }
                }
            }
        }
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
        drinkTick += 1
    }
}

struct ContainerCardView: View {
    let container: Container
    let isSelected: Bool
    let width: CGFloat
    @ScaledMetric(relativeTo: .footnote) private var iconSide: CGFloat = 52

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(spacing: 6) {
            ContainerIcon(container: container, side: iconSide)

            Text(container.name)
                .font(.rounded(.footnote, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text("\(container.capacity.formatted()) \(container.unit?.displayName ?? VolumeUnit.ml.displayName)")
                .font(.rounded(.caption, weight: .bold))
                .foregroundStyle(Theme.ink2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(width: width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            shape
                .fill(Theme.card)
                .shadow(color: Theme.water.opacity(isSelected ? 0.25 : 0), radius: 10, y: 5)
        )
        .overlay(shape.strokeBorder(isSelected ? Theme.water : Theme.line, lineWidth: isSelected ? 2.5 : 1))
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.rounded(.title3, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Theme.water)
                    .background(Circle().fill(Theme.ground).padding(-2))
                    .offset(x: 8, y: -8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// Liquid Glass on iOS 26 and later, frosted material before that
private struct BarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.line))
                .shadow(color: .black.opacity(0.12), radius: 15, y: 5)
        }
    }
}

#Preview {
    MainView()
        .modelContainer(for: [Container.self, DrinkRecord.self, AppState.self, DailyGoal.self], inMemory: true)
}
