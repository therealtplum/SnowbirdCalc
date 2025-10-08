//
//  MineralRightsService.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/6/25.
//


import Foundation

protocol MineralRightsService {
    func fetchListings(query: String?) async throws -> [MineralListing]
}

/// Default service: points to your backend/scraper when ready.
/// For local dev, we ship a stub that you can replace with a real HTTP call.
struct DefaultMineralRightsService: MineralRightsService {
    // TODO: Point to your backend endpoint from the Python scraper output
    // e.g., let endpoint = URL(string: "https://api.yourdomain.com/minerals")!

    func fetchListings(query: String?) async throws -> [MineralListing] {
        // ---- STUB DATA (replace with real network call) ----
        var demo: [MineralListing] = [
            MineralListing(
                source: "US Mineral Exchange",
                title: "Permian NMA w/ 3/16 Royalty",
                location: "Midland County, TX",
                acres: 120, netMineralAcres: 40,
                royaltyFraction: 0.1875,
                priceUSD: 120_000,
                url: URL(string: "https://example.com/offer/permian-123")!,
                postedAt: Date().addingTimeInterval(-60 * 60 * 24 * 2)
            ),
            MineralListing(
                source: "US Mineral Exchange",
                title: "SCOOP/STACK Package",
                location: "Grady County, OK",
                acres: 320, netMineralAcres: 80,
                royaltyFraction: 0.25,
                priceUSD: 180_000,
                url: URL(string: "https://example.com/offer/scoop-456")!,
                postedAt: Date().addingTimeInterval(-60 * 60 * 24 * 6)
            ),
            MineralListing(
                source: "Marketplace X",
                title: "Non-Producing NMA (Speculative)",
                location: "Lea County, NM",
                acres: 200, netMineralAcres: 20,
                royaltyFraction: 0.20,
                priceUSD: 45_000,
                url: URL(string: "https://example.com/offer/nm-789")!,
                postedAt: Date().addingTimeInterval(-60 * 60 * 24 * 1)
            )
        ]

        if let q = query, !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let needle = q.lowercased()
            demo = demo.filter {
                $0.title.lowercased().contains(needle)
                || $0.location.lowercased().contains(needle)
                || $0.source.lowercased().contains(needle)
            }
        }
        return demo
    }
}