import XCTest
@testable import Pocket_Dimension

final class LocationManagerTests: XCTestCase {
    var locationManager: LocationManager!
    var inventoryViewModel: InventoryViewModel!
    
    override func setUp() {
        super.setUp()
        locationManager = LocationManager()
        inventoryViewModel = InventoryViewModel(locationManager: locationManager)
        locationManager.inventoryViewModel = inventoryViewModel
    }
    
    override func tearDown() {
        locationManager = nil
        inventoryViewModel = nil
        super.tearDown()
    }
    
    // MARK: - CRUD Tests
    
    func testAddLocation() throws {
        let room = StorageLocation(name: "Living Room", type: .room)
        XCTAssertNoThrow(try locationManager.addLocation(room))
        XCTAssertNotNil(locationManager.location(withId: room.id))
    }
    
    func testAddLocationWithInvalidParent() {
        let shelf = StorageLocation(
            name: "Bookshelf",
            type: .shelf,
            parentId: UUID() // Non-existent parent
        )
        XCTAssertThrowsError(try locationManager.addLocation(shelf)) { error in
            XCTAssertEqual(error as? LocationError, .parentNotFound)
        }
    }
    
    func testUpdateLocation() throws {
        // Add initial location
        let room = StorageLocation(name: "Living Room", type: .room)
        try locationManager.addLocation(room)
        
        // Update location
        var updatedRoom = room
        updatedRoom.name = "Updated Living Room"
        XCTAssertNoThrow(try locationManager.updateLocation(updatedRoom))
        
        // Verify update
        let retrieved = locationManager.location(withId: room.id)
        XCTAssertEqual(retrieved?.name, "Updated Living Room")
    }
    
    func testDeleteLocation() throws {
        // Add location
        let room = StorageLocation(name: "Living Room", type: .room)
        try locationManager.addLocation(room)
        
        // Delete location
        XCTAssertNoThrow(try locationManager.removeLocation(room.id))
        XCTAssertNil(locationManager.location(withId: room.id))
    }
    
    // MARK: - Hierarchy Tests
    
    func testHierarchyOperations() throws {
        let room = StorageLocation(name: "Living Room", type: .room)
        try locationManager.addLocation(room)
        
        let shelf = StorageLocation(
            name: "Bookshelf",
            type: .shelf,
            parentId: room.id
        )
        try locationManager.addLocation(shelf)
        
        // Test parent-child relationship
        XCTAssertEqual(locationManager.children(of: room.id).count, 1)
        XCTAssertEqual(locationManager.children(of: room.id).first?.id, shelf.id)
    }
    
    func testCircularReferenceDetection() throws {
        // Create initial hierarchy
        let room = StorageLocation(name: "Living Room", type: .room)
        try locationManager.addLocation(room)
        
        let shelf = StorageLocation(
            name: "Bookshelf",
            type: .shelf,
            parentId: room.id
        )
        try locationManager.addLocation(shelf)
        
        // Attempt to make room a child of shelf
        var updatedRoom = room
        updatedRoom.parentId = shelf.id
        
        XCTAssertThrowsError(try locationManager.updateLocation(updatedRoom)) { error in
            XCTAssertEqual(error as? LocationError, .circularReference)
        }
    }
    
    // MARK: - Data Integrity Tests
    
    func testCascadingDelete() throws {
        // Create hierarchy
        let room = StorageLocation(name: "Living Room", type: .room)
        try locationManager.addLocation(room)
        
        let shelf = StorageLocation(
            name: "Bookshelf",
            type: .shelf,
            parentId: room.id
        )
        try locationManager.addLocation(shelf)
        
        // Add item to shelf
        let item = InventoryItem(
            title: "Test Book",
            type: .books,
            locationId: shelf.id
        )
        try inventoryViewModel.addItem(item)
        
        // Attempt to delete shelf (should fail due to items)
        XCTAssertThrowsError(try locationManager.removeLocation(shelf.id)) { error in
            XCTAssertEqual(
                (error as? LocationError)?.errorDescription,
                "Cannot delete location that contains items"
            )
        }
        
        // Remove item and try again
        inventoryViewModel.deleteItem(item)
        XCTAssertNoThrow(try locationManager.removeLocation(shelf.id))
    }
    
    func testOrphanedItems() throws {
        // Create location and item
        let room = StorageLocation(name: "Living Room", type: .room)
        try locationManager.addLocation(room)
        
        let item = InventoryItem(
            title: "Test Book",
            type: .books,
            locationId: room.id
        )
        try inventoryViewModel.addItem(item)
        
        // Delete location and verify item is orphaned
        try locationManager.removeLocation(room.id)
        
        let orphanedItem = inventoryViewModel.items.first
        XCTAssertNil(orphanedItem?.locationId)
    }
} 