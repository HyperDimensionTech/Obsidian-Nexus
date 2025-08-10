import XCTest
@testable import Pocket_Dimension

final class OpenLibraryServiceTests: XCTestCase {
    var service: OpenLibraryService!
    
    override func setUp() {
        super.setUp()
        service = OpenLibraryService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    func testSearchBooks() async throws {
        // Test basic search
        let response = try await service.searchBooks(query: "Foundation Asimov")
        XCTAssertFalse(response.docs.isEmpty, "Search should return results")
        XCTAssertTrue(response.docs.contains { $0.title.contains("Foundation") })
        
        // Test ISBN search
        let isbnResponse = try await service.searchBooks(query: "isbn:9780553293357")
        XCTAssertFalse(isbnResponse.docs.isEmpty, "ISBN search should return results")
        
        // Test empty search
        let emptyResponse = try await service.searchBooks(query: "")
        XCTAssertTrue(emptyResponse.docs.isEmpty, "Empty query should return no results")
    }
    
    func testSearchByISBN() async throws {
        let book = try await service.searchByISBN("9780553293357")
        XCTAssertNotNil(book, "Should find book by ISBN")
        XCTAssertEqual(book?.title, "Foundation")
    }
    
    func testFetchCoverImage() async throws {
        // Use a known cover ID from OpenLibrary
        let image = try await service.fetchCoverImage(coverId: 12345, size: .small)
        XCTAssertNotNil(image, "Should fetch cover image")
    }
} 