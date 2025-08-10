import SwiftUI

struct BreadcrumbView: View {
    @EnvironmentObject var locationManager: LocationManager
    let locationId: UUID?
    let onCrumbSelected: (UUID?) -> Void
    
    private var breadcrumbs: [(UUID?, String)] {
        guard let id = locationId else {
            return [(nil as UUID?, "Locations")]
        }
        
        var crumbs = [(nil as UUID?, "Locations")]
        var ancestors = locationManager.ancestors(of: id)
        ancestors.append(locationManager.location(withId: id)!)
        
        for location in ancestors {
            crumbs.append((location.id, location.name))
        }
        
        return crumbs
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                    }
                    
                    Button {
                        onCrumbSelected(crumb.0)
                    } label: {
                        Text(crumb.1)
                            .foregroundColor(index == breadcrumbs.count - 1 ? .primary : .accentColor)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 44)
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    let locationManager = LocationManager()
    locationManager.loadSampleData()
    
    return BreadcrumbView(
        locationId: locationManager.rootLocations().first?.id,
        onCrumbSelected: { _ in }
    )
    .environmentObject(locationManager)
} 