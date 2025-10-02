import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Snapshot of the currently selected Scenario
                SectionCard(title: "Snapshot") {
                    if let s = vm.current {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(s.name).font(.title3).fontWeight(.semibold)
                                Spacer()
                                // simple health-ish tag based on number of subs
                                Capsule()
                                    .fill((s.subs.isEmpty ? Color.orange : Color.green).opacity(0.2))
                                    .overlay(Text(s.subs.isEmpty ? "No Subsidiaries" : "Configured")
                                        .font(.footnote)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .foregroundStyle(.secondary))
                                    .frame(height: 28)
                            }

                            // High-level rates / settings
                            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                                GridRow {
                                    LabelValue("Employee Deferral", dollar(s.employeeDeferral))
                                    LabelValue("Employer Match", pct(s.employerPct))
                                }
                                GridRow { LabelValue("Ordinary Rate",       pct(s.ordinaryRate))     ; LabelValue("LTCG Rate",        pct(s.ltcgRate)) }
                                GridRow { LabelValue("NIIT Rate",           pct(s.niitRate))         ; LabelValue("Subsidiaries",     "\(s.subs.count)") }
                            }
                        }
                    } else {
                        Text("No scenario selected.")
                            .foregroundStyle(.secondary)
                        Button {
                            vm.addScenario()
                        } label: {
                            Label("Create your first scenario", systemImage: "plus.circle")
                        }
                    }
                }

                // Quick Actions
                SectionCard(title: "Quick Actions") {
                    HStack(spacing: 12) {
                        Button {
                            vm.addScenario(vm.current)
                        } label: {
                            Label("New Scenario", systemImage: "plus.circle")
                        }

                        Button {
                            vm.duplicateSelected()
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                        .disabled(vm.current == nil)

                        Button(role: .destructive) {
                            vm.deleteAll()
                        } label: {
                            Label("Delete All", systemImage: "trash")
                        }
                        .disabled(vm.scenarios.isEmpty)
                    }
                }

                // Scenarios at a glance
                SectionCard(title: "Your Scenarios") {
                    if vm.scenarios.isEmpty {
                        Text("No scenarios yet. Create one to get started.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(vm.scenarios) { s in
                                Button {
                                    vm.selectedID = s.id
                                } label: {
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(s.name)
                                                .fontWeight(.medium)
                                            Text("\(s.subs.count) subsidiaries • Deferral \(dollar(s.employeeDeferral))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if vm.selectedID == s.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 10)

                                if s.id != vm.scenarios.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Overview")
    }
}

// Small helper for label/value pairs
private struct LabelValue: View {
    var label: String
    var value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body)
        }
    }
}

// Percent helper that doesn’t explode if you feed 0–1 or 0–100
private func pct(_ x: Double) -> String {
    // Heuristic: if value <= 1 treat as 0–1, else assume 0–100
    let v = (x <= 1.0) ? x : (x / 100.0)
    return v.formatted(.percent.precision(.fractionLength(1)))
}

func dollar(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "en_US") // or whatever locale
    return formatter.string(from: NSNumber(value: value)) ?? "$0"
}
