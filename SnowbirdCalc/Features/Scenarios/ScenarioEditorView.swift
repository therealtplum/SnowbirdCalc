import SwiftUI
import Charts

struct ScenarioEditorView: View {
    @EnvironmentObject var vm: AppViewModel
    let scenarioID: Scenario.ID

    // 🥕 Easter egg overlay
    @State private var showBunny = false

    var body: some View {
        if let s = vm.scenarios.first(where: { $0.id == scenarioID }),
           let out = vm.output(for: scenarioID) {

            ScrollView { // guaranteed scroll
                VStack(spacing: 16) {

                    // ── Scenario
                    SectionCard(title: "Scenario") {
                        TextField("Name", text: Binding(
                            get: { s.name },
                            set: { newName in vm.updateCurrent { $0.name = newName } }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    // ── Plan / Tax
                    SectionCard(title: "Plan / Tax") {
                        row("Employee Deferral") {
                            currencyField(value: s.employeeDeferral) { newVal in
                                vm.updateCurrent { $0.employeeDeferral = newVal }
                            }
                        }
                        Divider()
                        row("Employer %") {
                            percentSlider(value: s.employerPct, max: 0.25) { newVal in
                                vm.updateCurrent { $0.employerPct = newVal }
                            }
                        }
                        Divider()
                        row("Ordinary Rate") {
                            percentSlider(value: s.ordinaryRate, max: 0.60) { newVal in
                                vm.updateCurrent { $0.ordinaryRate = newVal }
                            }
                        }
                        Divider()
                        row("LTCG Rate") {
                            percentSlider(value: s.ltcgRate, max: 0.40) { newVal in
                                vm.updateCurrent { $0.ltcgRate = newVal }
                            }
                        }
                        Divider()
                        row("NIIT Rate") {
                            percentSlider(value: s.niitRate, max: 0.10) { newVal in
                                vm.updateCurrent { $0.niitRate = newVal }
                            }
                        }
                    }

                    // ── Subsidiaries (List with swipe-to-delete + long-press egg)
                    SectionCard(title: "Subsidiaries") {
                        List {
                            ForEach(s.subs) { sub in
                                NavigationLink {
                                    SubsidiaryEditor(sub: sub, scenarioID: s.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(sub.name).font(.headline)
                                            Text(sub.kind.displayName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.footnote)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                            .onDelete { indexSet in
                                vm.updateCurrent { scenario in
                                    scenario.subs.remove(atOffsets: indexSet)
                                }
                            }

                            // Add button — tap adds, long-press shows bunny
                            Button {
                                vm.updateCurrent {
                                    $0.subs.append(
                                        Subsidiary(name: "New Sub",
                                                   kind: .activeBusiness,
                                                   ordinaryIncome: 0,
                                                   mgmtFeePct: 0)
                                    )
                                }
                            } label: {
                                Label("Add Subsidiary", systemImage: "plus.circle")
                            }
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 1.0).onEnded { _ in
                                    #if os(iOS)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    #endif
                                    showBunny = true
                                }
                            )
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)  // keep card look
                        .frame(minHeight: 240, maxHeight: 420) // avoids scroll conflicts
                    }

                    // ── Charts (polished)
                    SectionCard(title: "Charts") {
                        ChartsSection(output: out)
                    }

                    // ── Results
                    SectionCard(title: "Results") {
                        resultRow("HoldCo Earned Income", out.holdcoEarned)
                        resultRow("Employer Contribution", out.employerContribution)
                        resultRow("Total Retirement", out.totalRetirement)
                        Divider()
                        resultRow("Ordinary Tax", out.ordinaryTax)
                        resultRow("Cap Gains + NIIT", out.capGainsAndNIITTax)
                        resultRow("Total Federal Tax", out.totalFederalTax)
                        Divider()
                        resultRow("After-Tax (excl. retirement)", out.afterTaxIncomeExclRet)
                    }
                }
                .padding(16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(s.name)
            .onAppear { vm.selectedID = scenarioID }

            // 🥕 overlay on top of everything
            .overlay {
                if showBunny {
                    BunnyEggView(isPresented: $showBunny)
                        .transition(.opacity)
                        .zIndex(999)
                }
            }

        } else {
            Text("Scenario not found").foregroundStyle(.secondary)
        }
    }

    // MARK: - Small UI helpers

    @ViewBuilder
    private func row(_ title: String, trailing: () -> some View) -> some View {
        HStack {
            Text(title)
            Spacer()
            trailing()
        }
    }

    @ViewBuilder
    private func resultRow(_ title: String, _ number: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(number, format: .currency(code: "USD"))
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func currencyField(value: Double, onChange: @escaping (Double) -> Void) -> some View {
        TextField("", value: Binding(
            get: { value },
            set: { newVal in onChange(newVal) }
        ), format: .number)
        #if os(iOS)
        .keyboardType(.decimalPad)
        #endif
        .multilineTextAlignment(.trailing)
        .textFieldStyle(.roundedBorder)
        .frame(minWidth: 120)
    }

    @ViewBuilder
    private func percentSlider(value: Double, max: Double, onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("\(Int((value * 100).rounded()))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Slider(value: Binding(
                get: { value },
                set: { newVal in onChange(newVal) }
            ), in: 0...max)
            .frame(minWidth: 160)
        }
    }
}

// SectionCard is now in UI/Components/SectionCard.swift
