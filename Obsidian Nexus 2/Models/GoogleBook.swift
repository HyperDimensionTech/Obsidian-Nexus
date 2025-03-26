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
                    thumbnail: "http://books.google.com/books/content?id=t0LZDwAAQBAJ&printsec=frontcover&img=1&zoom=1&edge=curl&source=gbs_api"
                ),
                industryIdentifiers: [
                    GoogleBook.VolumeInfo.IndustryIdentifier(type: "ISBN_13", identifier: "9781974712557"),
                    GoogleBook.VolumeInfo.IndustryIdentifier(type: "ISBN_10", identifier: "1974712559")
                ]
            )
        )
    }
} 