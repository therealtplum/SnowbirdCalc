import Foundation
import Combine
import SwiftUI

// MARK: - Pure value types (non-isolated)

public struct ResolutionKey: Hashable, Codable, Sendable {
    public let entityId: String
    public let year: Int
    public init(entityId: String, year: Int) {
        self.entityId = entityId
        self.year = year
    }
}

public struct ResolutionRegister: Codable, Equatable, Sendable {
    public typealias Key = ResolutionKey
    public var counters: [Key: Int]

    public init(counters: [Key: Int]) {
        self.counters = counters
    }

    /// Convenience empty factory so you don't use default args across isolation
    public static let empty = ResolutionRegister(counters: [:])
}

// MARK: - Service (UI/ObservableObject). Keep this on the main actor.

@MainActor
public final class ResolutionIdService: ObservableObject {
    @Published public private(set) var register: ResolutionRegister

    /// Explicit initializer (no default-arg crossing isolation)
    public init(loaded: ResolutionRegister) {
        self.register = loaded
    }

    /// No-arg convenience init
    public convenience init() {
        self.init(loaded: .empty)
    }

    @discardableResult
    public func nextSequence(entityId: String, year: Int) -> Int {
        let key = ResolutionRegister.Key(entityId: entityId, year: year)
        let next = (register.counters[key] ?? 0) + 1
        register.counters[key] = next
        return next
    }

    public func generateResolutionId(entityId: String, date: Date, typeTag: String) -> String {
        let year = Calendar.current.component(.year, from: date)
        let seq = String(format: "%02d", nextSequence(entityId: entityId, year: year))
        return "\(entityId)-\(year)-\(seq)-RES-\(typeTag)"
    }

    // MARK: Persistence

    public func save(to url: URL) throws {
        let data = try JSONEncoder().encode(register)
        try data.write(to: url, options: .atomic)
    }

    public static func load(from url: URL) -> ResolutionRegister {
        guard let data = try? Data(contentsOf: url),
              let reg = try? JSONDecoder().decode(ResolutionRegister.self, from: data) else {
            return .empty
        }
        return reg
    }
}
