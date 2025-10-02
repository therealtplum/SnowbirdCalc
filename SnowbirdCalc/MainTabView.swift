import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var selected: Tab = .overview

    enum Tab: Hashable {
        case overview, scenarios, capital, learn
    }

    var body: some View {
        TabView(selection: $selected) {

            // OVERVIEW
            NavigationStack {
                OverviewView()
            }
            .tabItem {
                Label("Overview", systemImage: "rectangle.3.offgrid")
            }
            .tag(Tab.overview)

            // SCENARIOS (existing flow)
            NavigationStack {
                ScenarioListView()
            }
            .tabItem {
                Label("Scenarios", systemImage: "list.bullet.rectangle")
            }
            .tag(Tab.scenarios)

            // CAPITAL
            NavigationStack {
                CapitalView()
            }
            .tabItem {
                Label("Capital", systemImage: "banknote")
            }
            .tag(Tab.capital)
            
            // LEARN
            NavigationStack {
                LearnView()
            }
            .tabItem {
                Label("Learn", systemImage: "book")
            }
            .tag(Tab.learn)
        }
    }
}

// Temporary placeholder so the Overview tab shows something.
// You can delete this and use your real OverviewView later.
private struct OverviewPlaceholderView: View {
    var body: some View {
        List {
            Text("Overview is coming soon.")
                .font(.headline)
            Text("Use the Scenarios and Capital tabs for now.")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Overview")
    }
}
