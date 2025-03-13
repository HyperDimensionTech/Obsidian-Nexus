import SwiftUI

struct BookSearchResultRow: View {
    let book: GoogleBook
    
    var body: some View {
        HStack(spacing: 12) {
            // Book thumbnail
            if let thumbnail = book.volumeInfo.imageLinks?.thumbnail,
               let url = URL(string: thumbnail.replacingOccurrences(of: "http://", with: "https://")) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 90)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 90)
                            .cornerRadius(4)
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    case .failure:
                        Image(systemName: "book.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 90)
                            .foregroundColor(.gray)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    @unknown default:
                        Image(systemName: "book")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 90)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                Image(systemName: "book.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 90)
                    .foregroundColor(.gray)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
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
                
                if let publisher = book.volumeInfo.publisher {
                    Text(publisher)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let publishedDate = book.volumeInfo.publishedDate {
                    Text(publishedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, 8)
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