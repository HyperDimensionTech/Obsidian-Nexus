import SwiftUI
import PhotosUI

struct ItemImagePicker: View {
    @Binding var imageData: Data?
    @State private var showingOptions = false
    @State private var imageSelection: PhotosPickerItem? = nil
    
    var body: some View {
        VStack {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            } else {
                Image(systemName: "photo.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                    .frame(height: 200)
            }
            
            HStack {
                PhotosPicker(selection: $imageSelection, matching: .images) {
                    Label("Choose Photo", systemImage: "photo")
                }
                
                if imageData != nil {
                    Button("Remove Photo", role: .destructive) {
                        imageData = nil
                        imageSelection = nil
                    }
                }
            }
        }
        .onChange(of: imageSelection) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        // Compress image before storing
                        if let uiImage = UIImage(data: data) {
                            let maxSize: CGFloat = 1024 // Max dimension
                            let scale = min(maxSize/uiImage.size.width, maxSize/uiImage.size.height, 1.0)
                            let newSize = CGSize(width: uiImage.size.width * scale, 
                                               height: uiImage.size.height * scale)
                            
                            let renderer = UIGraphicsImageRenderer(size: newSize)
                            let compressedImage = renderer.image { context in
                                uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                            }
                            
                            self.imageData = compressedImage.jpegData(compressionQuality: 0.7)
                        }
                    }
                }
            }
        }
    }
} 