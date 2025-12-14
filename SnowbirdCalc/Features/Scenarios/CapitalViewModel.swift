import Foundation
import SwiftUI
import Combine
import os.log

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
        self.allocation = max(0, allocation)  // Ensure non-negative
        self.preTaxYieldPct = max(0, min(1.0, preTaxYieldPct))  // Clamp to 0-1
    }
}

@MainActor
final class CapitalViewModel: ObservableObject {
    
    private static let logger = Logger(subsystem: "com.snowbirdcalc", category: "CapitalViewModel")

    // MARK: - Published inputs
    @Published var contributions: Double {
        didSet {
            // Validate: ensure non-negative
            if contributions < 0 {
                contributions = 0
                Self.logger.warning("Attempted to set negative contributions, clamped to 0")
            }
        }
    }
    @Published var subs: [CapitalSub]
    @Published var lastError: String?

    // MARK: - Storage
    private let saveURL: URL
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init / Load
    init() {
        // Save path: ~/Documents/capital.json (inside app sandbox)
        let fm = FileManager.default
        
        // Safe file URL creation with fallback
        guard let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            // Fallback to temporary directory if document directory fails
            Self.logger.error("Failed to access document directory, using temporary directory")
            self.saveURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("capital.json")
            // Initialize with defaults
            self.contributions = 100_000
            self.subs = [
                CapitalSub(name: "Markets", allocation: 20_000, preTaxYieldPct: 0.12),
                CapitalSub(name: "Credit",  allocation: 40_000, preTaxYieldPct: 0.10)
            ]
            setupAutoSave()
            return
        }
        
        self.saveURL = docs.appendingPathComponent("capital.json")

        // Load saved state with error handling
        if let data = try? Data(contentsOf: saveURL),
           let decoded = try? JSONDecoder().decode(SavedState.self, from: data) {
            // Validate loaded data
            self.contributions = max(0, decoded.contributions)
            self.subs = decoded.subs.map { sub in
                CapitalSub(
                    name: sub.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Sub" : sub.name,
                    allocation: max(0, sub.allocation),
                    preTaxYieldPct: max(0, min(1.0, sub.preTaxYieldPct))
                )
            }
            Self.logger.info("Loaded capital data: \(decoded.contributions) contributions, \(decoded.subs.count) subsidiaries")
        } else {
            // Default starting state
            self.contributions = 100_000
            self.subs = [
                CapitalSub(name: "Markets", allocation: 20_000, preTaxYieldPct: 0.12),
                CapitalSub(name: "Credit",  allocation: 40_000, preTaxYieldPct: 0.10)
            ]
            Self.logger.info("Initialized with default capital data")
        }

        setupAutoSave()
    }
    
    private func setupAutoSave() {
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

    /// Update a specific sub by id with validation
    func updateSub(_ sub: CapitalSub, mutate: (inout CapitalSub) -> Void) {
        guard let idx = subs.firstIndex(where: { $0.id == sub.id }) else { return }
        var copy = subs[idx]
        mutate(&copy)
        
        // Validate and clamp values
        copy.allocation = max(0, copy.allocation)
        copy.preTaxYieldPct = max(0, min(1.0, copy.preTaxYieldPct))
        let trimmedName = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            copy.name = "New Sub"
            Self.logger.warning("Attempted to set empty sub name, using default")
        } else {
            copy.name = trimmedName
        }
        
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
        
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: saveURL, options: [.atomic])
            Self.logger.debug("Successfully saved capital data")
            lastError = nil
        } catch {
            Self.logger.error("Failed to save capital data: \(error.localizedDescription, privacy: .public)")
            lastError = "Failed to save: \(error.localizedDescription)"
        }
    }
}
