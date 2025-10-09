import SwiftUI

struct SubsidiaryEditor: View {
    @EnvironmentObject var vm: AppViewModel
    let sub: Subsidiary
    let scenarioID: Scenario.ID

    var body: some View {
        Form {
            // Basics
            Section("Basics") {
                textField("Name", text: sub.name) { newText in
                    update { $0.name = newText }
                }

                Picker("Type", selection: Binding(
                    get: { sub.kind },
                    set: { newKind in update { $0.kind = newKind } }
                )) {
                    ForEach(SubsidiaryType.allCases) { k in
                        Text(k.displayName).tag(k)
                    }
                }
            }

            // Per-type inputs
            if sub.kind == .investment {
                Section("Investment (Markets)") {
                    currencyField("LTCG", value: sub.ltcg) { newVal in
                        update { $0.ltcg = newVal }
                    }
                    currencyField("STCG", value: sub.stcg) { newVal in
                        update { $0.stcg = newVal }
                    }
                    pctSlider("Mgmt Fee % (of cap gains)", value: sub.mgmtFeePct) { newVal in
                        update { $0.mgmtFeePct = newVal }
                    }
                }
            } else if sub.kind == .royalties {
                Section("Royalties") {
                    currencyField("Gross Royalties", value: sub.ordinaryIncome) { newVal in
                        update { $0.ordinaryIncome = newVal }
                    }
                    pctSlider("Mgmt Fee % (of gross)", value: sub.mgmtFeePct) { newVal in
                        update { $0.mgmtFeePct = newVal }
                    }
                    pctSlider("Depletion %", value: sub.depletionPct, max: 0.30) { newVal in
                        update { $0.depletionPct = newVal }
                    }
                }
            } else {
                Section(sub.kind == .activeBusiness ? "Active Business" : "Passive Farm") {
                    currencyField("Ordinary Income", value: sub.ordinaryIncome) { newVal in
                        update { $0.ordinaryIncome = newVal }
                    }
                    pctSlider("Mgmt Fee %", value: sub.mgmtFeePct) { newVal in
                        update { $0.mgmtFeePct = newVal }
                    }
                }
            }
        }
        .navigationTitle(sub.name)
    }

    // MARK: - Helpers

    /// Mutates the current subsidiary inside the selected scenario
    func update(_ mutate: @escaping (inout Subsidiary) -> Void) {
        vm.updateCurrent { scenario in
            if let i = scenario.subs.firstIndex(where: { $0.id == sub.id }) {
                mutate(&scenario.subs[i])
            }
        }
    }

    func textField(_ title: String, text: String, onChange: @escaping (String) -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, text: Binding(
                get: { text },
                set: { newVal in onChange(newVal) }
            ))
            .multilineTextAlignment(.trailing)
        }
    }

    func currencyField(_ title: String, value: Double, onChange: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: Binding(
                get: { value },
                set: { newVal in onChange(newVal) }
            ), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
        }
    }

    func pctSlider(_ title: String, value: Double, max: Double = 1.0, onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: Binding(
                get: { value },
                set: { newVal in onChange(newVal) }
            ), in: 0...max)
        }
    }
}
