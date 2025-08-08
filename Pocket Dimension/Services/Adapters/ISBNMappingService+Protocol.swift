import Foundation

extension ISBNMappingService: ISBNMappingProviding {
    func createISBNMapping(incorrectISBN: String, correctGoogleBooksID: String, title: String, isReprint: Bool) throws {
        addMapping(incorrectISBN: incorrectISBN, googleBooksId: correctGoogleBooksID, title: title, isReprint: isReprint)
    }

    func loadISBNMappings() throws -> [ISBNMapping] {
        return mappings
    }
}


