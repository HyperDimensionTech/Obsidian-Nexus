import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var thumbnailService = ThumbnailService()
    
    @State private var thumbnailURL: URL?
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingImagePicker = false
    @State private var dragOffset = CGSize.zero
    @State private var currentItem: InventoryItem
    @State private var isTransitioning = false
    
    let item: InventoryItem
    
    init(item: InventoryItem) {
        self.item = item
        _currentItem = State(initialValue: item)
    }
    
    private var filteredItems: [InventoryItem] {
        // First filter by type
        let sameTypeItems = inventoryViewModel.items.filter { $0.type == currentItem.type }
        
        // If this is a volumed series (manga/comics), filter by series and sort by volume
        if let currentSeries = currentItem.series, currentItem.volume != nil {
            let seriesItems = sameTypeItems.filter { $0.series == currentSeries }
            let sortedItems = seriesItems.sorted { (item1, item2) in
                guard let vol1 = item1.volume, let vol2 = item2.volume else {
                    return item1.title < item2.title // Fallback to title sort if no volume
                }
                return vol1 < vol2
            }
            
            return sortedItems
        }
        
        // For non-volumed items, just return same type items sorted by title
        return sameTypeItems.sorted { $0.title < $1.title }
    }
    
    private var currentIndex: Int? {
        let index = filteredItems.firstIndex(where: { $0.id == currentItem.id })
        return index
    }
    
    private var hasNextItem: Bool {
        guard let index = currentIndex else { return false }
        return index < filteredItems.count - 1
    }
    
    private var hasPreviousItem: Bool {
        guard let index = currentIndex else { return false }
        return index > 0
    }
    
    private var shouldShowMetadataSection: Bool {
        return currentItem.creator != nil || 
               currentItem.publisher != nil || 
               currentItem.originalPublishDate != nil || 
               currentItem.isbn != nil || 
               currentItem.barcode != nil
    }
    
    private var shouldShowLocationSection: Bool {
        return currentItem.locationId != nil
    }
    
    private var shouldShowSeriesSection: Bool {
        return currentItem.series != nil
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    ZStack(alignment: .bottomTrailing) {
                        VStack {
                            if currentItem.imageSource == .custom, let imageData = currentItem.customImageData {
                                Image(uiImage: UIImage(data: imageData)!)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: dragOffset.width > 0 ? .trailing : .leading),
                                        removal: .move(edge: dragOffset.width > 0 ? .leading : .trailing)
                                    ))
                            } else if let url = thumbnailURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                    case .failure:
                                        Image(systemName: "photo")
                                            .imageScale(.large)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: dragOffset.width > 0 ? .trailing : .leading),
                                    removal: .move(edge: dragOffset.width > 0 ? .leading : .trailing)
                                ))
                                .frame(height: 200)
                            } else {
                                Image(systemName: "photo")
                                    .imageScale(.large)
                                    .frame(height: 200)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button {
                            showingImagePicker = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .symbolRenderingMode(.multicolor)
                                .font(.title)
                                .padding(8)
                        }
                    }
                    Spacer()
                }
                .listRowInsets(EdgeInsets())
                
                // Navigation buttons to previous/next items in filtered list
                if filteredItems.count > 1 {
                    HStack {
                        Button {
                            navigateToPreviousItem()
                        } label: {
                            Label("Previous", systemImage: "chevron.left")
                                .labelStyle(.iconOnly)
                                .font(.title3)
                        }
                        .disabled(!hasPreviousItem)
                        .opacity(hasPreviousItem ? 1.0 : 0.3)
                        
                        Spacer()
                        
                        if let index = currentIndex, filteredItems.count > 0 {
                            Text("\(index + 1) of \(filteredItems.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            navigateToNextItem()
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                                .labelStyle(.iconOnly)
                                .font(.title3)
                        }
                        .disabled(!hasNextItem)
                        .opacity(hasNextItem ? 1.0 : 0.3)
                    }
                }
            }
            
            // Use our ItemDetailComponent for consistent detail sections
            Section("Basic Information") {
                ItemDetailComponent(
                    item: currentItem,
                    sections: [.basic],
                    enableNavigation: true
                )
            }
            
            if shouldShowMetadataSection {
                Section("Metadata") {
                    ItemDetailComponent(
                        item: currentItem,
                        sections: [.metadata],
                        enableNavigation: true
                    )
                }
            }
            
            if shouldShowLocationSection {
                Section("Location") {
                    ItemDetailComponent(
                        item: currentItem,
                        sections: [.location],
                        enableNavigation: true
                    )
                }
            }
            
            if shouldShowSeriesSection {
                Section("Series Information") {
                    ItemDetailComponent(
                        item: currentItem,
                        sections: [.series],
                        enableNavigation: true
                    )
                }
            }
            
            if let synopsis = currentItem.synopsis, !synopsis.isEmpty {
                Section("Synopsis") {
                    Text(synopsis)
                        .font(.body)
                }
            }
        }
        .environment(\.editMode, .constant(.inactive))
        .navigationTitle(currentItem.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    guard !isTransitioning else { return }
                    // Make drag follow finger more closely
                    withAnimation(.interactiveSpring()) {
                        dragOffset = gesture.translation
                    }
                }
                .onEnded { gesture in
                    guard !isTransitioning else { return }
                    // Reset drag offset
                    dragOffset = .zero
                    
                    // If the drag was significant enough, navigate to the next/previous item
                    let threshold: CGFloat = 50 // Minimum drag distance to trigger navigation
                    if gesture.translation.width > threshold && hasPreviousItem {
                        navigateToPreviousItem()
                    } else if gesture.translation.width < -threshold && hasNextItem {
                        navigateToNextItem()
                    }
                }
        )
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker { newImage in
                if let data = newImage.jpegData(compressionQuality: 0.8) {
                    var updatedItem = currentItem
                    updatedItem.customImageData = data
                    updatedItem.imageSource = .custom
                    
                    do {
                        currentItem = try inventoryViewModel.updateItem(updatedItem)
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: {
            // When the edit sheet is dismissed, refresh the current item with the latest data
            if let updatedItem = inventoryViewModel.items.first(where: { $0.id == currentItem.id }) {
                currentItem = updatedItem
            }
        }) {
            NavigationStack {
                EditItemView(item: currentItem)
                    .environmentObject(inventoryViewModel)
                    .environmentObject(locationManager)
            }
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteItem()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this item? This action cannot be undone.")
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        if let existingURL = currentItem.thumbnailURL {
            // Create a more robust URL by ensuring it uses HTTPS
            if existingURL.absoluteString.hasPrefix("http://") {
                let secureString = existingURL.absoluteString.replacingOccurrences(of: "http://", with: "https://")
                thumbnailURL = URL(string: secureString)
            } else {
                thumbnailURL = existingURL
            }
            
            print("Loading thumbnail from URL: \(thumbnailURL?.absoluteString ?? "nil")")
        } else {
            thumbnailURL = nil
            print("No thumbnail URL available")
        }
    }
    
    private func navigateToNextItem() {
        guard let index = currentIndex, hasNextItem else { return }
        isTransitioning = true
        let nextItem = filteredItems[index + 1]
        
        // Animate out current item, then update
        withAnimation(.easeInOut(duration: 0.3)) {
            dragOffset.width = -UIScreen.main.bounds.width
        }
        
        // After animation, update to the next item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentItem = nextItem
            loadThumbnail()
            
            // Prepare for entry animation
            dragOffset.width = UIScreen.main.bounds.width
            
            // Animate back in
            withAnimation(.easeInOut(duration: 0.3)) {
                dragOffset = .zero
            }
            
            // Reset transition flag
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTransitioning = false
            }
        }
    }
    
    private func navigateToPreviousItem() {
        guard let index = currentIndex, hasPreviousItem else { return }
        isTransitioning = true
        let previousItem = filteredItems[index - 1]
        
        // Animate out current item, then update
        withAnimation(.easeInOut(duration: 0.3)) {
            dragOffset.width = UIScreen.main.bounds.width
        }
        
        // After animation, update to the previous item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentItem = previousItem
            loadThumbnail()
            
            // Prepare for entry animation
            dragOffset.width = -UIScreen.main.bounds.width
            
            // Animate back in
            withAnimation(.easeInOut(duration: 0.3)) {
                dragOffset = .zero
            }
            
            // Reset transition flag
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTransitioning = false
            }
        }
    }
    
    private func deleteItem() {
        do {
            try inventoryViewModel.deleteItem(currentItem)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    let locationManager = LocationManager()
    let inventoryViewModel = InventoryViewModel(locationManager: locationManager)
    
    let sampleItem = InventoryItem(
        title: "Sample Item",
        type: .books
    )
    
    return NavigationView {
        ItemDetailView(item: sampleItem)
            .environmentObject(locationManager)
            .environmentObject(inventoryViewModel)
            .environmentObject(NavigationCoordinator())
    }
} 

