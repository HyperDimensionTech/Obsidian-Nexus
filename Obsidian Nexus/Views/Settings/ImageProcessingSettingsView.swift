import SwiftUI

struct ImageProcessingSettingsView: View {
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @State private var isEnhancing = false
    @State private var enhancementProgress: Double = 0.0
    @State private var enhancementStatus = ""
    @State private var showingEnhancementReport = false
    @State private var lastReport: EnhancementReport?
    @State private var showingClearCacheAlert = false
    
    private var imageService: EnhancedImageProcessingService {
        serviceContainer.enhancedImageProcessingService
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Image Enhancement") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "photo.stack")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text("Progressive Enhancement")
                                    .font(.headline)
                                Text("Find and add missing images to your collection")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isEnhancing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        if isEnhancing {
                            VStack(alignment: .leading, spacing: 4) {
                                ProgressView(value: enhancementProgress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                
                                Text(enhancementStatus)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: {
                            startEnhancement()
                        }) {
                            HStack {
                                Image(systemName: "wand.and.rays")
                                Text("Enhance Existing Items")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isEnhancing)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Cache Management") {
                    CacheStatisticsView(stats: cacheStats)
                        .padding(.vertical, 4)
                    
                    Button(action: {
                        showingClearCacheAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Image Cache")
                            Spacer()
                        }
                    }
                    .foregroundColor(.red)
                }
                
                if let report = lastReport {
                    Section("Last Enhancement Report") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Items Processed:")
                                Spacer()
                                Text("\(report.totalProcessed)")
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Images Found:")
                                Spacer()
                                Text("\(report.imagesFound)")
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Text("Images Failed:")
                                Spacer()
                                Text("\(report.imagesFailed)")
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                            
                            HStack {
                                Text("Success Rate:")
                                Spacer()
                                Text("\(Int(report.successRate * 100))%")
                                    .fontWeight(.medium)
                                    .foregroundColor(report.successRate > 0.8 ? .green : .orange)
                            }
                            
                            HStack {
                                Text("Processing Time:")
                                Spacer()
                                Text("\(Int(report.processingTime))s")
                                    .fontWeight(.medium)
                            }
                        }
                        .font(.subheadline)
                    }
                }
                
                Section("Advanced Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Image Quality")
                            .font(.headline)
                        
                        Text("High-quality images are automatically downloaded and cached for better performance. Images are processed with retry logic to ensure consistency.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("HTTPS Security")
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Automatic Retry")
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Smart Caching")
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Image Processing")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss action if needed
                    }
                }
            }
        }
        .alert("Clear Image Cache", isPresented: $showingClearCacheAlert) {
            Button("Clear", role: .destructive) {
                clearImageCache()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will clear all cached images. They will be re-downloaded as needed.")
        }
        .sheet(isPresented: $showingEnhancementReport) {
            if let report = lastReport {
                EnhancementReportView(report: report)
            }
        }
    }
    
    private func startEnhancement() {
        isEnhancing = true
        enhancementProgress = 0.0
        enhancementStatus = "Scanning collection..."
        
        Task {
            let report = await imageService.enhanceExistingItems()
            
            await MainActor.run {
                isEnhancing = false
                lastReport = report
                enhancementStatus = "Enhancement complete!"
                
                if report.totalProcessed > 0 {
                    showingEnhancementReport = true
                }
            }
        }
    }
    
    private func clearImageCache() {
        imageService.clearAllCaches()
    }
    
    private var cacheStats: CacheStatistics {
        imageService.getCacheStatistics()
    }
}

struct EnhancementReportView: View {
    let report: EnhancementReport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Success Icon
                Image(systemName: report.successRate > 0.8 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(report.successRate > 0.8 ? .green : .orange)
                
                Text("Enhancement Complete")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    StatRow(title: "Items Processed", value: "\(report.totalProcessed)", color: .blue)
                    StatRow(title: "Images Found", value: "\(report.imagesFound)", color: .green)
                    StatRow(title: "Images Failed", value: "\(report.imagesFailed)", color: .red)
                    StatRow(title: "Success Rate", value: "\(Int(report.successRate * 100))%", color: report.successRate > 0.8 ? .green : .orange)
                    StatRow(title: "Processing Time", value: "\(Int(report.processingTime))s", color: .gray)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

struct CacheStatisticsView: View {
    let stats: CacheStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cache Information")
                .font(.headline)
            
            HStack {
                Text("Disk Cache Size:")
                Spacer()
                Text(stats.diskCacheSizeFormatted)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Cached Files:")
                Spacer()
                Text("\(stats.diskCacheFileCount)")
                    .fontWeight(.medium)
            }
        }
        .font(.subheadline)
    }
}

#Preview {
    ImageProcessingSettingsView()
        .environmentObject(ServiceContainer.shared)
} 