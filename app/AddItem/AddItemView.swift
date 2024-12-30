struct AddItemView: View {
    @State private var location: String = ""

    var body: some View {
        TextField("Location", text: $location)
        // ... existing code ...
    }
} 