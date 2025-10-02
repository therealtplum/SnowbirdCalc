import SwiftUI

struct CapitalView: View {
    @StateObject private var vm = CapitalViewModel()
    @FocusState private var focusedField: FocusedField?
    @State private var showClearConfirm = false

    private enum FocusedField: Hashable {
        case contributions
        case subAllocation(UUID)
        case subName(UUID)
    }

    private let usd: FloatingPointFormatStyle<Double>.Currency = .currency(code: "USD")

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Contributions & Summary
                SectionCard(title: "HoldCo Capital") {
                    row("Total Contributions") {
                        currencyField(value: vm.contributions) { vm.contributions = max(0, $0) }
                            .focused($focusedField, equals: .contributions)
                            .submitLabel(.done)
                    }
                    Divider()
                    summaryRow("Allocated", vm.allocatedTotal)
                    summaryRow("Cash on hand", vm.cashOnHand,
                               tint: vm.isOverAllocated ? .red : .secondary)
                    summaryRow("Portfolio value", vm.portfolioValue)
                    Divider()
                    HStack {
                        Text("Blended pre-tax yield")
                        Spacer()
                        Text("\(Int((vm.blendedPreTaxYieldPct * 100).rounded()))%")
                            .monospacedDigit()
                    }

                    // ✅ New: dollar figure for that yield
                    row("Projected pre-tax income (annual)") {
                        Text(vm.projectedPreTaxIncome, format: .currency(code: "USD"))
                            .monospacedDigit()
                    }

                    // ✅ keep this INSIDE the SectionCard
                    if vm.isOverAllocated {
                        Label("Over-allocated by \(usd.format(abs(vm.cashOnHand)))",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                // ── Subsidiary Allocations
                SectionCard(title: "Subsidiaries") {
                    List {
                        Section {
                            ForEach(vm.subs) { sub in
                                VStack(alignment: .leading, spacing: 10) {
                                    // Name
                                    TextField("Name", text: Binding(
                                        get: { sub.name },
                                        set: { newName in vm.updateSub(sub) { $0.name = newName } }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .subName(sub.id))
                                    .submitLabel(.done)

                                    // Allocation $
                                    row("Allocation") {
                                        currencyField(value: sub.allocation) { newVal in
                                            vm.updateSub(sub) { $0.allocation = max(0, newVal) }
                                        }
                                        .focused($focusedField, equals: .subAllocation(sub.id))
                                        .submitLabel(.done)
                                    }

                                    // Pre-tax yield %
                                    row("Pre-tax yield") {
                                        percentSlider(value: sub.preTaxYieldPct, max: 1.0) { newVal in
                                            vm.updateSub(sub) { $0.preTaxYieldPct = max(0, min(1.0, newVal)) }
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                            .onDelete(perform: vm.delete)
                        } footer: {
                            // ✅ Footer with full-width CTA, same look as Scenarios
                            VStack(spacing: 8) {
                                Button {
                                    focusedField = nil
                                    vm.addSub()
                                } label: {
                                    Label("Add Subsidiary", systemImage: "plus.circle.fill")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color.accentColor)
                                        )
                                        .shadow(radius: 8, y: 4)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 6)
                            // Make footer stretch edge-to-edge like a row
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .frame(minHeight: 280, maxHeight: 520)
                }

                // ── Next steps
                SectionCard(title: "What’s next") {
                    Text("Coming up: Post-tax yields, tax assumptions per sub (entity type, rates), and time-based growth to project portfolio value.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Capital")

        // Keyboard UX
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            // Done button above the keyboard
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
            // Clear All (top-right)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showClearConfirm = true
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .disabled(vm.contributions == 0 && vm.subs.isEmpty)
            }
        }
        // Only intercept taps when a field is focused (so buttons stay responsive)
        .background(
            Group {
                if focusedField != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { focusedField = nil }
                }
            }
        )
        .onSubmit { focusedField = nil }

        // Confirmation for Clear All
        .confirmationDialog(
            "Clear all capital inputs?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                focusedField = nil
                vm.clearAll()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reset contributions to $0 and remove all subsidiary allocations.")
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
    private func summaryRow(_ title: String, _ number: Double, tint: Color = .secondary) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(number, format: usd)
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private func currencyField(value: Double, onChange: @escaping (Double) -> Void) -> some View {
        TextField(
            "",
            value: Binding(
                get: { value },
                set: { newVal in onChange(newVal) }
            ),
            format: FloatingPointFormatStyle<Double>.Currency.currency(code: "USD").rounded(rule: .towardZero, increment: 1) // whole dollars only

        )
        #if os(iOS)
        .keyboardType(.decimalPad)
        #endif
        .multilineTextAlignment(.trailing)
        .textFieldStyle(.roundedBorder)
        .monospacedDigit()
        .frame(minWidth: 140)
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
