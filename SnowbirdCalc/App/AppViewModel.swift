import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
final class AppViewModel: ObservableObject {
    
    private static let logger = Logger(subsystem: "com.snowbirdcalc", category: "AppViewModel")

    // MARK: Published state
    @Published var scenarios: [Scenario] { didSet { save() } }
    @Published var selectedID: Scenario.ID? { didSet { save() } }
    @Published private(set) var outputs: [Scenario.ID: CalculatorOutput] = [:]
    @Published var store = PortfolioStore()
    @Published var router = AppRouter()
    @Published var lastError: String?

    // MARK: Storage
    private let saveURL: URL
    private var lastSavedScenarios: [Scenario] = []
    private var lastSavedSelectedID: Scenario.ID?

    // MARK: Init / Load
    init() {
        let fm = FileManager.default
        
        // Safe file URL creation with fallback
        guard let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            // Fallback to temporary directory if document directory fails
            Self.logger.error("Failed to access document directory, using temporary directory")
            self.saveURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("scenarios.json")
            // Initialize with default scenario
            self.scenarios = [Scenario()]
            self.selectedID = self.scenarios.first?.id
            recalcAll()
            return
        }
        
        self.saveURL = docs.appendingPathComponent("scenarios.json")

        // Load saved state with error handling
        if let data = try? Data(contentsOf: saveURL),
           let decoded = try? JSONDecoder().decode(SavedState.self, from: data) {
            self.scenarios = decoded.scenarios
            if let savedID = decoded.selectedID,
               decoded.scenarios.contains(where: { $0.id == savedID }) {
                self.selectedID = savedID
            } else {
                self.selectedID = decoded.scenarios.first?.id
            }
            Self.logger.info("Loaded \(decoded.scenarios.count) scenarios from disk")
        } else {
            // Default initializer if load fails
            let initial = [Scenario()]
            self.scenarios = initial
            self.selectedID = initial.first?.id
            Self.logger.info("Initialized with default scenario")
        }
        
        // Track initial state for change detection
        lastSavedScenarios = scenarios
        lastSavedSelectedID = selectedID
        
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
        // Only recalculate the changed scenario
        outputs[id] = Calc.compute(scenarios[idx])
    }

    func addScenario(_ base: Scenario? = nil) {
        let new = base.map(withFreshIDs) ?? Scenario()
        
        // Validate scenario name
        let trimmedName = new.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            Self.logger.warning("Attempted to add scenario with empty name, using default")
            var validScenario = new
            validScenario.name = "My Scenario"
            scenarios.append(validScenario)
            selectedID = validScenario.id
            return
        }
        
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
    
    /// Recalculate only changed scenarios for better performance
    private func recalcChanged() {
        let lastSavedDict = Dictionary(uniqueKeysWithValues: lastSavedScenarios.map { ($0.id, $0) })
        
        // Recalculate all scenarios that have changed or are new
        for scenario in scenarios {
            if let lastSaved = lastSavedDict[scenario.id] {
                // Scenario exists - only recalc if it changed
                if scenario != lastSaved {
                    outputs[scenario.id] = Calc.compute(scenario)
                }
            } else {
                // New scenario - always recalc
                outputs[scenario.id] = Calc.compute(scenario)
            }
        }
        
        // Remove outputs for deleted scenarios
        let currentIDs = Set(scenarios.map(\.id))
        outputs = outputs.filter { currentIDs.contains($0.key) }
    }

    // MARK: Persistence
    private func save() {
        let state = SavedState(scenarios: self.scenarios, selectedID: self.selectedID)
        
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: saveURL, options: [.atomic])
            
            // Update last saved state for change detection
            lastSavedScenarios = self.scenarios
            lastSavedSelectedID = self.selectedID
            
            // Only recalc if scenarios actually changed
            let scenariosChanged = self.scenarios.count != self.lastSavedScenarios.count || 
                                  self.scenarios.contains { scenario in
                                      guard let lastSaved = self.lastSavedScenarios.first(where: { $0.id == scenario.id }) else {
                                          return true  // New scenario
                                      }
                                      return scenario != lastSaved
                                  }
            
            if scenariosChanged || self.selectedID != self.lastSavedSelectedID {
                recalcChanged()
            }
            
            let scenarioCount = self.scenarios.count
            Self.logger.debug("Successfully saved \(scenarioCount) scenarios")
            lastError = nil
        } catch {
            Self.logger.error("Failed to save scenarios: \(error.localizedDescription, privacy: .public)")
            lastError = "Failed to save: \(error.localizedDescription)"
            // Still recalc even if save fails to keep UI in sync
            recalcChanged()
        }
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
