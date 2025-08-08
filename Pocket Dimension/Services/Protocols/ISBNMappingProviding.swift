import Foundation

public protocol ISBNMappingProviding {
    func getMappingForISBN(_ isbn: String) -> ISBNMapping?
    func createISBNMapping(incorrectISBN: String, correctGoogleBooksID: String, title: String, isReprint: Bool) throws
    func loadISBNMappings() throws -> [ISBNMapping]
}


