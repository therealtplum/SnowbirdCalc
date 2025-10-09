import Foundation
import SwiftUI
import Combine

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: Published state
    @Published var scenarios: [Scenario] { didSet { save() } }
    @Published var selectedID: Scenario.ID? { didSet { save() } }
    @Published private(set) var outputs: [Scenario.ID: CalculatorOutput] = [:]
    @Published var store = PortfolioStore()
    @Published var router = AppRouter()

    // MARK: Storage
    private let saveURL: URL

    // MARK: Init / Load
    init() {
        let fm = FileManager.default
        let docs = try! fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        self.saveURL = docs.appendingPathComponent("scenarios.json")

        if let data = try? Data(contentsOf: saveURL),
           let decoded = try? JSONDecoder().decode(SavedState.self, from: data) {
            self.scenarios = decoded.scenarios
            if let savedID = decoded.selectedID,
               decoded.scenarios.contains(where: { $0.id == savedID }) {
                self.selectedID = savedID
            } else {
                self.selectedID = decoded.scenarios.first?.id
            }
        } else {
            let initial = [Scenario()]         // your default initializer
            self.scenarios = initial
            self.selectedID = initial.first?.id
        }
        recalcAll()
    }

    // MARK: Convenience
    var current: Scenario? {
        guard let id = selectedID else { return nil }
        return scenarios.first(where: { $0.id == id })
    }

    func output(for id: Scenario.ID) -> CalculatorOutput? { outputs[id] }

    // MARK: Mutations
    func updateCurrent(_ mutate: (inout Scenario) -> Void) {
        guard let id = selectedID,
              let idx = scenarios.firstIndex(where: { $0.id == id }) else { return }
        mutate(&scenarios[idx])
        outputs[id] = Calc.compute(scenarios[idx])
    }

    func addScenario(_ base: Scenario? = nil) {
        let new = base.map(withFreshIDs) ?? Scenario()
        scenarios.append(new)
        selectedID = new.id
    }

    func duplicateSelected() {
        guard let s = current else { return }
        var copy = withFreshIDs(s)
        copy.name = uniqueName(from: s.name)
        scenarios.append(copy)
        selectedID = copy.id
    }

    // Removed the old `func delete(_ offsets: IndexSet)` to avoid API confusion.
    // Use the extension's `delete(at:)` and `delete(id:)` instead.

    func deleteAll() {
        scenarios.removeAll()
        selectedID = nil
    }

    // MARK: Recalc
    func recalcAll() {
        var new: [Scenario.ID: CalculatorOutput] = [:]
        for s in scenarios { new[s.id] = Calc.compute(s) }
        outputs = new
    }

    // MARK: Persistence
    private func save() {
        let state = SavedState(scenarios: scenarios, selectedID: selectedID)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: saveURL)
        }
        recalcAll()
    }

    private struct SavedState: Codable {
        var scenarios: [Scenario]
        var selectedID: Scenario.ID?   // allow empty state
    }

    // MARK: Helpers (fresh IDs without mutating let id)
    private func withFreshIDs(_ scenario: Scenario) -> Scenario {
        Scenario(
            id: UUID(),
            name: scenario.name,
            employeeDeferral: scenario.employeeDeferral,
            employerPct: scenario.employerPct,
            ordinaryRate: scenario.ordinaryRate,
            ltcgRate: scenario.ltcgRate,
            niitRate: scenario.niitRate,
            subs: scenario.subs.map { sub in
                Subsidiary(
                    id: UUID(),
                    name: sub.name,
                    kind: sub.kind,
                    ltcg: sub.ltcg,
                    stcg: sub.stcg,
                    ordinaryIncome: sub.ordinaryIncome,
                    mgmtFeePct: sub.mgmtFeePct,
                    depletionPct: sub.depletionPct
                )
            }
        )
    }

    private func uniqueName(from base: String) -> String {
        let existing = Set(scenarios.map(\.name))
        let first = "\(base) Copy"
        guard existing.contains(first) else { return first }
        var i = 2
        while existing.contains("\(base) Copy \(i)") { i += 1 }
        return "\(base) Copy \(i)"
    }

    // Core remover that both public delete methods use
    private func removeScenario(at index: Int) {
        let removed = scenarios.remove(at: index)
        if selectedID == removed.id {
            selectedID = scenarios.first?.id
        }
    }
}

// MARK: - Deletion helpers (List swipe + edit-mode)
extension AppViewModel {
    /// For `.onDelete` with `IndexSet`
    func delete(at offsets: IndexSet) {
        // remove in reverse to keep indices valid
        for idx in offsets.sorted(by: >) {
            guard scenarios.indices.contains(idx) else { continue }
            removeScenario(at: idx)
        }
    }

    /// For `.swipeActions` delete by id
    func delete(id: Scenario.ID) {
        if let idx = scenarios.firstIndex(where: { $0.id == id }) {
            removeScenario(at: idx)
        }
    }
}
