import Foundation

/// High-performance URL parser and pattern generator supporting multi-delimiters and batch patterns.
public struct URLParser: Sendable {

    /// Parses raw pasted input containing one or multiple URLs into a sanitized array of URLs.
    ///
    /// - Parameters:
    ///   - text: The input string pasted by the user. Can be single, comma-separated, newline-separated, semicolon-separated, or space-separated.
    ///   - filterExtension: Optional file extension filter (e.g. "mp4", "zip"). If set, only URLs ending with this extension are returned.
    /// - Returns: A deduplicated array of valid `URL` objects.
    public static func parse(text: String, filterExtension: String? = nil) -> [URL] {
        var rawTokens: [String] = []

        // 1. Split by lines, commas, semicolons, and tabs while preserving spaces within query parameters
        let lines = text.components(separatedBy: CharacterSet.newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            let subDelimiters = CharacterSet(charactersIn: ",;\t")
            let parts = trimmedLine.components(separatedBy: subDelimiters)
            for part in parts {
                let trimmed = cleanToken(part)
                guard !trimmed.isEmpty else { continue }

                // Check if multiple URLs exist on the same line separated by whitespace
                if trimmed.components(separatedBy: "http").count > 2 {
                    let spaceSeparated = trimmed.components(separatedBy: .whitespaces)
                    for s in spaceSeparated {
                        let cl = cleanToken(s)
                        if !cl.isEmpty { rawTokens.append(cl) }
                    }
                } else {
                    rawTokens.append(trimmed)
                }
            }
        }

        // 2. Expand patterns like http://site.com/file[01-10].zip
        var expandedStrings: [String] = []
        for token in rawTokens {
            let expanded = expandPattern(token)
            expandedStrings.append(contentsOf: expanded)
        }

        // 3. Validate and build URL objects
        var resultURLs: [URL] = []
        var seen = Set<String>()

        for str in expandedStrings {
            var candidate = str
            if URL(string: candidate) == nil {
                if let encoded = candidate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    candidate = encoded
                }
            }

            guard let url = URL(string: candidate),
                  let scheme = url.scheme?.lowercased(),
                  (scheme == "http" || scheme == "https"),
                  let host = url.host, !host.isEmpty else {
                continue
            }

            // Apply extension filter if specified (checks path extension and query-derived filename extension)
            if let extFilter = filterExtension?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")), !extFilter.isEmpty {
                let pathExt = url.pathExtension.lowercased()
                let detectedName = DownloadItem.extractFilename(from: url)
                let fileExt = (detectedName as NSString).pathExtension.lowercased()

                if pathExt != extFilter && fileExt != extFilter {
                    continue
                }
            }

            let absolute = url.absoluteString
            if !seen.contains(absolute) {
                seen.insert(absolute)
                resultURLs.append(url)
            }
        }

        return resultURLs
    }

    /// Strips leading/trailing whitespace, quotes, angle brackets, and punctuation from token.
    private static func cleanToken(_ token: String) -> String {
        var cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip trailing punctuation like comma, semicolon
        while let last = cleaned.last, [",", ";", "."].contains(last) {
            cleaned.removeLast()
        }

        // Pairs of enclosing characters
        let pairs: [(Character, Character)] = [
            ("\"", "\""),
            ("'", "'"),
            ("<", ">"),
            ("(", ")"),
            ("[", "]")
        ]

        var stripped = true
        while stripped && cleaned.count >= 2 {
            stripped = false
            for (start, end) in pairs {
                if cleaned.first == start && cleaned.last == end {
                    cleaned.removeFirst()
                    cleaned.removeLast()
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                    stripped = true
                    break
                }
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Expands bracketed numeric patterns such as `http://example.com/part[01-05].mp4`.
    public static func expandPattern(_ input: String) -> [String] {
        guard let openBracket = input.range(of: "["),
              let closeBracket = input.range(of: "]", range: openBracket.upperBound..<input.endIndex) else {
            return [input]
        }

        let prefix = String(input[..<openBracket.lowerBound])
        let suffix = String(input[closeBracket.upperBound...])
        let patternContent = String(input[openBracket.upperBound..<closeBracket.lowerBound])

        let parts = patternContent.split(separator: "-")
        guard parts.count == 2,
              let startStr = parts.first,
              let endStr = parts.last,
              let startInt = Int(startStr),
              let endInt = Int(endStr),
              startInt <= endInt else {
            return [input]
        }

        let isZeroPadded = startStr.starts(with: "0") && startStr.count > 1
        let padWidth = isZeroPadded ? startStr.count : 0

        var results: [String] = []
        for i in startInt...endInt {
            let numberString: String
            if padWidth > 0 {
                numberString = String(format: "%0\(padWidth)d", i)
            } else {
                numberString = "\(i)"
            }
            results.append("\(prefix)\(numberString)\(suffix)")
        }

        return results
    }
}
