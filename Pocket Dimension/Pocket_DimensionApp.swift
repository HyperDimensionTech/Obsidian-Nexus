//
//  Pocket_DimensionApp.swift
//  Pocket Dimension
//
//  Created by Andrew Palmer on 12/30/24.
//

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    var qrCodeService = QRCodeService.shared
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Pre-initialize database
        _ = DatabaseManager.shared
        
        // Log app launch with database info
        print("🚀 APP LAUNCH: Pocket Dimension started")
        let fm = FileManager.default
        
        do {
            let dbURL = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("pocket_dimension.sqlite")
            
            print("🚀 APP LAUNCH: Database path: \(dbURL.path)")
            print("🚀 APP LAUNCH: Database exists: \(fm.fileExists(atPath: dbURL.path))")
        } catch {
            print("🚀 APP LAUNCH ERROR: Failed to get database URL: \(error.localizedDescription)")
        }
        
        // Force StorageManager initialization
        _ = StorageManager.shared
        
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
struct Pocket_DimensionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
