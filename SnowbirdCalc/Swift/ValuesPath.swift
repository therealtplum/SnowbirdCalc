import Foundation

public enum ValuesPathError: Error { case missing, typeMismatch }

public struct ValuesBag {
    public var raw: [String:Any]
    public init(_ raw: [String:Any] = [:]) { self.raw = raw }

    // Basic dotted path lookup e.g., "entity.id"
    public func valueAt<T>(_ path: String) throws -> T {
        let parts = path.split(separator: ".").map(String.init)
        var cursor: Any? = raw
        for p in parts {
            if p == "$template" { return raw["$template"] as! T }
            if let dict = cursor as? [String:Any] {
                cursor = dict[p]
            } else {
                throw ValuesPathError.typeMismatch
            }
        }
        guard let casted = cursor as? T else { throw ValuesPathError.missing }
        return casted
    }
}
