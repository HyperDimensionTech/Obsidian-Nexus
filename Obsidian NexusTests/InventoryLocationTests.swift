import XCTest
@testable import Obsidian_Nexus

final class InventoryLocationTests: XCTestCase {
    var locationManager: LocationManager!
    var inventoryViewModel: InventoryViewModel!
    
    override func setUp() {
        super.setUp()
        locationManager = LocationManager()
        inventoryViewModel = InventoryViewModel(locationManager: locationManager)
    }
    
    override func tearDown() {
        locationManager = nil
        inventoryViewModel = nil
        super.tearDown()
    }
    
    // MARK: - Location Assignment Tests
    
    func testAssignValidLocation() throws {
        // Create a location
        let room = StorageLocation(name: "Living Room", type: .room)
        try locationManager.addLocation(room)
        
        // Create and add an item
        var item = InventoryItem(
            title: "Test Book",
            type: .books
        )
        try inventoryViewModel.addItem(item)
        
        // Update item with new location
        item.locationId = room.id
        XCTAssertNoThrow(try inventoryViewModel.updateItem(item))
        
        // Verify the update
        let updatedItem = inventoryViewModel.items.first
        XCTAssertEqual(updatedItem?.locationId, room.id)
    }
    
    func testAssignInvalidLocation() throws {
        // Create an item
        var item = InventoryItem(
            title: "Test Book",
            type: .books
        )
        try inventoryViewModel.addItem(item)
        
        // Attempt to assign non-existent location
        item.locationId = UUID()
        XCTAssertThrowsError(try inventoryViewModel.updateItem(item)) { error in
            XCTAssertEqual(error as? InventoryError, .invalidLocation)
        }
    }
    
    func testRemoveLocation() throws {
        // Create a location
        let room = StorageLocation(name: "Living Room", type: .room)
        try locationManager.addLocation(room)
        
        // Create item with location
        let item = InventoryItem(
            title: "Test Book",
            type: .books,
            locationId: room.id
        )
        try inventoryViewModel.addItem(item)
        
        // Update item to remove location
        var updatedItem = item
        updatedItem.locationId = nil
        XCTAssertNoThrow(try inventoryViewModel.updateItem(updatedItem))
        
        // Verify location was removed
        let savedItem = inventoryViewModel.items.first
        XCTAssertNil(savedItem?.locationId)
    }
    
    // MARK: - Location Deletion Tests
    
    func testLocationDeletionOrphansItems() throws {
        // Create a location
        let room = StorageLocation(name: "Living Room", type: .room)
        try locationManager.addLocation(room)
        
        // Create item with location
        let item = InventoryItem(
            title: "Test Book",
            type: .books,
            locationId: room.id
        )
        try inventoryViewModel.addItem(item)
        
        // Delete location
        try locationManager.removeLocation(room.id)
        
        // Verify item is orphaned
        let orphanedItem = inventoryViewModel.items.first
        XCTAssertNil(orphanedItem?.locationId)
    }
    
    // MARK: - Location Query Tests
    
    func testHasItemsInLocation() throws {
        // Create a location
        let room = StorageLocation(name: "Living Room", type: .room)
        try locationManager.addLocation(room)
        
        // Initially should have no items
        XCTAssertFalse(inventoryViewModel.hasItemsInLocation(room.id))
        
        // Add item to location
        let item = InventoryItem(
            title: "Test Book",
            type: .books,
            locationId: room.id
        )
        try inventoryViewModel.addItem(item)
        
        // Should now have items
        XCTAssertTrue(inventoryViewModel.hasItemsInLocation(room.id))
    }
} 