struct DashboardView: View {
    var body: some View {
        VStack {
            StatsOverviewCard()
            RecentItemsSection()
        }
    }
} 