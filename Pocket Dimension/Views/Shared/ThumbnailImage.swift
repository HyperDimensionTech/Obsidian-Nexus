import SwiftUI

struct ThumbnailImage: View {
    let url: URL?
    let type: CollectionType
    @State private var image: Image?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderImage
            }
        }
        .frame(width: 60, height: 90)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            loadImage()
        }
    }
    
    private var placeholderImage: some View {
        VStack {
            Image(systemName: type.iconName)
                .font(.title2)
                .foregroundColor(type.color)
            Text(type.name)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    image = Image(uiImage: uiImage)
                }
            } catch {
                print("Error loading image: \(error)")
            }
            isLoading = false
        }
    }
} 