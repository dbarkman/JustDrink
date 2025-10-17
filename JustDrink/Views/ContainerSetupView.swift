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
                ForEach(containers) { container in
                    ContainerRowView(container: container)
                        .onTapGesture {
                            containerToEdit = container
                        }
                }
                .onDelete(perform: deleteContainers)
            }
            .navigationTitle("Containers")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddContainer = true }) {
                        Image(systemName: "plus")
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
        try? modelContext.save()
    }
}

struct ContainerRowView: View {
    let container: Container
    
    var body: some View {
        HStack(spacing: 15) {
            // Image or SF Symbol
            if let imageData = container.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "waterbottle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 50)
                    .foregroundColor(DataManager.shared.getContainerColor(index: container.colorIndex))
            }
            
            VStack(alignment: .leading) {
                Text(container.name)
                    .font(.headline)
                Text("\(container.capacity.formatted()) \(container.unit.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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
    
    var isEditing: Bool {
        container != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Container Details") {
                    TextField("Name", text: $name)
                    
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
                }
                
                Section("Photo (Optional)") {
                    if let image = selectedImage {
                        HStack {
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Spacer()
                        }
                        
                        Button("Change Photo") {
                            showingImagePicker = true
                        }
                        
                        Button("Remove Photo", role: .destructive) {
                            selectedImage = nil
                        }
                    } else {
                        Button("Add Photo") {
                            showingImagePicker = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Container" : "Add Container")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
                    capacity = String(container.capacity)
                    selectedUnit = container.unit
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
        
        try? modelContext.save()
        dismiss()
    }
}

// Image selection with photo library and camera support
struct ImagePicker: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var showingSourceSelection = true
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        if showingSourceSelection {
            VStack(spacing: 20) {
                Text("Choose Photo Source")
                    .font(.headline)
                    .padding()
                
                Button(action: {
                    sourceType = .camera
                    showingSourceSelection = false
                }) {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    sourceType = .photoLibrary
                    showingSourceSelection = false
                }) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button("Cancel") {
                    dismiss()
                }
                .padding()
            }
            .padding()
        } else {
            ImagePickerController(image: $image, sourceType: sourceType)
        }
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

