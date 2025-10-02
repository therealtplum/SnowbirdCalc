import SwiftUI
import Charts

struct ScenarioListView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showDeleteAllConfirm = false
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.scenarios.isEmpty {
                    EmptyStateView(
                        title: "No scenarios yet",
                        message: "Create your first scenario to start modeling taxes and retirement.",
                        buttonTitle: "Add Scenario"
                    ) { vm.addScenario() }
                } else {
                    List {
                        ForEach(vm.scenarios) { s in
                            NavigationLink(value: s.id) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(s.name).font(.headline)

                                    if let out = vm.output(for: s.id) {
                                        HStack {
                                            Text("Retirement:")
                                            Text(out.totalRetirement, format: .currency(code: "USD")).bold()
                                            Spacer()
                                            Text("Tax:")
                                            Text(out.totalFederalTax, format: .currency(code: "USD")).bold()
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: vm.delete)
                    }
                }
            }
            .navigationTitle("Scenarios")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Add") { vm.addScenario() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Duplicate Current", systemImage: "square.on.square") {
                            vm.duplicateSelected()
                        }
                        .disabled(vm.current == nil)

                        Divider()

                        Button(role: .destructive) {
                            showDeleteAllConfirm = true
                        } label: {
                            Label("Delete All Scenarios", systemImage: "trash")
                        }
                        .disabled(vm.scenarios.isEmpty)

                        Divider()

                        Button {
                            showAbout = true
                        } label: {
                            Label("About", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog(
                "Delete all scenarios?",
                isPresented: $showDeleteAllConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) { vm.deleteAll() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove all scenarios. You can add a new one anytime.")
            }
            .navigationDestination(for: Scenario.ID.self) { id in
                ScenarioEditorView(scenarioID: id)
            }
            .onAppear {
                if vm.selectedID == nil { vm.selectedID = vm.scenarios.first?.id }
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()   // ✅ fill entire screen
            
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
                
                Text(title)
                    .font(.title2.bold())
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                Button(action: action) {
                    Label(buttonTitle, systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: 320)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor)
                        )
                        .shadow(radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding()
        }
    }
}
