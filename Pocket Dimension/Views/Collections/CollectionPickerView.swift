import SwiftUI

struct CollectionPickerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var collectionManager: CollectionManager
    @Binding var selectedCollectionId: UUID?
    
    @State private var showingNewCollectionSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(collectionManager.collections) { collection in
                        Button {
                            selectedCollectionId = collection.id
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(collection.name)
                                        .font(.headline)
                                    if let description = collection.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if collection.id == selectedCollectionId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        showingNewCollectionSheet = true
                    } label: {
                        Label("Create New Collection", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Select Collection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewCollectionSheet) {
            NewCollectionView()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct NewCollectionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var collectionManager: CollectionManager
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedType: CollectionType = .books
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Collection Name", text: $name)
                    TextField("Description (Optional)", text: $description)
                }
                
                Section {
                    Picker("Type", selection: $selectedType) {
                        ForEach(CollectionType.allCases) { type in
                            Text(type.name).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("New Collection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newCollection = Collection(
                            name: name,
                            description: description.isEmpty ? nil : description,
                            type: selectedType
                        )
                        collectionManager.addCollection(newCollection)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
} 