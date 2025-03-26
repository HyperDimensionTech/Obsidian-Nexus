import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
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
    
    private var location: StorageLocation? {
        guard let id = currentItem.locationId else { return nil }
        return locationManager.location(withId: id)
    }
    
    private var filteredItems: [InventoryItem] {
        // First filter by type
        let sameTypeItems = inventoryViewModel.items.filter { $0.type == currentItem.type }
        
        // If this is a volumed series (manga/comics), filter by series and sort by volume
        if let currentSeries = currentItem.series, currentItem.volume != nil {
            print("DEBUG: Current item is part of series '\(currentSeries)' volume \(currentItem.volume ?? 0)")
            
            let seriesItems = sameTypeItems.filter { $0.series == currentSeries }
            let sortedItems = seriesItems.sorted { (item1, item2) in
                guard let vol1 = item1.volume, let vol2 = item2.volume else {
                    return item1.title < item2.title // Fallback to title sort if no volume
                }
                return vol1 < vol2
            }
            
            print("DEBUG: Found \(seriesItems.count) items in series '\(currentSeries)'")
            print("DEBUG: Volumes in order: \(sortedItems.map { $0.volume ?? 0 })")
            
            return sortedItems
        }
        
        // For non-volumed items, just return same type items sorted by title
        return sameTypeItems.sorted { $0.title < $1.title }
    }
    
    private var currentIndex: Int? {
        let index = filteredItems.firstIndex(where: { $0.id == currentItem.id })
        print("DEBUG: Current item index: \(index ?? -1)")
        return index
    }
    
    private var hasNextItem: Bool {
        guard let index = currentIndex else { return false }
        let hasNext = index < filteredItems.count - 1
        
        if let currentSeries = currentItem.series, let currentVolume = currentItem.volume {
            let nextItem = hasNext ? filteredItems[index + 1] : nil
            print("DEBUG: Next item check for series '\(currentSeries)' - Current: Vol \(currentVolume), Next: Vol \(nextItem?.volume ?? -1)")
        }
        
        return hasNext
    }
    
    private var hasPreviousItem: Bool {
        guard let index = currentIndex else { return false }
        let hasPrev = index > 0
        
        if let currentSeries = currentItem.series, let currentVolume = currentItem.volume {
            let prevItem = hasPrev ? filteredItems[index - 1] : nil
            print("DEBUG: Previous item check for series '\(currentSeries)' - Current: Vol \(currentVolume), Previous: Vol \(prevItem?.volume ?? -1)")
        }
        
        return hasPrev
    }
    
    private func switchToItem(_ newItem: InventoryItem) {
        isTransitioning = true
        thumbnailURL = nil // Clear the current thumbnail immediately
        
        // Use a quicker, more immediate animation
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
            currentItem = newItem
            dragOffset = .zero
        }
        
        // Load the new thumbnail with minimal delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            loadThumbnail()
            isTransitioning = false
        }
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
                                            .frame(height: 200)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(height: 200)
                                            .transition(.asymmetric(
                                                insertion: .move(edge: dragOffset.width > 0 ? .trailing : .leading),
                                                removal: .move(edge: dragOffset.width > 0 ? .leading : .trailing)
                                            ))
                                    case .failure(_):
                                        Image(systemName: "book")
                                            .font(.system(size: 100))
                                            .foregroundColor(.gray)
                                            .frame(height: 200)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Image(systemName: "book")
                                    .font(.system(size: 100))
                                    .foregroundColor(.gray)
                                    .frame(height: 200)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: dragOffset.width > 0 ? .trailing : .leading),
                                        removal: .move(edge: dragOffset.width > 0 ? .leading : .trailing)
                                    ))
                            }
                        }
                        .animation(.easeInOut(duration: 0.15), value: thumbnailURL)
                        .animation(.easeInOut(duration: 0.15), value: currentItem.imageSource)
                        .onTapGesture {
                            showingImagePicker = true
                        }
                        
                        Button {
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                                .background(Color(UIColor.systemBackground))
                                .clipShape(Circle())
                                .shadow(radius: 1)
                                .offset(x: 70, y: -5)
                        }
                        .zIndex(1)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                    Spacer()
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            Section("Basic Details") {
                DetailRow(label: "Name", value: currentItem.title)
                if let creator = currentItem.creator {
                    DetailRow(label: currentItem.type.isLiterature ? "Author" : "Manufacturer", 
                             value: creator)
                }
                DetailRow(label: "Type", value: currentItem.type.name)
                DetailRow(label: "Condition", value: currentItem.condition.rawValue)
                
                if let date = currentItem.originalPublishDate {
                    DetailRow(label: "Original Publish Date", 
                            value: date.formatted(date: .long, time: .omitted))
                }
            }
            
            Section("Purchase Information") {
                if let price = currentItem.price {
                    DetailRow(label: "Price", value: price.convertedToDefaultCurrency().formatted())
                }
                if let purchaseDate = currentItem.purchaseDate {
                    DetailRow(label: "Purchase Date", 
                            value: purchaseDate.formatted(date: .long, time: .omitted))
                }
                if let locationId = currentItem.locationId {
                    DetailRow(
                        label: "Location", 
                        value: locationManager.breadcrumbPath(for: locationId)
                    )
                }
            }
            
            if let synopsis = currentItem.synopsis {
                Section("Details") {
                    Text(synopsis)
                        .font(.body)
                }
            }
            
            // Keep literature-specific section for additional details
            if currentItem.type.isLiterature {
                Section("Additional Details") {
                    if let publisher = currentItem.publisher {
                        DetailRow(label: "Publisher", value: publisher)
                    }
                    if let isbn = currentItem.isbn {
                        DetailRow(label: "ISBN", value: isbn)
                    }
                }
            }
        }
        .navigationTitle(currentItem.title)
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
                    let threshold: CGFloat = 50
                    let dragX = gesture.translation.width
                    let velocity = gesture.predictedEndTranslation.width - gesture.translation.width
                    
                    // Make swipe more responsive to quick flicks
                    let shouldTrigger = abs(dragX) > threshold || abs(velocity) > 200
                    
                    if dragX > 0 && hasPreviousItem && shouldTrigger {
                        if let index = currentIndex {
                            let previousItem = filteredItems[index - 1]
                            switchToItem(previousItem)
                        }
                    } else if dragX < 0 && hasNextItem && shouldTrigger {
                        if let index = currentIndex {
                            let nextItem = filteredItems[index + 1]
                            switchToItem(nextItem)
                        }
                    } else {
                        // Snappier reset animation
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .offset(x: dragOffset.width)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                    Button("Delete", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
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
            print("DEBUG: Loading thumbnail URL: \(existingURL)")
            thumbnailURL = existingURL
        } else {
            print("DEBUG: No thumbnail URL available for current item")
            thumbnailURL = nil
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
    }
} 
