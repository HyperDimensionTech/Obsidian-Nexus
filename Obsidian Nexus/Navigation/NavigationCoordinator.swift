import SwiftUI
import Combine

/**
 A centralized coordinator for handling navigation throughout the app.
 
 This class manages navigation paths for different tabs and provides methods to navigate
 to various destinations using SwiftUI's NavigationStack and sheet presentations.
 
 ## Key Features
 
 - Tab-specific navigation paths (homePath, searchPath, collectionsPath, settingsPath)
 - Sheet presentation management
 - Helper methods for common navigation actions
 
 ## Usage
 
 1. Add the coordinator to your environment:
 
 ```swift
 @main
 struct MyApp: App {
     @StateObject private var navigationCoordinator = NavigationCoordinator()
     
     var body: some Scene {
         WindowGroup {
             ContentView()
                 .environmentObject(navigationCoordinator)
         }
     }
 }
 ```
 
 2. Set up the NavigationStack in your tab views:
 
 ```swift
 struct HomeTabView: View {
     @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
     
     var body: some View {
         NavigationStack(path: navigationCoordinator.bindingForTab("Home")) {
             // Home content
             HomeContentView()
                 .navigationDestination(for: NavigationDestination.self) { destination in
                     switch destination {
                     case .locationDetail(let location):
                         LocationItemsView(location: location)
                     case .itemDetail(let item):
                         ItemDetailView(item: item)
                     // Handle other destinations
                     }
                 }
         }
     }
 }
 ```
 
 3. Navigate between views:
 
 ```swift
 // In any view with access to the environment object
 struct MyView: View {
     @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
     
     var body: some View {
         Button("View Item") {
             navigationCoordinator.navigateToItemDetail(item: myItem)
         }
     }
 }
 ```
 */

/**
 Represents navigation destinations throughout the app.
 
 This enum is used with NavigationPath to allow navigation to views that require parameters.
 Each case represents a specific destination in the app.
 */
enum NavigationDestination: Hashable, Equatable, Identifiable {
    /// Navigate to a location's detail view
    case locationDetail(StorageLocation)
    
    /// Navigate to location settings
    case locationSettings
    
    /// Navigate to add items with a specific location ID
    case addItems(UUID)  // locationId
    
    /// Navigate to an item's detail view
    case itemDetail(InventoryItem)
    
    /// Navigate to display a location's QR code
    case locationQRCode(StorageLocation)
    
    /// Navigate to a location that was scanned via QR code
    case scannedLocation(StorageLocation)
    
    /// Unique ID for Identifiable conformance
    var id: String {
        switch self {
        case .locationDetail(let location):
            return "locationDetail-\(location.id)"
        case .locationSettings:
            return "locationSettings"
        case .addItems(let locationId):
            return "addItems-\(locationId)"
        case .itemDetail(let item):
            return "itemDetail-\(item.id)"
        case .locationQRCode(let location):
            return "locationQRCode-\(location.id)"
        case .scannedLocation(let location):
            return "scannedLocation-\(location.id)"
        }
    }
    
    // MARK: - Equatable Implementation
    
    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.locationDetail(let l), .locationDetail(let r)):
            return l.id == r.id
        case (.locationSettings, .locationSettings):
            return true
        case (.addItems(let l), .addItems(let r)):
            return l == r
        case (.itemDetail(let l), .itemDetail(let r)):
            return l.id == r.id
        case (.locationQRCode(let l), .locationQRCode(let r)):
            return l.id == r.id
        case (.scannedLocation(let l), .scannedLocation(let r)):
            return l.id == r.id
        default:
            return false
        }
    }
    
    // MARK: - Hashable Implementation
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .locationDetail(let location):
            hasher.combine("locationDetail")
            hasher.combine(location.id)
        case .locationSettings:
            hasher.combine("locationSettings")
        case .addItems(let locationId):
            hasher.combine("addItems")
            hasher.combine(locationId)
        case .itemDetail(let item):
            hasher.combine("itemDetail")
            hasher.combine(item.id)
        case .locationQRCode(let location):
            hasher.combine("locationQRCode")
            hasher.combine(location.id)
        case .scannedLocation(let location):
            hasher.combine("scannedLocation")
            hasher.combine(location.id)
        }
    }
}

/**
 Manages navigation throughout the app with tab-specific navigation paths.
 
 This coordinator maintains separate navigation paths for different tabs and provides
 methods for navigation and sheet presentation management.
 */
@MainActor
class NavigationCoordinator: ObservableObject {
    // MARK: - Published Properties
    
    /// General navigation path (used as fallback)
    @Published var path = NavigationPath()
    
    /// Currently presented sheet
    @Published var presentedSheet: NavigationDestination?
    
    /// Tab-specific navigation paths
    @Published var homePath = NavigationPath()
    @Published var searchPath = NavigationPath()
    @Published var collectionsPath = NavigationPath()
    @Published var settingsPath = NavigationPath()
    
    // MARK: - Navigation Helpers for Components
    
    /**
     Navigates to a detail view for the specified inventory item.
     
     - Parameter item: The inventory item to show details for
     */
    func navigateToItemDetail(item: InventoryItem) {
        navigate(to: .itemDetail(item))
    }
    
