import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var inventoryViewModel: InventoryViewModel
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var userPreferences: UserPreferences
    
    @State private var editingLocation: StorageLocation?
    @State private var showingDeleteAlert = false
    @State private var showingAddItems = false
    @State private var selectedLocation: StorageLocation?
    @State private var showingAddLocation = false
    @State private var expandedLocations: Set<UUID> = []
    
    var body: some View {
        NavigationStack(path: navigationCoordinator.bindingForTab("Settings")) {
            List {
                Section(header: Text("APPEARANCE")) {
                    HStack {
                        Text("Theme")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        ThemeButton(
                            title: "System",
                            systemImage: "circle.lefthalf.filled",
                            isSelected: userPreferences.theme == .system,
                            action: { userPreferences.theme = .system }
                        )
                        
                        ThemeButton(
                            title: "Light",
                            systemImage: "sun.max.fill",
                            isSelected: userPreferences.theme == .light,
                            action: { userPreferences.theme = .light }
                        )
                        
                        ThemeButton(
                            title: "Dark",
                            systemImage: "moon.fill",
                            isSelected: userPreferences.theme == .dark,
                            action: { userPreferences.theme = .dark }
                        )
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("CURRENCY")) {
                    Picker("Default Currency", selection: $userPreferences.defaultCurrency) {
                        ForEach(Price.Currency.allCases, id: \.self) { currency in
                            HStack {
                                Text(currency.symbol)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)
                                Text(currency.name)
                                Text("(\(currency.code))")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .tag(currency)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    // Display information about current currency
                    let examplePrice = Price(amount: 100)
                    HStack {
                        Text("Example:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(examplePrice.convertedTo(userPreferences.defaultCurrency).formatted())
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                }
                
                Section(header: Text("ITEM DISPLAY")) {
                    NavigationLink {
                        ItemDisplaySettingsView()
                    } label: {
                        HStack {
                            Label("Item Information", systemImage: "list.bullet.indent")
                            Spacer()
                            Text("\(userPreferences.itemInfoDisplayOptions.count) selected")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section(header: Text("DATA")) {
                    NavigationLink {
                        BackupSettingsView()
                    } label: {
                        Label("Backup & Restore", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    NavigationLink {
                        ImportExportView()
                    } label: {
                        Label("Import/Export", systemImage: "square.and.arrow.up.on.square")
                    }
                }
                
                Section(header: Text("ADVANCED")) {
                    NavigationLink(destination: ISBNMappingsView()) {
                        HStack {
                            Image(systemName: "barcode")
                                .foregroundColor(.accentColor)
                                .frame(width: 24)
                            Text("ISBN Mappings")
                        }
                    }
                    
                    #if DEBUG
                    // Debug tools removed - no longer needed
                    #endif
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddItems) {
                if let location = selectedLocation {
                    NavigationView {
                        AddItemsToLocationView(locationId: location.id)
                            .environmentObject(locationManager)
                            .environmentObject(inventoryViewModel)
                            .environmentObject(navigationCoordinator)
                    }
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                NavigationView {
                    AddLocationView(parentLocation: selectedLocation)
                        .environmentObject(locationManager)
                }
            }
            .sheet(item: $editingLocation) { location in
                NavigationView {
                    EditLocationView(location: location)
                        .environmentObject(locationManager)
                }
            }
            .alert("Delete Location", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let location = selectedLocation {
                        try? locationManager.removeLocation(location.id)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let location = selectedLocation {
                    Text("Are you sure you want to delete '\(location.name)' and all its contents?")
                }
            }
        }
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: Notification.Name("TabDoubleTapped"),
                object: nil,
                queue: .main
            ) { notification in
                if let tab = notification.object as? String, tab == "Settings" {
                    DispatchQueue.main.async {
                        navigationCoordinator.navigateToRoot()
                    }
                }
            }
        }
        .preferredColorScheme(userPreferences.theme.colorScheme)
    }
}

struct ThemeButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : .primary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView()
        .environmentObject(LocationManager())
        .environmentObject(InventoryViewModel(locationManager: LocationManager()))
        .environmentObject(NavigationCoordinator())
        .environmentObject(UserPreferences())
}

private struct TrashSection: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @State private var showingEmptyTrashAlert = false
    
    var body: some View {
        List {
            if inventoryViewModel.trashedItems.isEmpty {
                Text("No items in trash")
                    .foregroundColor(.secondary)
            } else {
                ForEach(inventoryViewModel.trashedItems) { item in
                    ItemRow(item: item)
                        .swipeActions {
                            Button("Restore") {
                                try? inventoryViewModel.restoreItem(item)
                            }
                            .tint(.blue)
                        }
                }
            }
        }
        .navigationTitle("Trash")
        .toolbar {
            if !inventoryViewModel.trashedItems.isEmpty {
                Button("Empty Trash", role: .destructive) {
                    showingEmptyTrashAlert = true
                }
            }
        }
        .alert("Empty Trash?", isPresented: $showingEmptyTrashAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Empty", role: .destructive) {
                try? inventoryViewModel.emptyTrash()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            inventoryViewModel.loadTrashedItems()
        }
    }
} 