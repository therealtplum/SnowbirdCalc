import SwiftUI
import Combine

// MARK: - Shared App State available to all tabs
final class PortfolioStore: ObservableObject {
    // Core financials (replace with your real data later)
    @Published var contributions: Double = 1_500_000
    @Published var cashOnHand: Double = 210_000
    @Published var portfolioValue: Double = 2_240_000

    // Derived
    var netWorth: Double { portfolioValue + cashOnHand }

    // Hooks for Quick Actions
    var onAddContribution: (() -> Void)?
    var onAllocateCapital:   (() -> Void)?
    var onRecordTransaction: (() -> Void)?
}

// MARK: - Simple router to switch tabs programmatically
final class AppRouter: ObservableObject {
    enum Tab: Hashable { case overview, capital, activity }
    @Published var selectedTab: Tab = .overview
    func goTo(_ tab: Tab) { selectedTab = tab }
}

// Optional placeholder so the TabView compiles
struct ActivityView: View {
    var body: some View {
        List { Text("Activity goes here") }
            .navigationTitle("Activity")
    }
}
