import Foundation

public struct ResolutionRegister: Codable, Equatable {
    public struct Key: Hashable, Codable {
        public let entityId: String
        public let year: Int

        // Public init so you can construct keys outside the module if needed
        public init(entityId: String, year: Int) {
            self.entityId = entityId
            self.year = year
        }
    }

    public var counters: [Key:Int]

    // ✅ Public initializer (with default) so it’s legal in a public default argument
    public init(counters: [Key:Int] = [:]) {
        self.counters = counters
    }
}

public final class ResolutionIdService {
    private var register: ResolutionRegister

    // ✅ Now valid: uses the public init above
    public init(loaded: ResolutionRegister = ResolutionRegister()) {
        self.register = loaded
    }

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

    public func save(to url: URL) throws {
        let data = try JSONEncoder().encode(register)
        try data.write(to: url, options: .atomic)
    }

    public static func load(from url: URL) -> ResolutionRegister {
        (try? JSONDecoder().decode(ResolutionRegister.self, from: (try? Data(contentsOf: url)) ?? Data())) ?? ResolutionRegister()
    }
}
