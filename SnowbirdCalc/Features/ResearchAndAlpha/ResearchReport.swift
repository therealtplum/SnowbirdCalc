//
//  ResearchReport.swift
//  SnowbirdCalc
//
//  Created by Thomas Plummer on 10/9/25.
//


import Foundation

public struct ResearchReport: Identifiable, Hashable, Codable {
    public let id: UUID
    public let title: String
    public let summary: String?
    public let publishedAt: Date
    public let tags: [String]
    public let fileURL: URL

    public init(id: UUID = UUID(),
                title: String,
                summary: String? = nil,
                publishedAt: Date,
                tags: [String],
                fileURL: URL) {
        self.id = id
        self.title = title
        self.summary = summary
        self.publishedAt = publishedAt
        self.tags = tags
        self.fileURL = fileURL
    }
}
