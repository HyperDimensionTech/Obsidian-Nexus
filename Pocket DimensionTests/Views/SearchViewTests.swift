import XCTest
import ViewInspector
@testable import Pocket_Dimension

final class SearchViewTests: XCTestCase {
    var inventoryViewModel: InventoryViewModel!
    
    override func setUp() {
        super.setUp()
        inventoryViewModel = InventoryViewModel()
        // Add some test items
        try? inventoryViewModel.addItem(InventoryItem(
            title: "Test Book",
            type: .books,
            series: nil,
            volume: nil,
            condition: .good,
            locationId: nil,
            notes: nil,
            dateAdded: Date(),
            barcode: nil,
            thumbnailURL: nil,
            author: "Test Author",
            manufacturer: nil,
            originalPublishDate: nil,
            publisher: nil,
            isbn: nil,
            price: nil,
            purchaseDate: nil
        ))
    }
    
    override func tearDown() {
        inventoryViewModel = nil
        super.tearDown()
    }
    
    func testSearchFiltering() throws {
        let view = SearchView()
            .environmentObject(inventoryViewModel)
        
        // Test local search
        let searchText = try view.inspect().find(ViewType.TextField.self).text().string()
        XCTAssertEqual(searchText, "", "Initial search text should be empty")
        
        // Test filter selection
        let filter = try view.inspect().find(ViewType.Picker.self).selection() as? SearchFilter
        XCTAssertEqual(filter, .all, "Initial filter should be 'all'")
    }
    
    func testEmptyStateHandling() throws {
        let view = SearchView()
            .environmentObject(inventoryViewModel)
        
        // Test empty state view
        let hasEmptyView = try view.inspect().find(EmptySearchView.self) != nil
        XCTAssertTrue(hasEmptyView, "Should show empty state when no results")
    }
} 