import SwiftUI

struct BookSearchResultRow: View {
    let book: GoogleBook
    
    /// Enhanced image URL processing for Google Books thumbnails
    private func processImageURL(_ urlString: String?) -> URL? {
        guard let urlString = urlString else { return nil }
        
        var processedString = urlString
        
        // Ensure HTTPS
        if processedString.hasPrefix("http://") {
            processedString = "https://" + processedString.dropFirst(7)
        }
        
        // Optimize Google Books URLs for better quality
        if processedString.contains("books.google.com") {
            processedString = processedString.replacingOccurrences(of: "zoom=1", with: "zoom=2")
            processedString = processedString.replacingOccurrences(of: "&edge=curl", with: "")
        }
        
        return URL(string: processedString)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Book cover
            if let thumbnailURL = book.volumeInfo.imageLinks?.thumbnail {
                AsyncImage(url: processImageURL(thumbnailURL)) { phase in
                    switch phase {
                    case .empty:
                        Color.gray.opacity(0.2)
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "book.closed")
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 50, height: 75)
                .cornerRadius(4)
            } else {
                Image(systemName: "book.closed")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(width: 50, height: 75)
            }
            
            // Book details
            VStack(alignment: .leading, spacing: 4) {
                Text(book.volumeInfo.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let authors = book.volumeInfo.authors {
                    Text(authors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let publishedYear = book.volumeInfo.publishedDate?.prefix(4) {
                    Text("Published: \(publishedYear)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(book.volumeInfo.title), by \(book.volumeInfo.authors?.joined(separator: ", ") ?? "Unknown author")")
        .accessibilityHint("Tap to select this book")
    }

}

#Preview {
    BookSearchResultRow(book: GoogleBook.example)
        .padding()
        .frame(height: 120)
} 