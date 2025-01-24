import SwiftUI
import UIKit

struct BookSearchRow: View {
    let book: OpenLibrarySearchDoc
    let onAdd: () -> Void
    @StateObject private var openLibraryService = OpenLibraryService()
    @State private var coverImage: UIImage?
    
    var body: some View {
        HStack {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 90)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 90)
            }
            
            VStack(alignment: .leading) {
                Text(book.title)
                    .font(.headline)
                if let authors = book.authorNames {
                    Text(authors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let isbn = book.primaryISBN {
                    Text("ISBN: \(isbn)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 8)
        .task {
            if let coverId = book.coverId {
                do {
                    coverImage = try await openLibraryService.fetchCoverImage(coverId: coverId, size: .small)
                } catch {
                    print("Failed to load cover: \(error)")
                }
            }
        }
    }
} 