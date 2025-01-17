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
    
    func navigate(to destination: NavigationDestination) {
        path.append(destination)
    }
    
    func navigateBack() {
        path.removeLast()
    }
    
    func navigateToRoot() {
        path.removeLast(path.count)
    }
    
    func presentSheet(_ destination: NavigationDestination) {
        print("Presenting sheet with destination: \(destination)")
        presentedSheet = destination
        print("presentedSheet is now: \(String(describing: presentedSheet))")
    }
    
    func dismissSheet() {
        presentedSheet = nil
    }
} 