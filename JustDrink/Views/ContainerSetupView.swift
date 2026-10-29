//
// ContainerSetupView.swift
// JustDrink
//
// Created by David Barkman on 10/16/25.
//
//

import SwiftUI
import SwiftData
import PhotosUI

struct ContainerSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Container.createdAt) private var containers: [Container]
    @State private var showingAddContainer = false
    @State private var containerToEdit: Container?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(containers) { container in
                        Button {
                            containerToEdit = container
                        } label: {
                            ContainerRowView(container: container)
                        }
                        .listRowBackground(Theme.card)
                    }
                    .onDelete(perform: deleteContainers)
                } header: {
                    if !containers.isEmpty {
                        Text("What you drink from. Tap one to edit it.")
                            .font(.rounded(.subheadline, weight: .bold))
                            .foregroundStyle(Theme.ink2)
                            .textCase(nil)
                    }
                } footer: {
                    if !containers.isEmpty {
                        Text("Swipe left on a container to delete it. Your drink log keeps its past drinks.")
                            .font(.rounded(.footnote, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .overlay {
                if containers.isEmpty {
                    ContentUnavailableView(
                        "No Containers",
                        systemImage: "waterbottle",
                        description: Text("Tap + to add the bottle, glass or mug you drink from.")
                    )
                    .transition(.opacity)
                }
            }
            .animation(.default, value: containers.isEmpty)
            .navigationTitle("Containers")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Container", systemImage: "plus") {
                        showingAddContainer = true
                    }
                }
            }
            .sheet(isPresented: $showingAddContainer) {
                ContainerEditView(container: nil)
            }
            .sheet(item: $containerToEdit) { container in
                ContainerEditView(container: container)
            }
        }
    }

    private func deleteContainers(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(containers[index])
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to save after deleting containers: \(error)")
        }
    }
}

struct ContainerRowView: View {
    let container: Container
    @ScaledMetric(relativeTo: .headline) private var iconSide: CGFloat = 52

    var body: some View {
        HStack(spacing: 14) {
            ContainerIcon(container: container, side: iconSide)

            VStack(alignment: .leading, spacing: 2) {
                Text(container.name)
                    .font(.rounded(.headline, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("\(container.capacity.formatted()) \(container.unit?.displayName ?? VolumeUnit.ml.displayName)")
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(Theme.ink2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.rounded(.footnote, weight: .heavy))
                .foregroundStyle(Theme.ink2.opacity(0.6))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

struct ContainerEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var containers: [Container]

    let container: Container?

    @State private var name: String = ""
    @State private var capacity: String = ""
    @State private var selectedUnit: VolumeUnit = .ml
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @ScaledMetric(relativeTo: .body) private var photoHeight: CGFloat = 180

    var isEditing: Bool {
        container != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let image = selectedImage {
                        // Fills the row's width, cropped to the frame rather than widening it
                        Color.clear
                            .frame(height: photoHeight)
                            .overlay {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)

                        Button("Change Photo", systemImage: "photo") {
                            showingImagePicker = true
                        }
                        .listRowBackground(Theme.card)

                        Button("Remove Photo", systemImage: "trash", role: .destructive) {
                            selectedImage = nil
                        }
                        .listRowBackground(Theme.card)
                    } else {
                        Button {
                            showingImagePicker = true
                        } label: {
                            AddPhotoPrompt(height: photoHeight)
                        }
                        .buttonStyle(PressScaleStyle(scale: 0.98))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    TextField("Name", text: $name)
                } header: {
                    Eyebrow("Name")
                }
                .listRowBackground(Theme.card)

                Section {
                    HStack {
                        TextField("Capacity", text: $capacity)
                            .keyboardType(.decimalPad)
                        Spacer(minLength: 8)
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
                    Eyebrow("How much it holds")
                }
                .listRowBackground(Theme.card)
            }
            .font(.rounded(.body, weight: .semibold))
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .animation(.default, value: selectedImage)
            .navigationTitle(isEditing ? "Edit Container" : "Add Container")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveContainer()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onAppear {
                if let container = container {
                    name = container.name
                    capacity = editableNumber(container.capacity)
                    selectedUnit = container.unit ?? selectedUnit
                    if let imageData = container.imageData {
                        selectedImage = UIImage(data: imageData)
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        !name.isEmpty && Double(capacity) != nil && (Double(capacity) ?? 0) > 0
    }

    private func saveContainer() {
        guard let capacityValue = Double(capacity) else { return }

        if let container = container {
            // Editing existing container
            container.name = name
            container.capacity = capacityValue
            container.unit = selectedUnit
            container.imageData = selectedImage?.jpegData(compressionQuality: 0.8)
        } else {
            // Creating new container
            let imageData = selectedImage?.jpegData(compressionQuality: 0.8)

            // Determine color index for containers without images
            var colorIndex = 0
            if imageData == nil {
                let containersWithoutImages = containers.filter { $0.imageData == nil }
                colorIndex = containersWithoutImages.count
            }

            let newContainer = Container(
                name: name,
                capacity: capacityValue,
                unit: selectedUnit,
                imageData: imageData,
                colorIndex: colorIndex
            )
            modelContext.insert(newContainer)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save container changes: \(error)")
        }
        dismiss()
    }
}

// Dashed drop zone shown until a container has a photo
private struct AddPhotoPrompt: View {
    let height: CGFloat
    @ScaledMetric(relativeTo: .title2) private var tileSide: CGFloat = 64

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.rounded(.title2, weight: .semibold))
                .foregroundStyle(Theme.waterInk)
                .frame(width: tileSide, height: tileSide)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.water.opacity(0.14)))
            Text("Add a Photo")
                .font(.rounded(.headline, weight: .heavy))
                .foregroundStyle(Theme.waterInk)
            Text("Optional. Take one or pick from your library.")
                .font(.rounded(.footnote, weight: .bold))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: height)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
        )
    }
}

// Image selection with photo library and camera support
struct ImagePicker: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var showingCamera = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        if showingCamera {
            // Keep existing camera flow via UIImagePickerController
            ImagePickerController(image: $image, sourceType: .camera)
                .ignoresSafeArea()
        } else {
            VStack(spacing: 14) {
                Text("Add a Photo")
                    .font(.rounded(.title2, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Pick one from your library or take a new one.")
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    SourceRow(title: "Choose from Library", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(PressScaleStyle(scale: 0.97))

                Button(action: { showingCamera = true }) {
                    SourceRow(title: "Take Photo", systemImage: "camera")
                }
                .buttonStyle(PressScaleStyle(scale: 0.97))

                Button("Cancel") { dismiss() }
                    .font(.rounded(.body, weight: .heavy))
                    .tint(Theme.waterInk)
                    .padding()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.ground)
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        image = uiImage
                    }
                    dismiss()
                }
            }
        }
    }
}

// One choice in the photo source sheet
private struct SourceRow: View {
    let title: String
    let systemImage: String
    @ScaledMetric(relativeTo: .headline) private var tileSide: CGFloat = 44

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.rounded(.title3, weight: .semibold))
                .foregroundStyle(Theme.waterInk)
                .frame(width: tileSide, height: tileSide)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.water.opacity(0.14)))
            Text(title)
                .font(.rounded(.headline, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.rounded(.footnote, weight: .heavy))
                .foregroundStyle(Theme.ink2.opacity(0.6))
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.line))
    }
}

struct ImagePickerController: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerController

        init(_ parent: ImagePickerController) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ContainerSetupView()
        .modelContainer(for: Container.self, inMemory: true)
}

