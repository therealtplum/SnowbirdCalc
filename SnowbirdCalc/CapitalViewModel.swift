import Foundation
import SwiftUI
import Combine

// One allocation line item inside Capital
struct CapitalSub: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var allocation: Double          // dollars allocated to this sub
    var preTaxYieldPct: Double      // 0.12 = 12%

    init(id: UUID = UUID(),
         name: String,
         allocation: Double = 0,
         preTaxYieldPct: Double = 0.0) {
        self.id = id
        self.name = name
        self.allocation = allocation
        self.preTaxYieldPct = preTaxYieldPct
    }
}

@MainActor
final class CapitalViewModel: ObservableObject {

    // MARK: - Published inputs
    @Published var contributions: Double
    @Published var subs: [CapitalSub]

    // MARK: - Storage
    private let saveURL: URL
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init / Load
    init() {
        // Save path: ~/Documents/capital.json (inside app sandbox)
        let fm = FileManager.default
        let docs = try! fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        self.saveURL = docs.appendingPathComponent("capital.json")

        if let data = try? Data(contentsOf: saveURL),
           let decoded = try? JSONDecoder().decode(SavedState.self, from: data) {
            self.contributions = decoded.contributions
            self.subs = decoded.subs
        } else {
            // Default starting state
            self.contributions = 100_000
            self.subs = [
                CapitalSub(name: "Markets", allocation: 20_000, preTaxYieldPct: 0.12),
                CapitalSub(name: "Credit",  allocation: 40_000, preTaxYieldPct: 0.10)
            ]
        }

        // Auto-save whenever contributions or subs change
        Publishers.CombineLatest($contributions, $subs)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.save()
            }
            .store(in: &cancellables)
    }

    // MARK: - Derived
    var allocatedTotal: Double {
        subs.reduce(0) { $0 + max(0, $1.allocation) }
    }

    var cashOnHand: Double {
        contributions - allocatedTotal
    }

    /// For now, portfolio value equals total contributed.
    var portfolioValue: Double {
        contributions
    }

    /// Weighted pre-tax yield across all subs.
    /// If contributions == 0, returns 0.
    var blendedPreTaxYieldPct: Double {
        guard contributions > 0 else { return 0 }
        let weighted = subs.reduce(0) { sum, s in
            sum + max(0, s.allocation) * max(0, s.preTaxYieldPct)
        }
        return weighted / contributions
    }
    
    var projectedPreTaxIncome: Double {
        subs.reduce(0) { $0 + max(0, $1.allocation) * max(0, $1.preTaxYieldPct) }
    }

    var isOverAllocated: Bool { cashOnHand < 0 }

    // MARK: - Mutations
    func addSub() {
        subs.append(CapitalSub(name: "New Sub", allocation: 0, preTaxYieldPct: 0.0))
    }

    func delete(_ offsets: IndexSet) {
        subs.remove(atOffsets: offsets)
    }

    /// Update a specific sub by id
    func updateSub(_ sub: CapitalSub, mutate: (inout CapitalSub) -> Void) {
        guard let idx = subs.firstIndex(where: { $0.id == sub.id }) else { return }
        var copy = subs[idx]
        mutate(&copy)
        subs[idx] = copy
    }

    /// Reset all contributions and subsidiaries
    func clearAll() {
        contributions = 0
        subs.removeAll()
    }

    // MARK: - Persistence
    private struct SavedState: Codable {
        var contributions: Double
        var subs: [CapitalSub]
    }

    private func save() {
        let state = SavedState(contributions: contributions, subs: subs)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: saveURL, options: [.atomic])
        }
    }
}
