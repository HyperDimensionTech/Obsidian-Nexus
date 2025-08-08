import SwiftUI
import Combine

struct SyncManagementView: View {
    @StateObject private var syncEngine = LocalSyncEngine(authService: AuthenticationService.shared)
    @StateObject private var localNetworkSync = LocalNetworkSyncEngine()
    @ObservedObject var authService = AuthenticationService.shared
    @State private var showingSignIn = false
    @State private var isManualSyncRunning = false
    @State private var showingAdvancedSettings = false
    @State private var showingConflictResolution = false
    @State private var showingEventLog = false
    
    private var isCloudConnected: Bool {
        syncEngine.connectionStatus.isConnected && authService.isAuthenticated
    }
    
    var body: some View {
        NavigationView {
            List {
                // Connection Status Section
                Section(header: Text("CONNECTION STATUS")) {
                    ConnectionStatusCard(
                        connectionStatus: syncEngine.connectionStatus,
                        syncStatus: syncEngine.syncStatus,
                        lastSyncTime: syncEngine.lastSyncTime
                    )
                }
                
                // Local Network Sync Section
                Section(header: Text("LOCAL NETWORK SYNC")) {
                    LocalNetworkSyncCard(
                        syncEngine: localNetworkSync,
                        onToggleDiscovery: {
                            if localNetworkSync.isDiscovering {
                                localNetworkSync.stopDiscovery()
                            } else {
                                localNetworkSync.startDiscovery()
                            }
                        },
                        onSyncWithDevice: { device in
                            Task {
                                await localNetworkSync.syncWithDevice(device)
                            }
                        }
                    )
                }
                
                // Cloud Sync Section
                Section(header: Text("CLOUD SYNC")) {
                    if authService.isAuthenticated {
                        CloudSyncStatusCard(
                            isConnected: isCloudConnected,
                            connectionStatus: syncEngine.connectionStatus,
                            onSignOut: handleSignOut
                        )
                    } else {
                        LocalOnlyCard(onEnableCloudSync: {
                            showingSignIn = true
                        })
                    }
                }
                
                // Sync Controls Section
                Section(header: Text("SYNC CONTROLS")) {
                    SyncControlsSection(
                        syncEngine: syncEngine,
                        isManualSyncRunning: $isManualSyncRunning,
                        onManualSync: performManualSync
                    )
                }
                
                // Sync Statistics Section
                Section(header: Text("SYNC STATISTICS")) {
                    SyncStatisticsSection(
                        pendingEventCount: syncEngine.pendingEventCount,
                        syncProgress: syncEngine.syncProgress,
                        showingEventLog: $showingEventLog
                    )
                }
                
                // Advanced Settings Section
                Section(header: Text("ADVANCED")) {
                    AdvancedSettingsSection(
                        showingAdvancedSettings: $showingAdvancedSettings,
                        showingConflictResolution: $showingConflictResolution
                    )
                }
            }
            .navigationTitle("Sync Management")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refreshSyncStatus()
            }
            .sheet(isPresented: $showingSignIn) {
                AuthenticationView(
                    onAuthenticationSuccess: handleSignInSuccess,
                    onContinueLocal: { showingSignIn = false }
                )
            }
            .sheet(isPresented: $showingAdvancedSettings) {
                AdvancedSyncSettingsView(syncEngine: syncEngine)
            }
            .sheet(isPresented: $showingConflictResolution) {
                ConflictResolutionView(syncEngine: syncEngine)
            }
            .sheet(isPresented: $showingEventLog) {
                EventLogView(syncEngine: syncEngine)
            }
        }
        .onAppear {
            // Load authentication state
            loadAuthenticationState()
        }
    }
    
    private func handleSignInSuccess(user: AuthenticatedUser) {
        showingSignIn = false
        
        Task {
            await configureCloudSync(for: user)
        }
    }
    
    private func handleSignOut() {
        Task {
            try? await authService.signOut()
            // Clear cloud provider
            syncEngine.setCloudProvider(MockCloudProvider())
        }
    }
    
    private func configureCloudSync(for user: AuthenticatedUser) async {
        // Configure your app's cloud provider with the authenticated user
        let cloudProvider = MockCloudProvider()
        syncEngine.setCloudProvider(cloudProvider)
    }
    
    private func performManualSync() {
        isManualSyncRunning = true
        Task {
            do {
                try await syncEngine.manualSync()
            } catch {
                print("Manual sync failed: \(error)")
            }
            await MainActor.run {
                isManualSyncRunning = false
            }
        }
    }
    
    private func refreshSyncStatus() async {
        // Refresh sync statistics
        do {
            _ = try await syncEngine.getSyncStats()
        } catch {
            print("Failed to refresh sync stats: \(error)")
        }
    }
    
    private func loadAuthenticationState() {
        // Authentication state is automatically loaded by AuthenticationService
        if let user = authService.currentUser {
            Task {
                await configureCloudSync(for: user)
            }
        } else {
            // Default to local-only mode
            syncEngine.setCloudProvider(MockCloudProvider())
        }
    }
}

// MARK: - Connection Status Card

