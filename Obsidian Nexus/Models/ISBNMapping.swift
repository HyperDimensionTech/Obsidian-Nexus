import Foundation

struct ISBNMapping: Codable, Identifiable {
    var id: String { incorrectISBN }
    let incorrectISBN: String
    let correctGoogleBooksID: String
    let title: String
    let isReprint: Bool
    let dateAdded: Date
    
    init(incorrectISBN: String, correctGoogleBooksID: String, title: String, isReprint: Bool = false) {
        self.incorrectISBN = incorrectISBN
        self.correctGoogleBooksID = correctGoogleBooksID
        self.title = title
        self.isReprint = isReprint
        self.dateAdded = Date()
    }
    
    init(incorrectISBN: String, correctGoogleBooksID: String, title: String, isReprint: Bool = false, dateAdded: Date) {
        self.incorrectISBN = incorrectISBN
        self.correctGoogleBooksID = correctGoogleBooksID
        self.title = title
        self.isReprint = isReprint
        self.dateAdded = dateAdded
    }
} 