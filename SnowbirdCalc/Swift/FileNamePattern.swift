import Foundation

public final class FileNamePattern {
    public static func render(_ pattern: String, values: [String:Any]) -> String {
        var bag = ValuesBag(values)
        var s = pattern
        let regex = try! NSRegularExpression(pattern: #"\{\{\s*([^\}]+)\s*\}\}"#, options: [])
        let matches = regex.matches(in: s, options: [], range: NSRange(s.startIndex..., in: s)).reversed()
        for m in matches {
            let key = String(s[Range(m.range(at: 1), in: s)!]).trimmingCharacters(in: .whitespaces)
            let val = (try? bag.valueAt(any: key)) ?? ""
            s.replaceSubrange(Range(m.range, in: s)!, with: "\(val)")
        }
        return s
    }
}

private extension ValuesBag {
    func valueAt(any path: String) throws -> String {
        if let v: String = try? valueAt(path) { return v }
        if let v: Int = try? valueAt(path) { return String(v) }
        if let v: Double = try? valueAt(path) { return String(v) }
        if let v: Bool = try? valueAt(path) { return v ? "true":"false" }
        return ""
    }
}
