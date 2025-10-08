//
//  MineralAssumptions.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/6/25.
//


import Foundation

struct MineralAssumptions {
    // State-level severance/production tax (tweak as needed)
    static let stateTax: [String: Double] = [
        "TX": 0.06, "NM": 0.09, "OK": 0.07, "ND": 0.10, "LA": 0.09, "CO": 0.07, "UT": 0.07
    ]
    // Typical $/NMA bands to sanity-check outliers (optional)
    static let nmaBands: [String: (low: Double, high: Double)] = [
        "TX": (3000, 10000),
        "NM": (2000, 7000),
        "OK": (1500, 6000),
        "LA": (1500, 6000),
        "CO": (1500, 6000),
        "UT": (1000, 4000)
    ]
    // Personal tax and depletion considerations (rough cut)
    static let personalTax: Double = 0.30
    static let depletion: Double = 0.15

    // Commodity sensitivity (you can wire to a live price later)
    static let wtiBaseline: Double = 75.0
    static var wtiCurrent: Double = 75.0
    static let oilElasticity: Double = 0.80

    static func royaltyDisplay(_ fraction: Double?) -> String {
        guard let f = fraction else { return "—" }
        return "\(Int((f * 100).rounded()))%"
    }
}

struct MineralScore {
    /// Higher is better. Basic idea: cheap per NMA + higher royalty + fresher listing.
    static func score(
        dollarsPerNMA: Double?,
        royalty: Double?,                    // 0..1
        postedAt: Date?,                     // recency bonus
        stateCode: String?
    ) -> Double {
        var s: Double = 0

        if let d = dollarsPerNMA {
            // inverse cost (cap to avoid runaway)
            s += 1000.0 / max(d, 1.0)
        }

        if let r = royalty {
            // royalty has strong weight
            s += r * 10.0
        }

        if let date = postedAt {
            let days = max(0, Date().timeIntervalSince(date) / 86400.0)
            // newer is better; 0–15 days can add up to ~3 points
            s += max(0, 3.0 - min(3.0, days / 5.0))
        }

        if let st = stateCode, let stTax = MineralAssumptions.stateTax[st] {
            // modest penalty for higher state tax
            s -= stTax * 2.0
        }

        return s
    }
}