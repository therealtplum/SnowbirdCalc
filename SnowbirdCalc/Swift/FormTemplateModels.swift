import Foundation

// MARK: - Form Template Models
public struct FormTemplate: Codable {
    public let id: String
    public let name: String
    public let version: Int
    public let typeTag: String
    public let fileNamePattern: String
    public let fields: [Field]
    public let document: Document

    public struct Field: Codable {
        public let id: String
        public let label: String
        public let type: String
        public let required: Bool?
        public let minItems: Int?
        public let options: [String]?
        public let help: String?
        public let placeholder: String?
        public let hidden: Bool?
        public let source: String?
        public let repeatable: Bool?
        public let visibleIf: Condition?
        public let requiredIf: Condition?
        public let validate: Validation?
        public let compute: Compute?
    }

    public struct Condition: Codable {
        public let field: String
        public let equals: CodableValue?
        public let includes: String?
    }

    public struct Validation: Codable {
        public let notEqualField: String?
        public let gteField: String?
        public let message: String?
    }

    public struct Compute: Codable {
        public let fn: String
        public let args: [String:String]
    }

    public struct Document: Codable {
        public let title: String
        public let bodyMd: String
    }
}

// Helper for heterogeneous JSON comparisons
public enum CodableValue: Codable, Equatable {
    case string(String)
    case bool(Bool)
    case number(Double)
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s) }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let d = try? c.decode(Double.self) { self = .number(d) }
        else { self = .null }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .bool(let b): try c.encode(b)
        case .number(let d): try c.encode(d)
        case .null: try c.encodeNil()
        }
    }
}
