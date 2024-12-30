//
//  Obsidian_NexusApp.swift
//  Obsidian Nexus
//
//  Created by Andrew Palmer on 12/30/24.
//

import SwiftUI

@main
struct Obsidian_NexusApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var inventoryVM: InventoryViewModel
    
    init() {
        let locationManager = LocationManager()
        _locationManager = StateObject(wrappedValue: locationManager)
        _inventoryVM = StateObject(wrappedValue: 
            InventoryViewModel(
                storage: StorageManager.shared,
                locationManager: locationManager
            )
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(inventoryVM)
        }
    }
}
