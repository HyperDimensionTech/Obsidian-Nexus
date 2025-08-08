import Foundation

/// Errors that can occur during CRDT operations
public enum CRDTError: Error {
    case aggregateNotFound
    case aggregateAlreadyExists
    case eventStorageError(Error)
    case invalidEventData
}

/// Repository that combines CRDT operations with event sourcing
public class CRDTRepository: ObservableObject {
    private let eventStore: EventStore
    private let deviceId: DeviceID
    
    // In-memory CRDT state
    @Published private(set) var inventoryItems: [UUID: CRDTInventoryItem] = [:]
    @Published private(set) var locations: [UUID: CRDTLocation] = [:]
    @Published private(set) var isbnMappings: [String: CRDTISBNMapping] = [:]
    
    // Vector clock for this device
    private var vectorClock: VectorClock = VectorClock()
    
    public init(eventStore: EventStore = EventStore(), deviceId: DeviceID = DeviceID()) {
        self.eventStore = eventStore
        self.deviceId = deviceId
        
        // Load existing state from events
        loadStateFromEvents()
    }
    
    // MARK: - Inventory Item Operations
    
    /// Create a new inventory item
    public func createInventoryItem(
        title: String,
        type: CollectionType,
        series: String? = nil,
        volume: Int? = nil,
        condition: ItemCondition,
        locationId: UUID? = nil,
        notes: String? = nil,
        dateAdded: Date = Date(),
        barcode: String? = nil,
        author: String? = nil,
        publisher: String? = nil,
        isbn: String? = nil,
        price: Price? = nil,
        synopsis: String? = nil,
        thumbnailURL: URL? = nil,
        customImageData: Data? = nil,
        imageSource: InventoryItem.ImageSource = .none,
        // Additional v3 fields
        serialNumber: String? = nil,
        modelNumber: String? = nil,
        character: String? = nil,
        franchise: String? = nil,
        dimensions: String? = nil,
        weight: String? = nil,
        releaseDate: Date? = nil,
        limitedEditionNumber: String? = nil,
        hasOriginalPackaging: Bool? = nil,
        platform: String? = nil,
        developer: String? = nil,
        genre: String? = nil,
        ageRating: String? = nil,
        technicalSpecs: String? = nil,
        warrantyExpiry: Date? = nil
    ) throws -> UUID {
        
        let itemId = UUID()
        vectorClock.increment(for: deviceId)
        
        let event = InventoryItemCreated(
            aggregateId: itemId,
            deviceId: deviceId,
            version: 1,
            title: title,
            type: type.rawValue,
            series: series,
            volume: volume,
            condition: condition.rawValue,
            locationId: locationId,
            notes: notes,
            dateAdded: dateAdded,
            barcode: barcode,
            thumbnailURL: thumbnailURL?.absoluteString,
            author: author,
            publisher: publisher,
            isbn: isbn,
            price: price?.amount,
            priceCurrency: price?.currency.rawValue,
            synopsis: synopsis,
            customImageData: customImageData,
            imageSource: imageSource.rawValue,
            serialNumber: serialNumber,
            modelNumber: modelNumber,
            character: character,
            franchise: franchise,
            dimensions: dimensions,
            weight: weight,
            releaseDate: releaseDate,
            limitedEditionNumber: limitedEditionNumber,
            hasOriginalPackaging: hasOriginalPackaging,
            platform: platform,
            developer: developer,
            genre: genre,
            ageRating: ageRating,
            technicalSpecs: technicalSpecs,
            warrantyExpiry: warrantyExpiry
        )
        
        // Save event
        try eventStore.saveEvent(InventoryItemEvent.created(event))
        
        // Apply to local state
        applyInventoryItemCreated(event)
        
        return itemId
    }
    
    /// Update an inventory item
    public func updateInventoryItem(
        id: UUID,
        updates: [String: Any]
    ) throws {
        
        guard inventoryItems[id] != nil else {
            throw CRDTError.aggregateNotFound
        }
        
        vectorClock.increment(for: deviceId)
        let currentVersion = try eventStore.getCurrentVersion(for: id)
        
        // Convert updates to AnyCodable
        let codableUpdates = updates.compactMapValues { value -> AnyCodable? in
            if let codable = value as? Codable {
                return AnyCodable(codable)
            }
            return nil
        }
        
        let event = InventoryItemUpdated(
            aggregateId: id,
            deviceId: deviceId,
            version: currentVersion + 1,
            updatedFields: codableUpdates
        )
        
        // Save event
        try eventStore.saveEvent(InventoryItemEvent.updated(event))
        
        // Apply to local state
        applyInventoryItemUpdated(event)
    }
    
