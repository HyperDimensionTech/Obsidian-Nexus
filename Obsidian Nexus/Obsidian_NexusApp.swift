//
//  Obsidian_NexusApp.swift
//  Obsidian Nexus
//
//  Created by Andrew Palmer on 12/30/24.
//

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    var qrCodeService = QRCodeService.shared
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    // Handle deep links
    func application(_ app: UIApplication, 
                     open url: URL, 
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        
        // Check if it's our URL scheme
        guard url.scheme == "pocketdimension" else { return false }
        
        // Handle location URLs
        if url.host == "location", let uuidString = url.pathComponents.last, 
           let locationId = UUID(uuidString: uuidString) {
            // Post notification with the location ID
            NotificationCenter.default.post(
                name: Notification.Name("LocationDeepLink"),
                object: nil,
                userInfo: ["locationId": locationId]
            )
            return true
        }
        
        return false
    }
}

@main
struct Obsidian_NexusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
