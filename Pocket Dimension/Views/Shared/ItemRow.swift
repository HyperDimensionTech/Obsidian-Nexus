import SwiftUI

struct ItemRow: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userPreferences: UserPreferences
    let item: InventoryItem
    
    var body: some View {
        ItemDisplayComponent(
            item: item,
            displayStyle: .normal,
            showFullLocationPath: true
        )
    }
}

#Preview {
    ItemRow(item: InventoryItem(
        title: "One Piece, Vol. 1",
        type: .manga,
        series: "One Piece",
        volume: 1,
        condition: .good,
        locationId: nil,
        price: Price(amount: 9.99, currency: .usd)
    ))
    .environmentObject(LocationManager())
    .environmentObject(UserPreferences())
} 