import XCTest
@testable import Pocket_Dimension

final class GoogleBooksServiceTests: XCTestCase {
    var service: GoogleBooksService!
    
    override func setUp() {
        super.setUp()
        service = GoogleBooksService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    func testFetchBooks() {
        let expectation = XCTestExpectation(description: "Fetch books")
        
        service.fetchBooks(query: "One Piece manga") { result in
            switch result {
            case .success(let books):
                XCTAssertFalse(books.isEmpty, "Should return some books")
                if let firstBook = books.first {
                    XCTAssertFalse(firstBook.id.isEmpty, "Book should have an ID")
                    XCTAssertFalse(firstBook.volumeInfo.title.isEmpty, "Book should have a title")
                }
            case .failure(let error):
                XCTFail("Search failed with error: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
} 