import SwiftUI

struct BookSearchResultView: View {
    let book: GoogleBook
    let onSelect: (GoogleBook) -> Void
    @StateObject private var thumbnailService = ThumbnailService()
    @State private var thumbnailURL: URL?
    @State private var isAdded = false
    @State private var showingSuccess = false
    
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
        Button(action: {
            withAnimation {
                isAdded = true
                showingSuccess = true
            }
            onSelect(book)
            
            // Reset after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showingSuccess = false
                }
            }
        }) {
            HStack(spacing: 12) {
                // Thumbnail
                if let thumbnail = book.volumeInfo.imageLinks?.thumbnail {
                    AsyncImage(url: processImageURL(thumbnail)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "book")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 90)
                } else {
                    Image(systemName: "book")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 90)
                        .foregroundColor(.gray)
                }
                
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
                }
                
                Spacer()
                
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundColor(isAdded ? .green : .accentColor)
                    .imageScale(.large)
            }
            .padding(.vertical, 8)
            .overlay(alignment: .top) {
                if showingSuccess {
                    Text("Added to collection!")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

} 