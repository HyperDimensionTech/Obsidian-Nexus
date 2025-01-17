//
//  ContentView.swift
//  Obsidian Nexus
//
//  Created by Andrew Palmer on 12/30/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var inventoryViewModel: InventoryViewModel
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    
    init() {
        // Initialize InventoryViewModel with LocationManager
        let locationManager = LocationManager()
        _locationManager = StateObject(wrappedValue: locationManager)
        _inventoryViewModel = StateObject(wrappedValue: 
            InventoryViewModel(locationManager: locationManager))
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
        .onAppear {
            locationManager.loadSampleData()
            inventoryViewModel.loadSampleData()
        }
    }
}

#Preview {
    ContentView()
}
