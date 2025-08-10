import Foundation

public struct ISBNMapping: Codable, Identifiable {
    public var id: String { incorrectISBN }
    public let incorrectISBN: String
    public let correctGoogleBooksID: String
    public let title: String
    public let isReprint: Bool
    public let dateAdded: Date
    
    public init(incorrectISBN: String, correctGoogleBooksID: String, title: String, isReprint: Bool = false) {
        self.incorrectISBN = incorrectISBN
        self.correctGoogleBooksID = correctGoogleBooksID
        self.title = title
        self.isReprint = isReprint
        self.dateAdded = Date()
    }
    
    public init(incorrectISBN: String, correctGoogleBooksID: String, title: String, isReprint: Bool = false, dateAdded: Date) {
        self.incorrectISBN = incorrectISBN
        self.correctGoogleBooksID = correctGoogleBooksID
        self.title = title
        self.isReprint = isReprint
        self.dateAdded = dateAdded
    }
} 