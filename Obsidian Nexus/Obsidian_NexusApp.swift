//
//  Obsidian_NexusApp.swift
//  Obsidian Nexus
//
//  Created by Andrew Palmer on 12/30/24.
//

import SwiftUI

@main
struct Obsidian_NexusApp: App {
    // Create shared instances that persist through app lifecycle
    @StateObject private var locationManager = LocationManager()
    @StateObject private var inventoryViewModel: InventoryViewModel
    
    init() {
        let storage = StorageManager.shared
        let locationMgr = LocationManager(storage: storage)
        _locationManager = StateObject(wrappedValue: locationMgr)
        _inventoryViewModel = StateObject(wrappedValue: 
            InventoryViewModel(storage: storage, locationManager: locationMgr))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(inventoryViewModel)
        }
    }
}
