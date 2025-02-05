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
                        self.imageData = data
                    }
                }
            }
        }
    }
} 