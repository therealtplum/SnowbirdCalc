
import Foundation

enum SubsidiaryType: String, Codable, CaseIterable, Identifiable {
    case investment    // Markets: LTCG + STCG
    case activeBusiness // Credit: ordinary earned income
    case royalties     // Minerals: ordinary + depletion
    case passiveFarm   // AcreTrader: passive ordinary
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .investment: return "Investment (Markets)"
        case .activeBusiness: return "Active Business (Credit)"
        case .royalties: return "Royalties (Minerals)"
        case .passiveFarm: return "Passive Farm (AcreTrader)"
        }
    }
}

struct Subsidiary: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var kind: SubsidiaryType

    // Inputs
    var ltcg: Double        // for .investment
    var stcg: Double        // for .investment
    var ordinaryIncome: Double // for non-investment kinds
    var mgmtFeePct: Double  // 0...1
    var depletionPct: Double // royalties only

    init(
        id: UUID = .init(),
        name: String,
        kind: SubsidiaryType,
        ltcg: Double = 0,
        stcg: Double = 0,
        ordinaryIncome: Double = 0,
        mgmtFeePct: Double = 0,
        depletionPct: Double = 0.15
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.ltcg = ltcg
        self.stcg = stcg
        self.ordinaryIncome = ordinaryIncome
        self.mgmtFeePct = mgmtFeePct
        self.depletionPct = depletionPct
    }
}
