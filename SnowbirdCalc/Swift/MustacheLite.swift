import Foundation

// Extremely tiny mustache-ish renderer supporting:
// - {{path}} lookups (paths into ValuesBag.raw)
// - {{#if expr}} ... {{/if}}
// - {{#each array}} uses "this" in the scope
// - filters: | longDate, | money, | pct
//
// This is intentionally minimal for demo/testing; swap with a robust templater later.
public final class MustacheLite {
    public init() {}

    public func render(_ template: String, values: inout ValuesBag) -> String {
        // Very naive: handle {{ ... }} tokens and a couple of block forms.
        // For production, replace with a proper templating lib.
        var output = template

        // Blocks: #if and #each (single-level, non-nested naive implementation)
        output = renderIfBlocks(in: output, values: &values)
        output = renderEachBlocks(in: output, values: &values)

        // Simple tokens with optional filter " | xxx"
        let tokenPattern = #"\{\{\s*([^\}|]+?)(?:\s*\|\s*([^\}]+))?\s*\}\}"#
        let regex = try! NSRegularExpression(pattern: tokenPattern, options: [])
        let matches = regex.matches(in: output, options: [], range: NSRange(output.startIndex..., in: output)).reversed()
        for m in matches {
            let key = String(output[Range(m.range(at: 1), in: output)!]).trimmingCharacters(in: .whitespaces)
            let filter = (m.range(at: 2).location != NSNotFound) ? String(output[Range(m.range(at: 2), in: output)!]).trimmingCharacters(in: .whitespaces) : nil
            let replacement = renderToken(keyPath: key, filter: filter, values: &values)
            output.replaceSubrange(Range(m.range, in: output)!, with: replacement)
        }
        return output
    }

    private func renderToken(keyPath: String, filter: String?, values: inout ValuesBag) -> String {
        // Support ternary like "officerTitle == 'Other' ? officerTitleOther : officerTitle"
        if keyPath.contains("?") && keyPath.contains(":") && keyPath.contains("==") {
            return evalTernary(expr: keyPath, values: &values)
        }
        // Simple lookup
        let val: Any? = lookup(path: keyPath, values: &values)
        return applyFilter(val, name: filter)
    }

    private func lookup(path: String, values: inout ValuesBag) -> Any? {
        let parts = path.split(separator: ".").map(String.init)
        var cur: Any = values.raw
        for p in parts {
            if p == "$template" { return values.raw["$template"] }
            if let dict = cur as? [String:Any], let next = dict[p] {
                cur = next
            } else {
                return nil
            }
        }
        return cur
    }

    private func evalTernary(expr: String, values: inout ValuesBag) -> String {
        // Very small evaluator for "A == 'B' ? C : D"
        // Split on ? and :
        let parts = expr.split(separator: "?")
        guard parts.count == 2 else { return "" }
        let cond = parts[0].trimmingCharacters(in: .whitespaces)
        let tail = String(parts[1])
        let tailParts = tail.split(separator: ":")
        guard tailParts.count == 2 else { return "" }
        let ifTrue = tailParts[0].trimmingCharacters(in: .whitespaces)
        let ifFalse = tailParts[1].trimmingCharacters(in: .whitespaces)

        // condition "lhs == 'rhs'"
        let eqParts = cond.split(separator: "==")
        if eqParts.count == 2 {
            let lhsPath = eqParts[0].trimmingCharacters(in: .whitespaces)
            let rhsRaw = eqParts[1].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\'\""))
            let lhsVal = (lookup(path: lhsPath, values: &values) as? CustomStringConvertible)?.description ?? ""
            let resultPath = (lhsVal == rhsRaw) ? ifTrue : ifFalse
            return (lookup(path: resultPath, values: &values) as? CustomStringConvertible)?.description ?? resultPath
        }
        return ""
    }

    private func renderIfBlocks(in text: String, values: inout ValuesBag) -> String {
        var output = text
        let pattern = #"\{\{#if\s+([^\}]+)\}\}([\s\S]*?)\{\{\/if\}\}"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        while true {
            if let m = regex.firstMatch(in: output, options: [], range: NSRange(output.startIndex..., in: output)) {
                let cond = String(output[Range(m.range(at: 1), in: output)!]).trimmingCharacters(in: .whitespaces)
                let body = String(output[Range(m.range(at: 2), in: output)!])
                let include = evalCondition(cond, values: &values)
                output.replaceSubrange(Range(m.range, in: output)!, with: include ? body : "")
            } else { break }
        }
        return output
    }

    private func evalCondition(_ expr: String, values: inout ValuesBag) -> Bool {
        // supports: "isEquityHolder" (truthy) or "authorityScopes.includes('banking')"
        if expr.contains(".includes(") {
            let parts = expr.replacingOccurrences(of: ")", with: "").split(separator: ".includes(")
            guard parts.count == 2 else { return false }
            let arrPath = String(parts[0])
            let needle = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\'\""))
            if let arr = lookup(path: arrPath, values: &values) as? [String] {
                return arr.contains(needle)
            }
            return false
        } else {
            // Truthy lookup
            if let b = lookup(path: expr, values: &values) as? Bool { return b }
            if let s = lookup(path: expr, values: &values) as? String { return !s.isEmpty }
            if let n = lookup(path: expr, values: &values) as? NSNumber { return n != 0 }
            return false
        }
    }

    private func renderEachBlocks(in text: String, values: inout ValuesBag) -> String {
        var output = text
        let pattern = #"\{\{#each\s+([^\}]+)\}\}([\s\S]*?)\{\{\/each\}\}"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        while true {
            if let m = regex.firstMatch(in: output, options: [], range: NSRange(output.startIndex..., in: output)) {
                let path = String(output[Range(m.range(at: 1), in: output)!]).trimmingCharacters(in: .whitespaces)
                let body = String(output[Range(m.range(at: 2), in: output)!])
                var rendered = ""
                if let arr = lookup(path: path, values: &values) as? [[String:Any]] {
                    for item in arr {
                        var scope = values
                        scope.raw["this"] = item
                        // also expand item's keys at top-level for convenience? Not needed.
                        let inner = MustacheLite().render(body, values: &scope)
                        rendered += inner
                    }
                }
                output.replaceSubrange(Range(m.range, in: output)!, with: rendered)
            } else { break }
        }
        return output
    }

    private func applyFilter(_ value: Any?, name: String?) -> String {
        let str: String
        switch value {
        case let d as Date:
            str = ISO8601DateFormatter().string(from: d)
        case let n as NSNumber:
            str = n.stringValue
        case let s as String:
            str = s
        default:
            str = value.map { "\($0)" } ?? ""
        }

        guard let name = name else { return str }
        switch name {
        case "longDate":
            if let s = value as? String, let dt = ISO8601DateFormatter().date(from: s + "T00:00:00Z") {
                let f = DateFormatter()
                f.dateStyle = .long
                return f.string(from: dt)
            }
            return str
        case "money":
            if let n = Double(str) {
                let f = NumberFormatter()
                f.numberStyle = .currency
                f.currencyCode = "USD"
                f.maximumFractionDigits = 2
                return f.string(from: NSNumber(value: n)) ?? str
            }
            return str
        case "pct":
            if let n = Double(str) {
                let f = NumberFormatter()
                f.numberStyle = .percent
                f.maximumFractionDigits = 2
                return f.string(from: NSNumber(value: n/100.0)) ?? str
            }
            return str
        default:
            return str
        }
    }
}