    /// Delete an inventory item (soft delete)
    public func deleteInventoryItem(id: UUID) throws {
        guard inventoryItems[id] != nil else {
            throw CRDTError.aggregateNotFound
        }
        
        vectorClock.increment(for: deviceId)
        let currentVersion = try eventStore.getCurrentVersion(for: id)
        
        let event = InventoryItemDeleted(
            aggregateId: id,
            deviceId: deviceId,
            version: currentVersion + 1
        )
        
        // Save event
        try eventStore.saveEvent(InventoryItemEvent.deleted(event))
        
        // Apply to local state
        applyInventoryItemDeleted(event)
    }
    
    /// Change inventory item location
    public func changeItemLocation(id: UUID, newLocationId: UUID?) throws {
        guard let currentItem = inventoryItems[id] else {
            throw CRDTError.aggregateNotFound
        }
        
        vectorClock.increment(for: deviceId)
        let currentVersion = try eventStore.getCurrentVersion(for: id)
        
        let event = InventoryItemLocationChanged(
            aggregateId: id,
            deviceId: deviceId,
            version: currentVersion + 1,
            previousLocationId: currentItem.locationId?.value,
            newLocationId: newLocationId
        )
        
        // Save event
        try eventStore.saveEvent(InventoryItemEvent.locationChanged(event))
        
        // Apply to local state
        applyInventoryItemLocationChanged(event)
    }
    
    // MARK: - Location Operations
    
    /// Create a new location
    public func createLocation(
        name: String,
        type: StorageLocation.LocationType,
        parentId: UUID? = nil
    ) throws -> UUID {
        
        let locationId = UUID()
        vectorClock.increment(for: deviceId)
        
        let event = LocationCreated(
            aggregateId: locationId,
            deviceId: deviceId,
            version: 1,
            name: name,
            type: type.rawValue,
            parentId: parentId
        )
        
        // Save event
        try eventStore.saveEvent(LocationEvent.created(event))
        
        // Apply to local state
        applyLocationCreated(event)
        
        return locationId
    }
    
    /// Update a location
    public func updateLocation(
        id: UUID,
        updates: [String: Any]
    ) throws {
        
        guard locations[id] != nil else {
            throw CRDTError.aggregateNotFound
        }
        
        vectorClock.increment(for: deviceId)
        let currentVersion = try eventStore.getCurrentVersion(for: id)
        
        // Convert updates to AnyCodable
        let codableUpdates = updates.compactMapValues { value -> AnyCodable? in
            if let codable = value as? Codable {
                return AnyCodable(codable)
            }
            return nil
        }
        
        let event = LocationUpdated(
            aggregateId: id,
            deviceId: deviceId,
            version: currentVersion + 1,
            updatedFields: codableUpdates
        )
        
        // Save event
        try eventStore.saveEvent(LocationEvent.updated(event))
        
        // Apply to local state
        applyLocationUpdated(event)
    }
    
    /// Delete a location
    public func deleteLocation(id: UUID) throws {
        guard locations[id] != nil else {
            throw CRDTError.aggregateNotFound
        }
        
        vectorClock.increment(for: deviceId)
        let currentVersion = try eventStore.getCurrentVersion(for: id)
        
        let event = LocationDeleted(
            aggregateId: id,
            deviceId: deviceId,
            version: currentVersion + 1
        )
        
        // Save event
        try eventStore.saveEvent(LocationEvent.deleted(event))
        
        // Apply to local state
        applyLocationDeleted(event)
    }
    
    // MARK: - Synchronization
    
    /// Sync with events from another device
    public func syncEvents(_ events: [StoredEvent]) throws {
        // For now, we'll reconstruct the events from stored events
        // In a full implementation, you'd have proper event type dispatch
        
        // Replay events to update local state
        for event in events {
            try applyStoredEvent(event)
        }
    }
    
    /// Get events since a timestamp for sync
    public func getEventsSince(_ timestamp: Date) throws -> [StoredEvent] {
        return try eventStore.getEventsSince(timestamp)
    }
    
    // MARK: - Private Event Application
    
    private func loadStateFromEvents() {
        print("🔹 CRDT 🔹 Loading state from events...")
        
        do {
            let events = try eventStore.getAllEvents()
            print("🔹 CRDT 🔹 Found \(events.count) events to process")
            
            for event in events {
                try applyStoredEvent(event)
            }
            
            print("🔹 CRDT 🔹 Loaded \(inventoryItems.count) inventory items, \(locations.count) locations, and \(isbnMappings.count) ISBN mappings")
            
        } catch {
            print("🔹 CRDT 🔹 Error loading state from events: \(error)")
        }
    }
    
