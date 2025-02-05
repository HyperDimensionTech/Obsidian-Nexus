//
//  ContentView.swift
//  Obsidian Nexus
//
//  Created by Andrew Palmer on 12/30/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager: LocationManager
    @StateObject private var inventoryViewModel: InventoryViewModel
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    
    init() {
        let storage = StorageManager.shared
        let locationManager = LocationManager(storage: storage)
        _locationManager = StateObject(wrappedValue: locationManager)
        _inventoryViewModel = StateObject(wrappedValue: 
            InventoryViewModel(storage: storage, locationManager: locationManager))
    }
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            CollectionsTabView()
                .tabItem {
                    Label("Collections", systemImage: "books.vertical")
                }
            
            SearchTabView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            AddItemTabView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environmentObject(locationManager)
        .environmentObject(inventoryViewModel)
        .environmentObject(navigationCoordinator)
    }
}

#Preview {
    ContentView()
        .environmentObject(PreviewData.shared.locationManager)
        .environmentObject(InventoryViewModel(locationManager: PreviewData.shared.locationManager))
}
