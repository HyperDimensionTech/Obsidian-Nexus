import SwiftUI

struct LocationTypePickerView: View {
    @Binding var selectedType: StorageLocation.LocationType
    let parentLocation: StorageLocation?
    
    private var allowedTypes: [StorageLocation.LocationType] {
        if let parent = parentLocation {
            return parent.type.allowedChildTypes
        } else {
            return StorageLocation.LocationType.allCases
        }
    }
    
    private var groupedTypes: [(String, [StorageLocation.LocationType])] {
        Dictionary(grouping: allowedTypes) { $0.category.rawValue }
            .map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        Picker("Type", selection: $selectedType) {
            ForEach(groupedTypes, id: \.0) { category, types in
                Section {
                    ForEach(types) { locationType in
                        Label {
                            Text(locationType.name)
                        } icon: {
                            Image(systemName: locationType.icon)
                        }
                        .tag(locationType)
                    }
                } header: {
                    Text(category)
                        .font(.headline)
                        .textCase(nil)
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                }
            }
        }
        .pickerStyle(.navigationLink)
    }
}

#Preview {
    Form {
        LocationTypePickerView(
            selectedType: .constant(.room),
            parentLocation: nil
        )
        .environmentObject(PreviewData.shared.locationManager)
    }
} 