    private func applyStoredEvent(_ storedEvent: StoredEvent) throws {
        print("🔹 CRDT 🔹 Applying event: \(storedEvent.eventType)")
        
        switch storedEvent.eventType {
        case "InventoryItemEvent":
            // This is a wrapper event - we need to decode the inner event
            if let eventData = try? JSONDecoder().decode(InventoryItemEvent.self, from: storedEvent.eventData) {
                try applyInventoryItemEvent(eventData)
            }
        case "LocationEvent":
            // This is a wrapper event - we need to decode the inner event
            if let eventData = try? JSONDecoder().decode(LocationEvent.self, from: storedEvent.eventData) {
                try applyLocationEvent(eventData)
            }
        case "ISBNMappingEvent":
            // This is a wrapper event - we need to decode the inner event
            if let eventData = try? JSONDecoder().decode(ISBNMappingEvent.self, from: storedEvent.eventData) {
                try applyISBNMappingEvent(eventData)
            }
        default:
            // Handle individual event types directly
            if storedEvent.eventType.contains("InventoryItemCreated") {
                if let event = try? storedEvent.decode(as: InventoryItemCreated.self) {
                    applyInventoryItemCreated(event)
                }
            } else if storedEvent.eventType.contains("InventoryItemUpdated") {
                if let event = try? storedEvent.decode(as: InventoryItemUpdated.self) {
                    applyInventoryItemUpdated(event)
                }
            } else if storedEvent.eventType.contains("InventoryItemDeleted") {
                if let event = try? storedEvent.decode(as: InventoryItemDeleted.self) {
                    applyInventoryItemDeleted(event)
                }
            } else if storedEvent.eventType.contains("InventoryItemLocationChanged") {
                if let event = try? storedEvent.decode(as: InventoryItemLocationChanged.self) {
                    applyInventoryItemLocationChanged(event)
                }
            } else if storedEvent.eventType.contains("LocationCreated") {
                if let event = try? storedEvent.decode(as: LocationCreated.self) {
                    applyLocationCreated(event)
                }
            } else if storedEvent.eventType.contains("LocationUpdated") {
                if let event = try? storedEvent.decode(as: LocationUpdated.self) {
                    applyLocationUpdated(event)
                }
            } else if storedEvent.eventType.contains("LocationDeleted") {
                if let event = try? storedEvent.decode(as: LocationDeleted.self) {
                    applyLocationDeleted(event)
                }
            } else if storedEvent.eventType.contains("ISBNMappingCreated") {
                if let event = try? storedEvent.decode(as: ISBNMappingCreated.self) {
                    applyISBNMappingCreated(event)
                }
            } else if storedEvent.eventType.contains("ISBNMappingDeleted") {
                if let event = try? storedEvent.decode(as: ISBNMappingDeleted.self) {
                    applyISBNMappingDeleted(event)
                }
            }
        }
    }
    
    private func applyInventoryItemEvent(_ event: InventoryItemEvent) throws {
        switch event {
        case .created(let createdEvent):
            applyInventoryItemCreated(createdEvent)
        case .updated(let updatedEvent):
            applyInventoryItemUpdated(updatedEvent)
        case .deleted(let deletedEvent):
            applyInventoryItemDeleted(deletedEvent)
        case .restored(let restoredEvent):
            applyInventoryItemRestored(restoredEvent)
        case .locationChanged(let locationChangedEvent):
            applyInventoryItemLocationChanged(locationChangedEvent)
        }
    }
    
    private func applyLocationEvent(_ event: LocationEvent) throws {
        switch event {
        case .created(let createdEvent):
            applyLocationCreated(createdEvent)
        case .updated(let updatedEvent):
            applyLocationUpdated(updatedEvent)
        case .deleted(let deletedEvent):
            applyLocationDeleted(deletedEvent)
        case .parentChanged(let parentChangedEvent):
            applyLocationParentChanged(parentChangedEvent)
        }
    }
    
    private func applyISBNMappingEvent(_ event: ISBNMappingEvent) throws {
        switch event {
        case .created(let createdEvent):
            applyISBNMappingCreated(createdEvent)
        case .deleted(let deletedEvent):
            applyISBNMappingDeleted(deletedEvent)
        }
    }
    
