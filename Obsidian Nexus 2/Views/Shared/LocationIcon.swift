import SwiftUI

struct LocationIcon: View {
    let type: LocationType
    
    var body: some View {
        Image(systemName: type.icon)
    }
} 