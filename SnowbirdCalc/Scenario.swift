
import Foundation

struct Scenario: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String

    // Global plan/tax inputs
    var employeeDeferral: Double
    var employerPct: Double            // e.g. 0.25
    var ordinaryRate: Double           // e.g. 0.35
    var ltcgRate: Double               // e.g. 0.20
    var niitRate: Double               // e.g. 0.038

    // Subsidiaries (editable/extendable)
    var subs: [Subsidiary]

    init(
        id: UUID = .init(),
        name: String = "My Scenario",
        employeeDeferral: Double = 23_000,
        employerPct: Double = 0.25,
        ordinaryRate: Double = 0.35,
        ltcgRate: Double = 0.20,
        niitRate: Double = 0.038,
        subs: [Subsidiary] = [
            .init(name: "Markets", kind: .investment, ltcg: 50_000, stcg: 150_000, mgmtFeePct: 0.25),
            .init(name: "Credit", kind: .activeBusiness, ordinaryIncome: 75_000, mgmtFeePct: 1.0),
            .init(name: "Royalties", kind: .royalties, ordinaryIncome: 60_000, mgmtFeePct: 0.25, depletionPct: 0.15),
            .init(name: "Farms", kind: .passiveFarm, ordinaryIncome: 40_000, mgmtFeePct: 0.0)
        ]
    ) {
        self.id = id
        self.name = name
        self.employeeDeferral = employeeDeferral
        self.employerPct = employerPct
        self.ordinaryRate = ordinaryRate
        self.ltcgRate = ltcgRate
        self.niitRate = niitRate
        self.subs = subs
    }
}
