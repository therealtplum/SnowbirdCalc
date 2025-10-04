import Foundation

public struct EntityDirectory: Codable {
    public struct Entity: Codable, Identifiable {
        public let id: String          // shorthand like SMARK
        public let legalName: String
        public let shortName: String?
        public let jurisdiction: String?
        public let ein: String?
        public let effectiveDate: String?
        public let status: String?
        public let address: String?
        public let email: String?
    }
    public let version: Int
    public let updatedAt: String
    public let entities: [Entity]
}

public final class DirectoryStore {
    public private(set) var dir: EntityDirectory

    public init(jsonURL: URL) throws {
        let data = try Data(contentsOf: jsonURL)
        dir = try JSONDecoder().decode(EntityDirectory.self, from: data)
    }

    public func entity(by id: String) -> EntityDirectory.Entity? {
        return dir.entities.first { $0.id == id }
    }
}