    private func applyInventoryItemCreated(_ event: InventoryItemCreated) {
        let item = CRDTInventoryItem(
            id: event.aggregateId,
            title: LWWRegister(value: event.title, timestamp: vectorClock, deviceId: deviceId),
            type: LWWRegister(value: CollectionType(rawValue: event.type) ?? .books, timestamp: vectorClock, deviceId: deviceId),
            series: event.series.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            volume: event.volume.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            condition: LWWRegister(value: ItemCondition(rawValue: event.condition) ?? .good, timestamp: vectorClock, deviceId: deviceId),
            locationId: event.locationId.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            notes: event.notes.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            dateAdded: LWWRegister(value: event.dateAdded, timestamp: vectorClock, deviceId: deviceId),
            barcode: event.barcode.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            // Publishing/Creation info
            author: event.author.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            publisher: event.publisher.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            isbn: event.isbn.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            synopsis: event.synopsis.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            // Image-related fields
            thumbnailURL: event.thumbnailURL.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            customImageData: event.customImageData.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            imageSource: LWWRegister(value: InventoryItem.ImageSource(rawValue: event.imageSource) ?? .none, timestamp: vectorClock, deviceId: deviceId),
            // Additional v3 fields
            serialNumber: event.serialNumber.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            modelNumber: event.modelNumber.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            character: event.character.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            franchise: event.franchise.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            dimensions: event.dimensions.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            weight: event.weight.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            releaseDate: event.releaseDate.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            limitedEditionNumber: event.limitedEditionNumber.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            hasOriginalPackaging: event.hasOriginalPackaging.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            platform: event.platform.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            developer: event.developer.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            genre: event.genre.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            ageRating: event.ageRating.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            technicalSpecs: event.technicalSpecs.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            warrantyExpiry: event.warrantyExpiry.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            vectorClock: vectorClock,
            deviceId: deviceId,
            isDeleted: false
        )
        
        inventoryItems[event.aggregateId] = item
        print("🔹 CRDT 🔹 Created inventory item: \(event.title)")
    }
    
