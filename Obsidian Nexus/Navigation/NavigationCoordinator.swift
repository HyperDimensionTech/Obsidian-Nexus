import SwiftUI

enum NavigationDestination: Hashable, Equatable, Identifiable {
    case locationDetail(StorageLocation)
    case locationSettings
    case addItems(UUID)  // locationId
    case itemDetail(InventoryItem)
    
    // Add id property for Identifiable conformance
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
        }
    }
    
    // Add Equatable conformance
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
        default:
            return false
        }
    }
    
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
        }
    }
}

@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var path = NavigationPath()
    @Published var presentedSheet: NavigationDestination?
    
    // Add tab-specific paths
    @Published var homePath = NavigationPath()
    @Published var searchPath = NavigationPath()
    @Published var collectionsPath = NavigationPath()
    @Published var settingsPath = NavigationPath()
    
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