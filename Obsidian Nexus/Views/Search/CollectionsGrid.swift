import SwiftUI

struct CollectionsGrid: View {
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Collections")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(CollectionType.literatureTypes, id: \.self) { type in
                    NavigationLink(value: type) {
                        CollectionCard(type: type)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
        }
    }
} 