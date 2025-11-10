import Foundation

class NoteFormattingHelper {
    static func stripHTMLTags(from htmlString: String) -> String {
        // Remove HTML tags using regex
        let pattern = "<[^>]+>"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: htmlString.utf16.count)
            let strippedString = regex.stringByReplacingMatches(in: htmlString, options: [], range: range, withTemplate: "")

            return decodeHTMLEntities(strippedString)
        } catch {
            return htmlString
        }
    }

    static func decodeHTMLEntities(_ string: String) -> String {
        // Use a lightweight approach instead of NSAttributedString to avoid crashes
        var result = string
        
        // Decode common HTML entities
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&nbsp;": " ",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™"
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // Decode numeric entities (&#xxx; and &#xHH;)
        let decimalPattern = "&#(\\d+);"
        if let decimalRegex = try? NSRegularExpression(pattern: decimalPattern, options: []) {
            let matches = decimalRegex.matches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count))
            
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let numRange = Range(match.range(at: 1), in: result),
                   let code = Int(result[numRange]),
                   let scalar = UnicodeScalar(code) {
                    result.replaceSubrange(range, with: String(Character(scalar)))
                }
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

class NotesFilterHelper {
    static func filterNotes(_ notes: [Note], with searchText: String) -> [Note] {
        if searchText.isEmpty {
            return notes
        } else {
            return notes.filter { note in
                let titleMatch = note.title?.localizedCaseInsensitiveContains(searchText) == true
                let contentMatch = note.content.flatMap { NoteFormattingHelper.stripHTMLTags(from: $0).localizedCaseInsensitiveContains(searchText) } == true
                return titleMatch || contentMatch
            }
        }
    }
}