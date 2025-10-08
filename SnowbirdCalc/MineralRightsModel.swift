//
//  MineralRightsModel.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/6/25.
//

import Foundation

struct MineralListing: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var source: String
    var title: String
    var location: String          // "County, ST"
    var acres: Double?            // gross acres
    var netMineralAcres: Double?  // NMA
    var royaltyFraction: Double?  // 0.0–1.0
    var priceUSD: Double?         // asking price
    var url: URL
    var postedAt: Date?
    var notes: String?
    var listingID: String?        // e.g., "304845"
    var cashFlowUSD: Double?
    // Derived
    var nma: Double { netMineralAcres ?? acres ?? 0 }
    var dollarsPerNMA: Double? {
        guard let p = priceUSD, nma > 0 else { return nil }
        return p / nma
    }
    var royaltyPctDisplay: String { MineralAssumptions.royaltyDisplay(royaltyFraction) }

    var shortLoc: String {
        let parts = location.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count >= 2 { return "\(parts[0]), \(parts[1])" }
        return location.isEmpty ? source : location
    }

    var stateCode: String? {
        let parts = location.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.last?.count == 2 ? String(parts.last!) : nil
    }

    var score: Double {
        MineralScore.score(dollarsPerNMA: dollarsPerNMA, royalty: royaltyFraction, postedAt: postedAt, stateCode: stateCode)
    }
}

enum MineralSort: String, CaseIterable, Identifiable {
    case bestScore = "Best Score"
    case lowestPricePerNMA = "Lowest $/NMA"
    case highestRoyalty = "Highest Royalty"
    case newest = "Newest"
    var id: String { rawValue }
}
