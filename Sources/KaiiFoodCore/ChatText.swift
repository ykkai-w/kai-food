import Foundation

public enum ChatText {
    public static func normalizedMarkdown(_ source: String) -> String {
        let strong = try! NSRegularExpression(pattern: #"\*\*([^*\n]+?)\*\*"#)
        var result = source
        for match in strong.matches(in: source, range: NSRange(source.startIndex..., in: source)).reversed() {
            guard let whole = Range(match.range, in: result), let inner = Range(match.range(at: 1), in: result) else { continue }
            let content = result[inner].trimmingCharacters(in: .whitespaces)
            if !content.isEmpty { result.replaceSubrange(whole, with: "**\(content)**") }
        }
        return result.components(separatedBy: "\n").map { line in
            if let range = line.range(of: #"^\s*#{1,6}\s+"#, options: .regularExpression) {
                return "**\(line[range.upperBound...])**"
            }
            return line.replacingOccurrences(of: #"^(\s*)[-*+]\s+"#, with: "$1• ", options: .regularExpression)
        }.joined(separator: "\n")
    }

    public static func attributed(_ source: String) -> AttributedString {
        let normalized = normalizedMarkdown(source)
        let strong = try! NSRegularExpression(pattern: #"\*\*([^*\n]+?)\*\*"#)
        var result = AttributedString()
        var start = normalized.startIndex
        for match in strong.matches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) {
            guard let whole = Range(match.range, in: normalized), let inner = Range(match.range(at: 1), in: normalized) else { continue }
            result += AttributedString(String(normalized[start..<whole.lowerBound]))
            var bold = AttributedString(String(normalized[inner]))
            bold.inlinePresentationIntent = .stronglyEmphasized
            result += bold
            start = whole.upperBound
        }
        result += AttributedString(String(normalized[start...]))
        return result
    }
}
