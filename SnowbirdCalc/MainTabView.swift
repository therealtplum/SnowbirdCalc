import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var selected: Tab = .overview

    enum Tab: Hashable { case overview, scenarios, capital, learn, forms }

    var body: some View {
        TabView(selection: $selected) {
            // OVERVIEW
            NavigationStack {
                OverviewView()
                    .environmentObject(vm)          // ★ ensure vm flows in
            }
            .tabItem { Label("Overview", systemImage: "rectangle.3.offgrid") }
            .tag(Tab.overview)

            // SCENARIOS
            NavigationStack {
                ScenarioListView()
                    .environmentObject(vm)          // ★
            }
            .tabItem { Label("Scenarios", systemImage: "list.bullet.rectangle") }
            .tag(Tab.scenarios)

            // CAPITAL
            NavigationStack {
                CapitalView()
                    .environmentObject(vm)          // ★
            }
            .tabItem { Label("Capital", systemImage: "banknote") }
            .tag(Tab.capital)

            // FORMS
            NavigationStack {
                FormsRootView()
                    .environmentObject(vm)          // optional, if Forms needs vm
            }
            .tabItem { Label("Forms", systemImage: "doc.text") }
            .tag(Tab.forms)
            
            // LEARN
            NavigationStack {
                LearnView()
                    .environmentObject(vm)          // ★
            }
            .tabItem { Label("Learn", systemImage: "book") }
            .tag(Tab.learn)
        }
    }
}
