import SwiftUI

struct SearchFilterView: View {
    @Binding var searchOptions: SearchOptions
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingLocationPicker = false
    
    var body: some View {
        Form {
            TypesSection(types: $searchOptions.types)
            LocationSection(
                location: $searchOptions.location,
                showPicker: $showingLocationPicker
            )
            ConditionSection(condition: $searchOptions.condition)
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerSheet(location: $searchOptions.location)
        }
    }
}

private struct TypesSection: View {
    @Binding var types: Set<CollectionType>
    
    var body: some View {
        Section("Types") {
            ForEach(CollectionType.allCases) { type in
                Toggle(type.name, isOn: Binding(
                    get: { types.contains(type) },
                    set: { isEnabled in
                        if isEnabled {
                            types.insert(type)
                        } else {
                            types.remove(type)
                        }
                    }
                ))
            }
        }
    }
}

private struct LocationSection: View {
    @Binding var location: StorageLocation?
    @Binding var showPicker: Bool
    
    var body: some View {
        Section("Location") {
            Button {
                showPicker = true
            } label: {
                HStack {
                    Text("Location")
                    Spacer()
                    if let location = location {
                        Text(location.name)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Any")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

private struct ConditionSection: View {
    @Binding var condition: ItemCondition?
    
    var body: some View {
        Section("Condition") {
            Menu {
                Button("Any") {
                    condition = nil
                }
                ForEach(ItemCondition.allCases, id: \.rawValue) { itemCondition in
                    Button(itemCondition.rawValue) {
                        condition = itemCondition
                    }
                }
            } label: {
                HStack {
                    Text("Condition")
                    Spacer()
                    Text(condition?.rawValue ?? "Any")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct LocationPickerSheet: View {
    @Binding var location: StorageLocation?
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            LocationPicker(selectedLocationId: Binding(
                get: { location?.id },
                set: { newId in
                    if let newId = newId {
                        location = locationManager.location(withId: newId)
                    } else {
                        location = nil
                    }
                    dismiss()
                }
            ))
        }
    }
}

#Preview {
    SearchFilterView(searchOptions: .constant(SearchOptions()))
        .environmentObject(LocationManager())
} 