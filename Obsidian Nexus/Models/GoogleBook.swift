import Foundation

// MARK: - Example for Previews
extension GoogleBook {
    static var example: GoogleBook {
        GoogleBook(
            id: "t0LZDwAAQBAJ",
            volumeInfo: GoogleBook.VolumeInfo(
                title: "One Piece, Vol. 93",
                authors: ["Eiichiro Oda"],
                publisher: "VIZ Media LLC",
                publishedDate: "2020-08-04",
                description: "Join Monkey D. Luffy and his swashbuckling crew in their search for the ultimate treasure, the One Piece.",
                imageLinks: GoogleBook.VolumeInfo.ImageLinks(
                    smallThumbnail: "http://books.google.com/books/content?id=t0LZDwAAQBAJ&printsec=frontcover&img=1&zoom=5&edge=curl&source=gbs_api",
                    thumbnail: "http://books.google.com/books/content?id=t0LZDwAAQBAJ&printsec=frontcover&img=1&zoom=1&edge=curl&source=gbs_api",
                    small: nil,
                    medium: nil,
                    large: nil,
                    extraLarge: nil
                ),
                industryIdentifiers: [
                    GoogleBook.VolumeInfo.IndustryIdentifier(type: "ISBN_13", identifier: "9781974712557"),
                    GoogleBook.VolumeInfo.IndustryIdentifier(type: "ISBN_10", identifier: "1974712559")
                ],
                pageCount: 192,
                categories: ["Comics & Graphic Novels"],
                averageRating: nil,
                ratingsCount: nil,
                language: "en",
                mainCategory: "Comics & Graphic Novels"
            )
        )
    }

    static let preview = GoogleBook(
        id: "preview",
        volumeInfo: GoogleBook.VolumeInfo(
            title: "Sample Book Title",
            authors: ["John Doe", "Jane Smith"],
            publisher: "Sample Publisher",
            publishedDate: "2023",
            description: "This is a sample book description.",
            imageLinks: GoogleBook.VolumeInfo.ImageLinks(
                smallThumbnail: "https://example.com/small.jpg",
                thumbnail: "https://example.com/medium.jpg",
                small: "https://example.com/small.jpg",
                medium: "https://example.com/medium.jpg", 
                large: "https://example.com/large.jpg",
                extraLarge: "https://example.com/xlarge.jpg"
            ),
            industryIdentifiers: [
                GoogleBook.VolumeInfo.IndustryIdentifier(type: "ISBN_13", identifier: "9781234567890")
            ],
            pageCount: 300,
            categories: ["Fiction", "Adventure"],
            averageRating: 4.5,
            ratingsCount: 150,
            language: "en",
            mainCategory: "Fiction"
        )
    )
} 