struct ConnectionStatusCard: View {
    let connectionStatus: CloudConnectionStatus
    let syncStatus: SyncEngineStatus
    let lastSyncTime: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusIndicator(status: connectionStatus)
                VStack(alignment: .leading, spacing: 4) {
                    Text(connectionStatus.description)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(syncStatus.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            if let lastSync = lastSyncTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("Last synced: \(lastSync, formatter: relativeDateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatusIndicator: View {
    let status: CloudConnectionStatus
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
    }
    
    private var statusColor: Color {
        switch status {
        case .connected: return .green
        case .connecting, .syncing: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
}

// MARK: - Local Only Card

struct LocalOnlyCard: View {
    let onEnableCloudSync: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Storage Only")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Your data is stored locally on this device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "iphone")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Export to CSV anytime", systemImage: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("Download SQLite database", systemImage: "externaldrive")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("Works completely offline", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onEnableCloudSync) {
                HStack {
                    Image(systemName: "icloud")
                    Text("Enable Cloud Sync")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Cloud Sync Status Card

struct CloudSyncStatusCard: View {
    let isConnected: Bool
    let connectionStatus: CloudConnectionStatus
    let onSignOut: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cloud Sync Enabled")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(connectionStatus.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: isConnected ? "icloud.fill" : "icloud.slash")
                    .font(.system(size: 24))
                    .foregroundColor(isConnected ? .green : .orange)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Sync across all devices", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("Access via web dashboard", systemImage: "globe")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("Automatic cloud backup", systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Sign Out", action: onSignOut)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Sync Controls Section

struct SyncControlsSection: View {
    @ObservedObject var syncEngine: LocalSyncEngine
    @Binding var isManualSyncRunning: Bool
    let onManualSync: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: onManualSync) {
                HStack {
                    if isManualSyncRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(isManualSyncRunning ? "Syncing..." : "Sync Now")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(10)
            }
            .disabled(isManualSyncRunning || syncEngine.connectionStatus != .connected)
            
            Toggle("Auto Sync", isOn: .constant(true))
                .onChange(of: true) { _, enabled in
                    if enabled {
                        syncEngine.startAutoSync()
                    } else {
                        syncEngine.stopAutoSync()
                    }
                }
        }
    }
}

// MARK: - Sync Statistics Section

struct SyncStatisticsSection: View {
    let pendingEventCount: Int
    let syncProgress: SyncProgress
    @Binding var showingEventLog: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pending Changes")
                Spacer()
                Text("\(pendingEventCount)")
                    .foregroundColor(.secondary)
            }
            
            if syncProgress.current > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(syncProgress.stage.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(syncProgress.current)/\(syncProgress.total)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: syncProgress.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
            
            Button("View Event Log") {
                showingEventLog = true
            }
            .foregroundColor(.accentColor)
        }
    }
}

// MARK: - Advanced Settings Section

struct AdvancedSettingsSection: View {
    @Binding var showingAdvancedSettings: Bool
    @Binding var showingConflictResolution: Bool
    
    var body: some View {
        Group {
            Button("Advanced Settings") {
                showingAdvancedSettings = true
            }
            .foregroundColor(.accentColor)
            
            Button("Conflict Resolution") {
                showingConflictResolution = true
            }
            .foregroundColor(.accentColor)
        }
    }
}

// MARK: - Supporting Types

// AuthenticatedUser is now defined in AuthenticationService

// MARK: - Cloud Providers
// Cloud providers are now defined in CloudSyncProvider.swift

// MARK: - Removed Views

// SignInView and SignUpView have been moved to AuthenticationView.swift for better organization

// MARK: - Placeholder Views

struct AdvancedSyncSettingsView: View {
    @ObservedObject var syncEngine: LocalSyncEngine
    
    var body: some View {
        NavigationView {
            List {
                Text("Advanced sync settings")
            }
            .navigationTitle("Advanced Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ConflictResolutionView: View {
    @ObservedObject var syncEngine: LocalSyncEngine
    
    var body: some View {
        NavigationView {
            List {
                Text("Conflict resolution settings")
            }
            .navigationTitle("Conflict Resolution")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EventLogView: View {
    @ObservedObject var syncEngine: LocalSyncEngine
    
    var body: some View {
        NavigationView {
            List {
                Text("Event log will be displayed here")
            }
            .navigationTitle("Event Log")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Local Network Sync Card

struct LocalNetworkSyncCard: View {
    @ObservedObject var syncEngine: LocalNetworkSyncEngine
    let onToggleDiscovery: () -> Void
    let onSyncWithDevice: (PeerDevice) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Discovery Status
            HStack {
                Circle()
                    .fill(syncEngine.isDiscovering ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 4) {
                    Text(syncEngine.isDiscovering ? "Discovering Devices" : "Discovery Stopped")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(syncEngine.syncStatus.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(syncEngine.isDiscovering ? "Stop" : "Start") {
                    onToggleDiscovery()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            
            // Discovered Devices
            if !syncEngine.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Discovered Devices (\(syncEngine.discoveredDevices.count))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    ForEach(syncEngine.discoveredDevices, id: \.id) { device in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(device.deviceType.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if syncEngine.connectedDevices.contains(where: { $0.id == device.id }) {
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Button("Sync") {
                                    onSyncWithDevice(device)
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else if syncEngine.isDiscovering {
                Text("Searching for devices...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // Sync Statistics
            if syncEngine.pendingEventCount > 0 {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("\(syncEngine.pendingEventCount) pending changes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let lastSync = syncEngine.lastLocalSync {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("Last local sync: \(lastSync, formatter: relativeDateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Helper Formatters

private let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter
}() 