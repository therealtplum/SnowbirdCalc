import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var selected: Tab = .overview

    enum Tab: Hashable { case overview, utilities, capital, learn, forms }

    var body: some View {
        TabView(selection: $selected) {
            // OVERVIEW
            NavigationStack {
                OverviewView()
                    .environmentObject(vm)
            }
            .tabItem { Label("Overview", systemImage: "rectangle.3.offgrid") }
            .tag(Tab.overview)

            // UTILITIES (contains Scenarios + future tools)
            NavigationStack {
                UtilitiesView()
                    .environmentObject(vm)
            }
            .tabItem { Label("Utilities", systemImage: "wrench.and.screwdriver") }
            .tag(Tab.utilities)

            // CAPITAL
            NavigationStack {
                CapitalView()
                    .environmentObject(vm)
            }
            .tabItem { Label("Capital", systemImage: "banknote") }
            .tag(Tab.capital)

            // FORMS
            NavigationStack {
                FormsRootView()
                    .environmentObject(vm)
            }
            .tabItem { Label("Forms", systemImage: "doc.text") }
            .tag(Tab.forms)

            // LEARN
            NavigationStack {
                LearnView()
                    .environmentObject(vm)
            }
            .tabItem { Label("Learn", systemImage: "book") }
            .tag(Tab.learn)
        }
    }
}
