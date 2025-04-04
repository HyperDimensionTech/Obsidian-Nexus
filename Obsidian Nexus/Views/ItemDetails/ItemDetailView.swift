import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject var inventoryViewModel: InventoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var thumbnailService = ThumbnailService()
    @StateObject private var googleBooksService = GoogleBooksService()
    
    @State private var thumbnailURL: URL?
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingImagePicker = false
    @State private var dragOffset = CGSize.zero
    @State private var currentItem: InventoryItem
    @State private var isTransitioning = false
    @State private var swipeDirection: SwipeDirection = .none
    
    // Track swipe animation progress
    enum SwipeDirection {
        case left, right, none
    }
    
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
        GeometryReader { geometry in
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
            .offset(x: dragOffset.width)
            .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        guard !isTransitioning else { return }
                        // Only allow horizontal swiping when there are items to navigate to
                        if (gesture.translation.width > 0 && hasPreviousItem) || 
                           (gesture.translation.width < 0 && hasNextItem) {
                            // Apply some resistance at the edges
                            let elasticity: CGFloat = 0.7
                            dragOffset = CGSize(width: gesture.translation.width * elasticity, height: 0)
                        }
                    }
                    .onEnded { gesture in
                        guard !isTransitioning else { return }
                        
                        let screenWidth = geometry.size.width
                        let threshold: CGFloat = screenWidth * 0.25 // 25% of screen width
                        
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                            if dragOffset.width > threshold && hasPreviousItem {
                                // Swiped right past threshold - go to previous
                                isTransitioning = true
                                swipeDirection = .right
                                dragOffset = CGSize(width: screenWidth, height: 0)
                                
                                // Transition after animation completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    navigateToPreviousItem()
                                    // Reset for next transition with direction-appropriate starting point
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                        dragOffset = CGSize(width: -screenWidth, height: 0)
                                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                            dragOffset = .zero
                                        }
                                        // Re-enable gestures after animation completes
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            isTransitioning = false
                                            swipeDirection = .none
                                        }
                                    }
                                }
                            } else if dragOffset.width < -threshold && hasNextItem {
                                // Swiped left past threshold - go to next
                                isTransitioning = true
                                swipeDirection = .left
                                dragOffset = CGSize(width: -screenWidth, height: 0)
                                
                                // Transition after animation completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    navigateToNextItem()
                                    // Reset for next transition with direction-appropriate starting point
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                        dragOffset = CGSize(width: screenWidth, height: 0)
                                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                            dragOffset = .zero
                                        }
                                        // Re-enable gestures after animation completes
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            isTransitioning = false
                                            swipeDirection = .none
                                        }
                                    }
                                }
                            } else {
                                // Didn't swipe far enough - snap back to center
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .sheet(isPresented: $showingEditSheet) {
                if let updatedItem = inventoryViewModel.items.first(where: { $0.id == currentItem.id }) {
                    NavigationView {
                        EditItemView(item: updatedItem)
                            .environmentObject(inventoryViewModel)
                            .environmentObject(locationManager)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Item", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteItem()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(currentItem.title)?")
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker { image in
                    if let imageData = image.jpegData(compressionQuality: 0.7) {
                        var updatedItem = currentItem
                        updatedItem.customImageData = imageData
                        updatedItem.imageSource = .custom
                        
                        do {
                            try inventoryViewModel.updateItem(updatedItem)
                            currentItem = updatedItem  // Update displayed item
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
            }
            .onAppear {
                // Set up thumbnail when the view appears
                setThumbnail()
            }
        }
    }
    
    // Navigate to the next item
    private func navigateToNextItem() {
        guard let index = currentIndex, index < filteredItems.count - 1 else { return }
        let nextItem = filteredItems[index + 1]
        
        withAnimation {
            currentItem = nextItem
        }
        
        // Reset thumbnail
        setThumbnail()
    }
    
    // Navigate to the previous item
    private func navigateToPreviousItem() {
        guard let index = currentIndex, index > 0 else { return }
        let previousItem = filteredItems[index - 1]
        
        withAnimation {
            currentItem = previousItem
        }
        
        // Reset thumbnail
        setThumbnail()
    }
    
    // Helper to set thumbnail URL
    private func setThumbnail() {
        if let url = currentItem.thumbnailURL {
            thumbnailURL = url
        } else if currentItem.imageSource != .custom {
            // Try to find an appropriate thumbnail based on type and ISBN
            if let isbn = currentItem.isbn {
                // Instead of direct method call, use the fetchByISBN method with completion handler
                googleBooksService.fetchBooks(query: "isbn:\(isbn)") { result in
                    switch result {
                    case .success(let books):
                        if let firstBook = books.first,
                           let thumbnail = firstBook.volumeInfo.imageLinks?.thumbnail,
                           let processedURL = URL(string: thumbnail.replacingOccurrences(of: "http://", with: "https://")) {
                            self.thumbnailURL = processedURL
                        }
                    case .failure:
                        break
                    }
                }
            }
        }
    }
    
    // Delete the current item
    private func deleteItem() {
        do {
            try inventoryViewModel.deleteItem(currentItem)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func dismiss() {
        navigationCoordinator.navigateBack()
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