    /**
     Navigates to the items view for the specified location.
     
     - Parameter locationId: The ID of the storage location to show
     */
    func navigateToLocation(locationId: UUID) {
        // Find the location by ID
        if let location = LocationManager().location(withId: locationId) {
            navigate(to: .locationDetail(location))
        }
    }
    
    /**
     Navigates to a series detail view.
     
     - Parameter name: The name of the series to show
     */
    func navigateToSeries(name: String) {
        // Navigate to series detail
        // This will need to be expanded when we have a dedicated series destination
        // For now, let's rely on existing paths
        if let tab = currentTab() {
            switch tab {
            case "Collections":
                collectionsPath.append(name) // Assuming we've set up destination handlers for String
            default:
                // Handle in default path
                path.append(name)
            }
        } else {
            path.append(name)
        }
    }
    
    // MARK: - Tab Navigation
    
    /**
     Returns the navigation path for the specified tab.
     
     - Parameter tab: The tab name to get the path for
     - Returns: The NavigationPath for the specified tab
     */
    func pathForTab(_ tab: String) -> NavigationPath {
        switch tab {
        case "Home":
            return homePath
        case "Browse & Search":
            return searchPath
        case "Collections":
            return collectionsPath
        case "Settings":
            return settingsPath
        default:
            return path
        }
    }
    
    /**
     Returns a binding to the navigation path for the specified tab.
     
     - Parameter tab: The tab name to get the binding for
     - Returns: A Binding to the NavigationPath for the specified tab
     */
    func bindingForTab(_ tab: String) -> Binding<NavigationPath> {
        switch tab {
        case "Home":
            return Binding(
                get: { self.homePath },
                set: { self.homePath = $0 }
            )
        case "Browse & Search":
            return Binding(
                get: { self.searchPath },
                set: { self.searchPath = $0 }
            )
        case "Collections":
            return Binding(
                get: { self.collectionsPath },
                set: { self.collectionsPath = $0 }
            )
        case "Settings":
            return Binding(
                get: { self.settingsPath },
                set: { self.settingsPath = $0 }
            )
        default:
            return Binding(
                get: { self.path },
                set: { self.path = $0 }
            )
        }
    }
    
    /**
     Clears the navigation path for the specified tab.
     
     - Parameter tab: The tab name to clear the path for
     */
    func clearPathForTab(_ tab: String) {
        switch tab {
        case "Home":
            homePath.removeLast(homePath.count)
        case "Browse & Search":
            searchPath.removeLast(searchPath.count)
        case "Collections":
            collectionsPath.removeLast(collectionsPath.count)
        case "Settings":
            settingsPath.removeLast(settingsPath.count)
        default:
            path.removeLast(path.count)
        }
    }
    
    func navigate(to destination: NavigationDestination) {
        // Determine which path to use based on the current context
        if let tab = currentTab() {
            switch tab {
            case "Home":
                homePath.append(destination)
            case "Browse & Search":
                searchPath.append(destination)
            case "Collections":
                collectionsPath.append(destination)
            case "Settings":
                settingsPath.append(destination)
            default:
                path.append(destination)
            }
        } else {
            path.append(destination)
        }
    }
    
    func navigateBack() {
        path.removeLast()
    }
    
    func navigateToRoot() {
        path.removeLast(path.count)
        homePath.removeLast(homePath.count)
        searchPath.removeLast(searchPath.count)
        collectionsPath.removeLast(collectionsPath.count)
        settingsPath.removeLast(settingsPath.count)
    }
    
    func presentSheet(_ destination: NavigationDestination) {
        print("Presenting sheet with destination: \(destination)")
        presentedSheet = destination
        print("presentedSheet is now: \(String(describing: presentedSheet))")
    }
    
    func dismissSheet() {
        presentedSheet = nil
        // Clear any navigation state that might have been built up in sheets
        navigateToRoot()
    }
    
    private func currentTab() -> String? {
        // This is a simple implementation. You might want to make this more robust
        // by actually tracking the current tab in your app's state
        if homePath.count > 0 { return "Home" }
        if searchPath.count > 0 { return "Browse & Search" }
        if collectionsPath.count > 0 { return "Collections" }
        if settingsPath.count > 0 { return "Settings" }
        return nil
    }
}

// MARK: - Main Tab Enum

/**
 Represents the main tabs in the app's interface.
 
 Used by the NavigationCoordinator to track and switch between the main tabs.
 */
enum MainTab: String, CaseIterable {
    /// The inventory tab showing all items
    case inventory = "Inventory"
    
    /// The locations tab showing all storage locations
    case locations = "Locations"
    
    /// The search tab for finding items and locations
    case search = "Search"
    
    /// The collections tab for viewing series, authors, etc.
    case collections = "Collections"
    
    /// The settings tab for app configuration
    case settings = "Settings"
    
    /// Icon name for each tab
    var iconName: String {
        switch self {
        case .inventory: return "books.vertical"
        case .locations: return "folder"
        case .search: return "magnifyingglass"
        case .collections: return "square.grid.2x2"
        case .settings: return "gear"
        }
    }
} 