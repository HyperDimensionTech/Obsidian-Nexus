import XCTest
@testable import Obsidian_Nexus

class InventoryViewModelTests: XCTestCase {
    var sut: InventoryViewModel!
    var mockStorage: MockStorageManager!
    
    override func setUp() {
        super.setUp()
        mockStorage = MockStorageManager()
        sut = InventoryViewModel(storage: mockStorage)
    }
    
    override func tearDown() {
        sut = nil
        mockStorage = nil
        super.tearDown()
    }
    
    func testAddValidItem() throws {
        let item = InventoryItem(title: "Test Book", type: .books)
        try sut.addItem(item)
        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(mockStorage.savedItems.count, 1)
    }
    
    func testAddInvalidItem() {
        let item = InventoryItem(title: "", type: .books)
        XCTAssertThrowsError(try sut.addItem(item)) { error in
            XCTAssertEqual(error as? InventoryError, .invalidTitle)
        }
    }
    
    func testDeleteItem() {
        // Add an item first
        let item = InventoryItem(title: "Test", type: .books)
        try? sut.addItem(item)
        
        // Then delete it
        sut.deleteItem(item)
        XCTAssertEqual(sut.items.count, 0)
        XCTAssertEqual(mockStorage.savedItems.count, 0)
    }
} 