    private func applyInventoryItemUpdated(_ event: InventoryItemUpdated) {
        guard var item = inventoryItems[event.aggregateId] else { return }
        
        for (key, value) in event.updatedFields {
            switch key {
            case "title":
                if let titleValue = value.value as? String {
                    item.title = item.title.updated(with: titleValue, deviceId: event.deviceId)
                }
            case "notes":
                if let notesValue = value.value as? String {
                    item.notes = LWWRegister(value: notesValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "condition":
                if let conditionValue = value.value as? String,
                   let condition = ItemCondition(rawValue: conditionValue) {
                    item.condition = item.condition.updated(with: condition, deviceId: event.deviceId)
                }
            case "type":
                if let typeValue = value.value as? String,
                   let type = CollectionType(rawValue: typeValue) {
                    item.type = item.type.updated(with: type, deviceId: event.deviceId)
                }
            case "series":
                if let seriesValue = value.value as? String {
                    item.series = LWWRegister(value: seriesValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "volume":
                if let volumeValue = value.value as? Int {
                    item.volume = LWWRegister(value: volumeValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "locationId":
                if let locationIdString = value.value as? String,
                   let locationId = UUID(uuidString: locationIdString) {
                    item.locationId = LWWRegister(value: locationId, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "dateAdded":
                if let dateAddedValue = value.value as? Date {
                    item.dateAdded = LWWRegister(value: dateAddedValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "barcode":
                if let barcodeValue = value.value as? String {
                    item.barcode = LWWRegister(value: barcodeValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "author":
                if let authorValue = value.value as? String {
                    item.author = LWWRegister(value: authorValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "publisher":
                if let publisherValue = value.value as? String {
                    item.publisher = LWWRegister(value: publisherValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "isbn":
                if let isbnValue = value.value as? String {
                    item.isbn = LWWRegister(value: isbnValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "synopsis":
                if let synopsisValue = value.value as? String {
                    item.synopsis = LWWRegister(value: synopsisValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "thumbnailURL":
                if let thumbnailURLValue = value.value as? String {
                    item.thumbnailURL = LWWRegister(value: thumbnailURLValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "customImageData":
                if let customImageDataValue = value.value as? Data {
                    item.customImageData = LWWRegister(value: customImageDataValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "imageSource":
                if let imageSourceValue = value.value as? String,
                   let imageSource = InventoryItem.ImageSource(rawValue: imageSourceValue) {
                    item.imageSource = LWWRegister(value: imageSource, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "serialNumber":
                if let serialNumberValue = value.value as? String {
                    item.serialNumber = LWWRegister(value: serialNumberValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "modelNumber":
                if let modelNumberValue = value.value as? String {
                    item.modelNumber = LWWRegister(value: modelNumberValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "character":
                if let characterValue = value.value as? String {
                    item.character = LWWRegister(value: characterValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "franchise":
                if let franchiseValue = value.value as? String {
                    item.franchise = LWWRegister(value: franchiseValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "dimensions":
                if let dimensionsValue = value.value as? String {
                    item.dimensions = LWWRegister(value: dimensionsValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "weight":
                if let weightValue = value.value as? String {
                    item.weight = LWWRegister(value: weightValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "releaseDate":
                if let releaseDateValue = value.value as? Date {
                    item.releaseDate = LWWRegister(value: releaseDateValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "limitedEditionNumber":
                if let limitedEditionNumberValue = value.value as? String {
                    item.limitedEditionNumber = LWWRegister(value: limitedEditionNumberValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "hasOriginalPackaging":
                if let hasOriginalPackagingValue = value.value as? Bool {
                    item.hasOriginalPackaging = LWWRegister(value: hasOriginalPackagingValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "platform":
                if let platformValue = value.value as? String {
                    item.platform = LWWRegister(value: platformValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "developer":
                if let developerValue = value.value as? String {
                    item.developer = LWWRegister(value: developerValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "genre":
                if let genreValue = value.value as? String {
                    item.genre = LWWRegister(value: genreValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "ageRating":
                if let ageRatingValue = value.value as? String {
                    item.ageRating = LWWRegister(value: ageRatingValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "technicalSpecs":
                if let technicalSpecsValue = value.value as? String {
                    item.technicalSpecs = LWWRegister(value: technicalSpecsValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            case "warrantyExpiry":
                if let warrantyExpiryValue = value.value as? Date {
                    item.warrantyExpiry = LWWRegister(value: warrantyExpiryValue, timestamp: vectorClock, deviceId: event.deviceId)
                }
            default:
                break
            }
        }
        
        inventoryItems[event.aggregateId] = item
        print("🔹 CRDT 🔹 Updated inventory item: \(event.aggregateId)")
    }
    
    private func applyInventoryItemDeleted(_ event: InventoryItemDeleted) {
        inventoryItems[event.aggregateId]?.isDeleted = true
        print("🔹 CRDT 🔹 Deleted inventory item: \(event.aggregateId)")
    }
    
    private func applyInventoryItemRestored(_ event: InventoryItemRestored) {
        inventoryItems[event.aggregateId]?.isDeleted = false
        print("🔹 CRDT 🔹 Restored inventory item: \(event.aggregateId)")
    }
    
    private func applyInventoryItemLocationChanged(_ event: InventoryItemLocationChanged) {
        guard var item = inventoryItems[event.aggregateId] else { return }
        
        if let newLocationId = event.newLocationId {
            item.locationId = LWWRegister(value: newLocationId, timestamp: vectorClock, deviceId: event.deviceId)
        } else {
            item.locationId = nil
        }
        
        inventoryItems[event.aggregateId] = item
        print("🔹 CRDT 🔹 Changed location for inventory item: \(event.aggregateId)")
    }
    
    private func applyLocationCreated(_ event: LocationCreated) {
        let location = CRDTLocation(
            id: event.aggregateId,
            name: LWWRegister(value: event.name, timestamp: vectorClock, deviceId: deviceId),
            type: LWWRegister(value: StorageLocation.LocationType(rawValue: event.type) ?? .room, timestamp: vectorClock, deviceId: deviceId),
            parentId: event.parentId.map { LWWRegister(value: $0, timestamp: vectorClock, deviceId: deviceId) },
            vectorClock: vectorClock,
            deviceId: deviceId,
            isDeleted: false
        )
        
        locations[event.aggregateId] = location
        print("🔹 CRDT 🔹 Created location: \(event.name)")
    }
    
    private func applyLocationUpdated(_ event: LocationUpdated) {
        guard var location = locations[event.aggregateId] else { return }
        
        for (key, value) in event.updatedFields {
            switch key {
            case "name":
                if let nameValue = value.value as? String {
                    location.name = location.name.updated(with: nameValue, deviceId: event.deviceId)
                }
            case "type":
                if let typeValue = value.value as? String,
                   let type = StorageLocation.LocationType(rawValue: typeValue) {
                    location.type = location.type.updated(with: type, deviceId: event.deviceId)
                }
            case "parentId":
                if let parentIdString = value.value as? String,
                   let parentId = UUID(uuidString: parentIdString) {
                    location.parentId = LWWRegister(value: parentId, timestamp: vectorClock, deviceId: event.deviceId)
                }
            default:
                break
            }
        }
        
        locations[event.aggregateId] = location
        print("🔹 CRDT 🔹 Updated location: \(event.aggregateId)")
    }
    
    private func applyLocationDeleted(_ event: LocationDeleted) {
        locations[event.aggregateId]?.isDeleted = true
        print("🔹 CRDT 🔹 Deleted location: \(event.aggregateId)")
    }
    
    private func applyLocationParentChanged(_ event: LocationParentChanged) {
        guard var location = locations[event.aggregateId] else { return }
        
        if let newParentId = event.newParentId {
            location.parentId = LWWRegister(value: newParentId, timestamp: vectorClock, deviceId: event.deviceId)
        } else {
            location.parentId = nil
        }
        
        locations[event.aggregateId] = location
        print("🔹 CRDT 🔹 Changed parent for location: \(event.aggregateId)")
    }
    
    // MARK: - ISBN Mapping Operations
    
    /// Create a new ISBN mapping
    public func createISBNMapping(
        incorrectISBN: String,
        correctGoogleBooksID: String,
        title: String,
        isReprint: Bool = true,
        dateAdded: Date = Date()
    ) throws {
        // Check if mapping already exists
        if isbnMappings[incorrectISBN] != nil {
            throw CRDTError.aggregateAlreadyExists
        }
        
        vectorClock.increment(for: deviceId)
        
        // Create a UUID for the mapping (even though we use ISBN as key, we need UUID for aggregateId)
        let mappingId = UUID()
        
        let event = ISBNMappingCreated(
            aggregateId: mappingId,
            deviceId: deviceId,
            version: 1,
            incorrectISBN: incorrectISBN,
            correctGoogleBooksID: correctGoogleBooksID,
            title: title,
            isReprint: isReprint,
            dateAdded: dateAdded
        )
        
        // Save event
        try eventStore.saveEvent(ISBNMappingEvent.created(event))
        
        // Apply to local state
        applyISBNMappingCreated(event)
    }
    
    /// Delete an ISBN mapping
    public func deleteISBNMapping(incorrectISBN: String) throws {
        guard isbnMappings[incorrectISBN] != nil else {
            throw CRDTError.aggregateNotFound
        }
        
        vectorClock.increment(for: deviceId)
        
        // Use a UUID for the aggregateId (event sourcing requirement)
        let mappingId = UUID()
        
        let event = ISBNMappingDeleted(
            aggregateId: mappingId,
            deviceId: deviceId,
            version: 1,
            incorrectISBN: incorrectISBN
        )
        
        // Save event
        try eventStore.saveEvent(ISBNMappingEvent.deleted(event))
        
        // Apply to local state
        applyISBNMappingDeleted(event)
    }
    
    /// Get all non-deleted ISBN mappings
    public func getISBNMappings() -> [ISBNMapping] {
        return isbnMappings.values.compactMap { crdtMapping in
            guard !crdtMapping.isDeleted else { return nil }
            return crdtMapping.toDomainModel()
        }
    }
    
    /// Get a specific ISBN mapping
    public func getISBNMapping(for isbn: String) -> ISBNMapping? {
        guard let crdtMapping = isbnMappings[isbn], !crdtMapping.isDeleted else { return nil }
        return crdtMapping.toDomainModel()
    }
    
    // MARK: - Private ISBN Mapping Event Application
    
    private func applyISBNMappingCreated(_ event: ISBNMappingCreated) {
        let mapping = CRDTISBNMapping(
            incorrectISBN: event.incorrectISBN,
            correctGoogleBooksID: event.correctGoogleBooksID,
            title: event.title,
            isReprint: event.isReprint,
            dateAdded: event.dateAdded,
            vectorClock: vectorClock,
            deviceId: deviceId
        )
        
        isbnMappings[event.incorrectISBN] = mapping
        print("🔹 CRDT 🔹 Created ISBN mapping: \(event.incorrectISBN) -> \(event.title)")
    }
    
    private func applyISBNMappingDeleted(_ event: ISBNMappingDeleted) {
        isbnMappings[event.incorrectISBN]?.isDeleted = true
        print("🔹 CRDT 🔹 Deleted ISBN mapping: \(event.incorrectISBN)")
    }
    
    // MARK: - Public Access Methods
    
    /// Get all non-deleted inventory items as regular InventoryItem objects
    internal func getInventoryItems() -> [InventoryItem] {
        return inventoryItems.values.compactMap { crdtItem in
            guard !crdtItem.isDeleted else { return nil }
            return crdtItem.toInventoryItem()
        }
    }
    
    /// Get all non-deleted locations as regular StorageLocation objects
    internal func getStorageLocations() -> [StorageLocation] {
        return locations.values.compactMap { crdtLocation in
            guard !crdtLocation.isDeleted else { return nil }
            return crdtLocation.toStorageLocation()
        }
    }
}

// MARK: - CRDT Entity Types

/// CRDT version of InventoryItem
internal struct CRDTInventoryItem: CRDTReplica {
    public let id: UUID
    public var title: LWWRegister<String>
    public var type: LWWRegister<CollectionType>
    public var series: LWWRegister<String>?
    public var volume: LWWRegister<Int>?
    public var condition: LWWRegister<ItemCondition>
    public var locationId: LWWRegister<UUID>?
    public var notes: LWWRegister<String>?
    public var dateAdded: LWWRegister<Date>
    public var barcode: LWWRegister<String>?
    
    // Publishing/Creation info
    public var author: LWWRegister<String>?
    public var publisher: LWWRegister<String>?
    public var isbn: LWWRegister<String>?
    public var synopsis: LWWRegister<String>?
    
    // Image-related fields
    public var thumbnailURL: LWWRegister<String>?
    public var customImageData: LWWRegister<Data>?
    public var imageSource: LWWRegister<InventoryItem.ImageSource>
    
    // Additional v3 fields
    public var serialNumber: LWWRegister<String>?
    public var modelNumber: LWWRegister<String>?
    public var character: LWWRegister<String>?
    public var franchise: LWWRegister<String>?
    public var dimensions: LWWRegister<String>?
    public var weight: LWWRegister<String>?
    public var releaseDate: LWWRegister<Date>?
    public var limitedEditionNumber: LWWRegister<String>?
    public var hasOriginalPackaging: LWWRegister<Bool>?
    public var platform: LWWRegister<String>?
    public var developer: LWWRegister<String>?
    public var genre: LWWRegister<String>?
    public var ageRating: LWWRegister<String>?
    public var technicalSpecs: LWWRegister<String>?
    public var warrantyExpiry: LWWRegister<Date>?
    
    public var vectorClock: VectorClock
    public var deviceId: DeviceID
    public var isDeleted: Bool = false
    
    public mutating func merge(with other: CRDTInventoryItem) {
        title = title.merged(with: other.title)
        type = type.merged(with: other.type)
        condition = condition.merged(with: other.condition)
        imageSource = imageSource.merged(with: other.imageSource)
        
        if let otherSeries = other.series {
            series = series?.merged(with: otherSeries) ?? otherSeries
        }
        
        if let otherVolume = other.volume {
            volume = volume?.merged(with: otherVolume) ?? otherVolume
        }
        
        if let otherLocationId = other.locationId {
            locationId = locationId?.merged(with: otherLocationId) ?? otherLocationId
        }
        
        if let otherNotes = other.notes {
            notes = notes?.merged(with: otherNotes) ?? otherNotes
        }
        
                 dateAdded = dateAdded.merged(with: other.dateAdded)
        
        if let otherBarcode = other.barcode {
            barcode = barcode?.merged(with: otherBarcode) ?? otherBarcode
        }
        
        if let otherAuthor = other.author {
            author = author?.merged(with: otherAuthor) ?? otherAuthor
        }
        
        if let otherPublisher = other.publisher {
            publisher = publisher?.merged(with: otherPublisher) ?? otherPublisher
        }
        
        if let otherIsbn = other.isbn {
            isbn = isbn?.merged(with: otherIsbn) ?? otherIsbn
        }
        
        if let otherSynopsis = other.synopsis {
            synopsis = synopsis?.merged(with: otherSynopsis) ?? otherSynopsis
        }
        
        if let otherThumbnailURL = other.thumbnailURL {
            thumbnailURL = thumbnailURL?.merged(with: otherThumbnailURL) ?? otherThumbnailURL
        }
        
        if let otherCustomImageData = other.customImageData {
            customImageData = customImageData?.merged(with: otherCustomImageData) ?? otherCustomImageData
        }
        
        if let otherSerialNumber = other.serialNumber {
            serialNumber = serialNumber?.merged(with: otherSerialNumber) ?? otherSerialNumber
        }
        
        if let otherModelNumber = other.modelNumber {
            modelNumber = modelNumber?.merged(with: otherModelNumber) ?? otherModelNumber
        }
        
        if let otherCharacter = other.character {
            character = character?.merged(with: otherCharacter) ?? otherCharacter
        }
        
        if let otherFranchise = other.franchise {
            franchise = franchise?.merged(with: otherFranchise) ?? otherFranchise
        }
        
        if let otherDimensions = other.dimensions {
            dimensions = dimensions?.merged(with: otherDimensions) ?? otherDimensions
        }
        
        if let otherWeight = other.weight {
            weight = weight?.merged(with: otherWeight) ?? otherWeight
        }
        
        if let otherReleaseDate = other.releaseDate {
            releaseDate = releaseDate?.merged(with: otherReleaseDate) ?? otherReleaseDate
        }
        
        if let otherLimitedEditionNumber = other.limitedEditionNumber {
            limitedEditionNumber = limitedEditionNumber?.merged(with: otherLimitedEditionNumber) ?? otherLimitedEditionNumber
        }
        
        if let otherHasOriginalPackaging = other.hasOriginalPackaging {
            hasOriginalPackaging = hasOriginalPackaging?.merged(with: otherHasOriginalPackaging) ?? otherHasOriginalPackaging
        }
        
        if let otherPlatform = other.platform {
            platform = platform?.merged(with: otherPlatform) ?? otherPlatform
        }
        
        if let otherDeveloper = other.developer {
            developer = developer?.merged(with: otherDeveloper) ?? otherDeveloper
        }
        
        if let otherGenre = other.genre {
            genre = genre?.merged(with: otherGenre) ?? otherGenre
        }
        
        if let otherAgeRating = other.ageRating {
            ageRating = ageRating?.merged(with: otherAgeRating) ?? otherAgeRating
        }
        
        if let otherTechnicalSpecs = other.technicalSpecs {
            technicalSpecs = technicalSpecs?.merged(with: otherTechnicalSpecs) ?? otherTechnicalSpecs
        }
        
        if let otherWarrantyExpiry = other.warrantyExpiry {
            warrantyExpiry = warrantyExpiry?.merged(with: otherWarrantyExpiry) ?? otherWarrantyExpiry
        }
        
        vectorClock = vectorClock.merged(with: other.vectorClock)
        isDeleted = isDeleted || other.isDeleted
    }
    
    public mutating func apply(operation: CRDTOperation) {
        // Apply operation to this replica
        operation.apply(to: &self)
    }
    
    /// Convert CRDT item to regular InventoryItem
    internal func toInventoryItem() -> InventoryItem {
        return InventoryItem(
            title: title.value,
            type: type.value,
            series: series?.value,
            volume: volume?.value,
            condition: condition.value,
            locationId: locationId?.value,
            notes: notes?.value,
            id: id,
            dateAdded: dateAdded.value,
            barcode: barcode?.value,
            thumbnailURL: thumbnailURL.flatMap { URL(string: $0.value) },
            author: author?.value,
            manufacturer: nil,
            originalPublishDate: nil,
            publisher: publisher?.value,
            isbn: isbn?.value,
            price: nil,
            purchaseDate: nil,
            synopsis: synopsis?.value,
            customImageData: customImageData?.value,
            imageSource: imageSource.value,
            serialNumber: serialNumber?.value,
            modelNumber: modelNumber?.value,
            character: character?.value,
            franchise: franchise?.value,
            dimensions: dimensions?.value,
            weight: weight?.value,
            releaseDate: releaseDate?.value,
            limitedEditionNumber: limitedEditionNumber?.value,
            hasOriginalPackaging: hasOriginalPackaging?.value,
            platform: platform?.value,
            developer: developer?.value,
            genre: genre?.value,
            ageRating: ageRating?.value,
            technicalSpecs: technicalSpecs?.value,
            warrantyExpiry: warrantyExpiry?.value
        )
    }
}

/// CRDT version of StorageLocation
internal struct CRDTLocation: CRDTReplica {
    public let id: UUID
    public var name: LWWRegister<String>
    public var type: LWWRegister<StorageLocation.LocationType>
    public var parentId: LWWRegister<UUID>?
    
    public var vectorClock: VectorClock
    public var deviceId: DeviceID
    public var isDeleted: Bool = false
    
    public mutating func merge(with other: CRDTLocation) {
        name = name.merged(with: other.name)
        type = type.merged(with: other.type)
        
        if let otherParentId = other.parentId {
            parentId = parentId?.merged(with: otherParentId) ?? otherParentId
        }
        
        vectorClock = vectorClock.merged(with: other.vectorClock)
        isDeleted = isDeleted || other.isDeleted
    }
    
    public mutating func apply(operation: CRDTOperation) {
        // Apply operation to this replica
        operation.apply(to: &self)
    }
    
    /// Convert CRDT location to regular StorageLocation
    internal func toStorageLocation() -> StorageLocation {
        return StorageLocation(
            id: id,
            name: name.value,
            type: type.value,
            parentId: parentId?.value
        )
    }
}


