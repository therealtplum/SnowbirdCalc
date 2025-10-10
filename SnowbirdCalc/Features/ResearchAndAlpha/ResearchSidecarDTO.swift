//
//  ResearchSidecarDTO.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/9/25.
//


import Foundation

/// JSON sidecar model decoded off the main actor (pure data).
struct ResearchSidecarDTO: Codable, Sendable {
    var id: UUID? = nil
    var title: String? = nil
    var summary: String? = nil
    /// Parsed by `scanBundle()` using ISO8601 or yyyy-MM-dd
    var publishedAt: String? = nil
    var tags: [String]? = nil
    var fileURL: URL? = nil
}